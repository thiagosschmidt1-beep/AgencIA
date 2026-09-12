import "server-only";
import { env } from "@/lib/env";

const TTS_MODEL = "tts-1";
// Warm/conversational voice — good fit for a live assistant. Configurable via env.
const TTS_VOICE = process.env.OPENAI_TTS_VOICE ?? "nova";

/**
 * Streams speech for `text` via OpenAI TTS. Returns the raw upstream Response
 * so the caller can pipe the audio stream directly to the browser.
 */
export async function synthesizeStream(text: string): Promise<Response> {
  return fetch("https://api.openai.com/v1/audio/speech", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.openaiApiKey()}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: TTS_MODEL,
      input: text,
      voice: TTS_VOICE,
      response_format: "mp3",
    }),
  });
}
