import "server-only";
import { env } from "@/lib/env";

// Turbo v2.5: low latency (~250-300ms) while keeping expressiveness — the "fast but
// expressive" sweet spot for a live voice assistant. Flash v2.5 is faster but flatter;
// v3 is more expressive but too slow for real-time streaming.
const ELEVENLABS_MODEL_ID = process.env.ELEVENLABS_MODEL_ID ?? "eleven_turbo_v2_5";

// OpenAI TTS fallback voice — "nova" is warm/conversational, close to an assistant feel.
const OPENAI_TTS_MODEL = "tts-1";
const OPENAI_TTS_VOICE = process.env.OPENAI_TTS_VOICE ?? "nova";

/**
 * Streams speech for `text`. Tries ElevenLabs first; falls back to OpenAI TTS
 * if ElevenLabs credentials are missing or the upstream request fails.
 * Returns a streaming Response with audio/mpeg so the caller can pipe it directly.
 */
export async function synthesizeStream(text: string): Promise<Response> {
  // Try ElevenLabs when credentials are present
  const elevenLabsKey = process.env.ELEVENLABS_API_KEY;
  const voiceId = process.env.ELEVENLABS_VOICE_ID;

  if (elevenLabsKey && voiceId) {
    try {
      const res = await fetch(
        `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}/stream`,
        {
          method: "POST",
          headers: {
            "xi-api-key": elevenLabsKey,
            "content-type": "application/json",
            accept: "audio/mpeg",
          },
          body: JSON.stringify({
            text,
            model_id: ELEVENLABS_MODEL_ID,
            voice_settings: {
              stability: 0.4,
              similarity_boost: 0.8,
              style: 0.3,
              use_speaker_boost: true,
            },
          }),
        },
      );

      if (res.ok) return res;

      // Capture ElevenLabs error body for diagnostics
      const errBody = await res.text().catch(() => "(unreadable)");
      console.error(
        JSON.stringify({
          level: "error",
          event: "elevenlabs_tts_failed",
          status: res.status,
          body: errBody.slice(0, 500),
        }),
      );
      // Fall through to OpenAI fallback
    } catch (err) {
      console.error(
        JSON.stringify({
          level: "error",
          event: "elevenlabs_tts_exception",
          message: err instanceof Error ? err.message : "unknown",
        }),
      );
      // Fall through to OpenAI fallback
    }
  }

  // OpenAI TTS fallback
  console.warn(
    JSON.stringify({ level: "warn", event: "tts_using_openai_fallback" }),
  );
  const openaiKey = env.openaiApiKey();
  const res = await fetch("https://api.openai.com/v1/audio/speech", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openaiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_TTS_MODEL,
      input: text,
      voice: OPENAI_TTS_VOICE,
      response_format: "mp3",
    }),
  });

  return res;
}
