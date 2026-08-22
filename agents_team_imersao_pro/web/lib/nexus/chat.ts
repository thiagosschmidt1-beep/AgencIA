import "server-only";
import Anthropic from "@anthropic-ai/sdk";
import { env } from "@/lib/env";
import { NEXUS_SYSTEM_PROMPT } from "@/lib/nexus/prompt";
import { toolSpecs, runTool } from "@/lib/nexus/tools";
import { type AgentTrigger } from "@/lib/nexus/agent-trigger";
import { loadMemory, appendExchange } from "@/lib/nexus/memory";

// Sonnet 4.6: fast, strong tool use — better fit than Opus for a low-latency voice
// loop (Opus 4.8 defaults to extended thinking, which adds latency we don't want here).
const MODEL = process.env.NEXUS_MODEL ?? "claude-sonnet-4-6";
const MAX_TOOL_ITERATIONS = 5;
const MAX_TOKENS = 1024;
const FALLBACK = "Desculpa, não consegui completar isso agora. Pode repetir?";

let client: Anthropic | null = null;
function anthropic(): Anthropic {
  if (!client) client = new Anthropic({ apiKey: env.anthropicApiKey() });
  return client;
}

export type ChatReply = {
  kind: "reply";
  reply: string;
  usedTools: string[];
  agentTriggers: AgentTrigger[];
};
export type ChatResult = ChatReply;

function extractText(content: Anthropic.ContentBlock[]): string {
  return content
    .filter((b): b is Anthropic.TextBlock => b.type === "text")
    .map((b) => b.text)
    .join(" ")
    .trim();
}

function stringField(value: unknown, key: string): string | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const field = (value as Record<string, unknown>)[key];
  return typeof field === "string" && field.length > 0 ? field : null;
}

function agentTriggerFromToolResult(toolName: string, result: unknown): AgentTrigger | null {
  if (toolName !== "request_campaign_creation" && toolName !== "request_campaign_activation") return null;
  if (!result || typeof result !== "object" || Array.isArray(result)) return null;
  if ((result as Record<string, unknown>).enqueued !== true) return null;

  const jobId = stringField(result, "job_id");
  const skill = stringField(result, "skill");
  const kind = stringField(result, "kind");
  const clientSlug = stringField(result, "client_slug");
  const queuedAt = stringField(result, "queued_at");
  if (!jobId || !skill || !kind || !clientSlug || !queuedAt) return null;

  return {
    jobId,
    skill,
    kind,
    clientSlug,
    queuedAt,
    source: "nexus",
  };
}

function pushAgentTrigger(agentTriggers: AgentTrigger[], trigger: AgentTrigger | null): void {
  if (!trigger || agentTriggers.some((item) => item.jobId === trigger.jobId)) return;
  agentTriggers.push(trigger);
}

/** The bounded Claude tool loop. All tools run server-side, inline. */
async function runLoop(
  messages: Anthropic.MessageParam[],
  usedTools: string[],
  agentTriggers: AgentTrigger[],
): Promise<ChatResult> {
  for (let i = 0; i < MAX_TOOL_ITERATIONS; i++) {
    const res = await anthropic().messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: [{ type: "text", text: NEXUS_SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
      tools: toolSpecs,
      messages,
    });

    if (res.stop_reason !== "tool_use") {
      return { kind: "reply", reply: extractText(res.content) || FALLBACK, usedTools, agentTriggers };
    }

    messages.push({ role: "assistant", content: res.content });

    const results: Anthropic.ToolResultBlockParam[] = [];
    for (const block of res.content) {
      if (block.type !== "tool_use") continue;
      usedTools.push(block.name);
      const result = await runTool(block.name, (block.input ?? {}) as Record<string, unknown>);
      pushAgentTrigger(agentTriggers, agentTriggerFromToolResult(block.name, result));
      results.push({ type: "tool_result", tool_use_id: block.id, content: JSON.stringify(result) });
    }

    messages.push({ role: "user", content: results });
  }

  // Exhausted the tool-iteration budget without a final text answer.
  return { kind: "reply", reply: FALLBACK, usedTools, agentTriggers };
}

/**
 * Runs one Nexus turn: loads the sliding-window memory, lets Claude call tools as
 * needed (bounded loop), then persists the exchange.
 */
export async function runChat(sessionId: string, text: string): Promise<ChatResult> {
  const memory = await loadMemory(sessionId);
  const messages: Anthropic.MessageParam[] = memory.map((t) => ({ role: t.role, content: t.content }));
  messages.push({ role: "user", content: text });

  const result = await runLoop(messages, [], []);
  await appendExchange(sessionId, text, result.reply, memory);
  return result;
}
