// Thin wrapper over the Anthropic Messages API. The API key lives only in
// the ANTHROPIC_API_KEY Edge Function secret, never in the Flutter app.
export const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5";

// USD per 1M tokens (input, output). Third-party figures, check the Anthropic pricing page.
const PRICES: Record<string, [number, number]> = { "haiku": [0.1, 0.5], "sonnet": [2, 10], "opus": [5, 25] };
export type Usage = { input_tokens: number; output_tokens: number; cost_usd: number };
export function costOf(model: string, i: number, o: number): number {
  const k = Object.keys(PRICES).find((n) => model.includes(n)) ?? "sonnet";
  return (i * PRICES[k][0] + o * PRICES[k][1]) / 1e6;
}

export async function askClaude(content: unknown[], system: string, maxTokens = 2000, usage?: Usage): Promise<string> {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) throw new Error("ANTHROPIC_API_KEY secret is not set on this function");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: MODEL, max_tokens: maxTokens, system, messages: [{ role: "user", content }] }),
  });
  if (!res.ok) throw new Error(`Claude API ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  if (usage) {
    usage.input_tokens = data.usage?.input_tokens ?? 0;
    usage.output_tokens = data.usage?.output_tokens ?? 0;
    usage.cost_usd = costOf(MODEL, usage.input_tokens, usage.output_tokens);
  }
  return (data.content ?? []).filter((b: { type: string }) => b.type === "text").map((b: { text: string }) => b.text).join("");
}

/** Pull the first JSON object out of a model reply, tolerating code fences. */
export function parseJson(text: string): Record<string, unknown> {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end < start) throw new Error("Model reply had no JSON object");
  return JSON.parse(text.slice(start, end + 1));
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
