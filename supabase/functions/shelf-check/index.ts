// Shelf Check: a rep photographs a product aisle; Claude (vision) reports
// which products look low or out of stock. The result is stored in
// shelf_checks using the CALLER's session, so RLS applies (a rep can only
// write rows as themselves, and only read photos in their own folder).
//
// LIMITS, stated so nobody over-trusts it: one photo shows the front of the
// shelf only. It cannot see backstock, and facing counts are estimates.
// Output is a prompt for the rep/manager to check, not an inventory count.
//
// NOT YET DEPLOYED OR TEST-INVOKED. Needs the ANTHROPIC_API_KEY secret.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { askClaude, json, MODEL, parseJson, type Usage } from "../_shared/claude.ts";

const SYSTEM = `You review one photo of a retail shelf (FMCG: food, drinks, household, personal care) for a field sales rep in Indonesia.
LANGUAGE: write every free-text value (summary, notes, descriptions, analysis, key actions, limits, gap and issue text) in Bahasa Indonesia, simple and direct. Keep JSON keys and the fixed values ("ok"/"low"/"out", "high"/"medium"/"low", "now"/"this_visit"/"next_visit", "rep"/"manager", "top"/"eye"/"middle"/"bottom"/"unknown") exactly as written in English.
Report only what is visible. Never invent brands, counts, prices or shelf positions. If a label is unreadable, name the product by category (for example "unidentified instant noodles") and lower the confidence.
The user message may list "focus brands" (the rep's own brands). If it does, mark each product is_focus_brand true/false and compute our_share_pct. If it does not, set is_focus_brand and our_share_pct to null and treat every brand equally.

Definitions:
- facings: number of units visible side by side at the front of that product's slot, summed across rows. Estimate, whole number, or null if you cannot tell.
- share_pct: that product's facings divided by total visible facings x 100, rounded. Only when facings are known.
- status: "out" = empty slot or gap where the product clearly belongs (price tag with no product, bare shelf); "low" = one or two facings, a thin row, or a mostly empty slot; "ok" = well stocked.
- shelf_row: "top", "eye" (roughly eye height), "middle", "bottom" or "unknown". Eye level sells best, so note when a focus brand sits at the bottom or a competitor holds eye level.
- price_tag: seen true only if a shelf price label for that product is legible. price_idr only if the number is clearly readable, in rupiah as an integer, else null. promo true if a promo or discount label is visible.
- gaps: each empty or thin spot, with where it is (for example "second shelf, left of the noodles") and what product likely belongs there only if a price tag or neighbouring layout shows it.
- placement_issues: mixed products in one slot, products facing sideways or backwards, misplaced items, missing or wrong price tags, competitor blocking, damaged or dusty stock if visible.
- analysis: 3 to 6 observations a supervisor would find useful, each with the evidence you counted ("5 of 24 facings").
- key_actions: 3 to 6 concrete next steps for the rep, ordered by priority 1 = most urgent. Each names the product, says exactly what to do (for example "Pull 2 cases of X from the backroom and fill the gap on the second shelf"), and why. urgency: "now" (do before leaving the store), "this_visit", or "next_visit". owner: "rep" or "manager" (use manager for pricing disputes, space negotiation, supply problems).
- limits: 1 to 3 short, specific statements of what this photo cannot show (backstock, shelves out of frame, hidden rows, unreadable labels). Always include what you could not verify.

Reply with ONLY a JSON object, no prose, in exactly this shape:
{"photo_quality":{"usable":boolean,"issue":string|null},
 "shelf":{"category":string,"total_facings":number|null,"fullness_pct":number|null,"our_share_pct":number|null,"summary":string},
 "products":[{"name":string,"brand":string|null,"status":"ok"|"low"|"out","facings":number|null,"share_pct":number|null,"shelf_row":string,"is_focus_brand":boolean|null,"price_tag":{"seen":boolean,"price_idr":number|null,"promo":boolean},"confidence":"high"|"medium"|"low","note":string}],
 "gaps":[{"location":string,"description":string,"likely_product":string|null}],
 "competitors":[{"brand":string,"facings":number|null,"share_pct":number|null,"note":string}],
 "placement_issues":[{"issue":string,"detail":string}],
 "analysis":[{"title":string,"detail":string,"evidence":string}],
 "key_actions":[{"priority":number,"action":string,"product":string|null,"why":string,"urgency":"now"|"this_visit"|"next_visit","owner":"rep"|"manager"}],
 "restock_priority":[string],
 "summary":string (2 sentences max, plain words),
 "limits":[string]}
fullness_pct is your estimate of how full the visible shelf space is. "competitors" lists only when focus brands were given; otherwise return an empty array.
If the photo is not a shelf or is unusable, set usable false, explain in issue, and return empty arrays and null numbers.`;

function toBase64(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let bin = "";
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(bin);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization header" }, 401);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: u, error: ue } = await sb.auth.getUser();
  if (ue || !u.user) return json({ error: "Invalid session" }, 401);

  let body: { store_id?: string; photo_path?: string; store_visit_id?: string; focus_brands?: string };
  try { body = await req.json(); } catch { return json({ error: "Bad JSON" }, 400); }
  if (!body.store_id || !body.photo_path) return json({ error: "store_id and photo_path are required" }, 400);
  if (!body.photo_path.startsWith(`${u.user.id}/`)) return json({ error: "Photo must be in your own folder" }, 403);

  try {
    const { data: file, error: de } = await sb.storage.from("osa-photos").download(body.photo_path);
    if (de || !file) return json({ error: `Could not read photo: ${de?.message ?? "not found"}` }, 400);

    const { data: store } = await sb.from("stores").select("name").eq("id", body.store_id).single();
    const usage: Usage = { input_tokens: 0, output_tokens: 0, cost_usd: 0 };
    const reply = await askClaude([
      { type: "image", source: { type: "base64", media_type: "image/jpeg", data: toBase64(await file.arrayBuffer()) } },
      { type: "text", text: `Store: ${store?.name ?? "unknown"}. Focus brands: ${(body.focus_brands ?? "").trim().slice(0, 200) || "none given"}. Analyze this shelf photo.` },
    ], SYSTEM, 4000, usage);
    // Best effort: a failed usage log must not lose the result.
    await sb.from("ai_usage").insert({ fn: "shelf-check", model: MODEL, ...usage });
    const analysis = parseJson(reply);

    const { data: row, error: ie } = await sb.from("shelf_checks").insert({
      employee_id: u.user.id,
      store_id: body.store_id,
      store_visit_id: body.store_visit_id ?? null,
      photo_path: body.photo_path,
      summary: (analysis.summary as string) ?? ((analysis.shelf as { summary?: string } | undefined)?.summary ?? null),
      analysis,
      model: MODEL,
    }).select().single();
    if (ie) return json({ error: `Could not save result: ${ie.message}` }, 500);
    return json({ shelf_check: row });
  } catch (e) {
    return json({ error: (e as Error).message }, 502);
  }
});
