import { Hono } from "hono";
import { handle } from "hono/vercel";
import { setCookie, deleteCookie } from "hono/cookie";
import { z } from "zod";
import { env } from "@/lib/env";
import { verifyPassword } from "@/lib/auth/password";
import { verifyTurnstile } from "@/lib/auth/turnstile";
import {
  SESSION_COOKIE,
  createSessionToken,
  sessionCookieOptions,
} from "@/lib/auth/session";
import { rateLimiters, enforceLimit, clientIp } from "@/lib/ratelimit";
import { transcribe } from "@/lib/nexus/stt";
import { runChat } from "@/lib/nexus/chat";
import { synthesizeStream } from "@/lib/nexus/tts";

export const runtime = "nodejs";
export const maxDuration = 60;

const MAX_AUDIO_BYTES = 2_500_000; // ~2.5MB; VAD keeps clips short

const app = new Hono().basePath("/api");

const loginSchema = z.object({
  password: z.string().min(1).max(200),
  // Cloudflare Turnstile token (cf-turnstile-response). Optional in the schema so the
  // endpoint still works when Turnstile is not configured; enforced below when the
  // secret key is present.
  turnstileToken: z.string().min(1).max(4096).optional(),
});

const chatSchema = z.object({
  sessionId: z.string().min(8).max(64),
  text: z.string().min(1).max(2000),
});

const ttsSchema = z.object({
  text: z.string().min(1).max(2000),
});

app.post("/auth/login", async (c) => {
  const ip = clientIp(c.req.raw);
  const { allowed } = await enforceLimit(rateLimiters.login(), ip, "login");
  if (!allowed) {
    return c.json({ error: "rate_limited" }, 429, { "Retry-After": "60" });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = loginSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "invalid_request" }, 400);
  }

  // Bot / brute-force gate: when Turnstile is configured, reject before we ever
  // touch the password so automated attempts never reach the credential check.
  const turnstileSecret = env.turnstileSecretKey();
  if (turnstileSecret) {
    const token = parsed.data.turnstileToken;
    if (!token) {
      return c.json({ error: "captcha_required" }, 400);
    }
    const human = await verifyTurnstile(token, turnstileSecret, ip);
    if (!human) {
      return c.json({ error: "captcha_failed" }, 403);
    }
  }

  const ok = await verifyPassword(parsed.data.password, env.dashboardPasswordHash());
  if (!ok) {
    return c.json({ error: "unauthorized" }, 401);
  }

  const token = await createSessionToken(env.authSecret());
  setCookie(c, SESSION_COOKIE, token, { ...sessionCookieOptions });
  return c.json({ ok: true });
});

app.post("/auth/logout", (c) => {
  deleteCookie(c, SESSION_COOKIE, { path: "/" });
  return c.json({ ok: true });
});

// ---------- Nexus voice pipeline ----------

app.post("/nexus/stt", async (c) => {
  const { allowed } = await enforceLimit(rateLimiters.nexusStt(), clientIp(c.req.raw), "nexus-stt");
  if (!allowed) return c.json({ error: "rate_limited" }, 429, { "Retry-After": "60" });

  const form = await c.req.formData().catch(() => null);
  const audio = form?.get("audio");
  if (!(audio instanceof Blob)) return c.json({ error: "invalid_request" }, 400);
  if (audio.size === 0) return c.json({ text: "" });
  if (audio.size > MAX_AUDIO_BYTES) return c.json({ error: "audio_too_large" }, 413);

  try {
    const text = await transcribe(audio);
    return c.json({ text });
  } catch (err) {
    console.error(JSON.stringify({ level: "error", event: "stt_failed", message: errMsg(err) }));
    return c.json({ error: "stt_failed" }, 502);
  }
});

app.post("/nexus/chat", async (c) => {
  const { allowed } = await enforceLimit(rateLimiters.nexusChat(), clientIp(c.req.raw), "nexus-chat");
  if (!allowed) return c.json({ error: "rate_limited" }, 429, { "Retry-After": "60" });

  const parsed = chatSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: "invalid_request" }, 400);

  try {
    const result = await runChat(parsed.data.sessionId, parsed.data.text);
    return c.json({
      reply: result.reply,
      usedTools: result.usedTools,
      agentTriggers: result.agentTriggers,
    });
  } catch (err) {
    console.error(JSON.stringify({ level: "error", event: "chat_failed", message: errMsg(err) }));
    return c.json({ error: "chat_failed" }, 502);
  }
});

app.post("/nexus/tts", async (c) => {
  const { allowed } = await enforceLimit(rateLimiters.nexusTts(), clientIp(c.req.raw), "nexus-tts");
  if (!allowed) return c.json({ error: "rate_limited" }, 429, { "Retry-After": "60" });

  const parsed = ttsSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: "invalid_request" }, 400);

  try {
    const upstream = await synthesizeStream(parsed.data.text);
    if (!upstream.ok || !upstream.body) {
      console.error(JSON.stringify({ level: "error", event: "tts_failed", status: upstream.status }));
      return c.json({ error: "tts_failed" }, 502);
    }
    return new Response(upstream.body, {
      status: 200,
      headers: { "content-type": "audio/mpeg", "cache-control": "no-store" },
    });
  } catch (err) {
    console.error(JSON.stringify({ level: "error", event: "tts_failed", message: errMsg(err) }));
    return c.json({ error: "tts_failed" }, 502);
  }
});

app.get("/health", (c) => c.json({ ok: true }));

function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : "unknown";
}

export const GET = handle(app);
export const POST = handle(app);
