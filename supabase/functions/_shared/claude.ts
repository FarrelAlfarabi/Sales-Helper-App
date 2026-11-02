// Thin wrapper over the Anthropic Messages API. The API key lives only in
// the ANTHROPIC_API_KEY Edge Function secret, never in the Flutter app.
export const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5";

export async function askClaude(content: unknown[], system: string, maxTokens = 2000): Promise<string> {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) throw new Error("ANTHROPIC_API_KEY secret is not set on this function");
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: MODEL, max_tokens: maxTokens, system, messages: [{ role: "user", content }] }),
  });
  if (!res.ok) throw new Error(`Claude API ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
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
