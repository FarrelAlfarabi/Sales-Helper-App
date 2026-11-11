// AI insights on FMCG sales for managers/admins. The function gathers
// aggregated numbers (sales entries, shelf checks, price checks, visits) over
// a period, sends only those aggregates to Claude (no photos, no names of
// employees), and stores the answer in ai_insights.
//
// The model is told to use only the data provided and to state data gaps.
// Quality depends on how much the reps actually enter: with a few rows it
// will say so instead of guessing.
//
// NOT YET DEPLOYED OR TEST-INVOKED. Needs the ANTHROPIC_API_KEY secret.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { askClaude, json, MODEL, parseJson, type Usage } from "../_shared/claude.ts";
import { withCors } from "../_shared/cors.ts";

const SYSTEM = `You are a sales analyst for an FMCG field-sales team in Indonesia. You get aggregated data for a period and the previous period.
Use ONLY the data given. Do not invent numbers, brands or causes. If data is thin or missing for a point, say that in data_gaps instead of guessing.
LANGUAGE: write every text value (headline, findings, risks, notes, actions, data gaps) in Bahasa Indonesia. Keep JSON keys and "rep"/"manager" in English.
Write plain, short sentences a store supervisor understands. Amounts are in Indonesian rupiah where mentioned.
Reply with ONLY a JSON object:
{"headline":string,
 "findings":[{"title":string,"detail":string,"evidence":string}],
 "restock_risks":[{"product":string,"stores":[string],"why":string}],
 "price_notes":[string],
 "actions":[{"action":string,"who":"rep"|"manager","why":string}],
 "data_gaps":[string]}
Keep findings to 5 or fewer and actions to 5 or fewer, most important first. "evidence" must quote the numbers you used.
Keep the reply compact so it is never cut off: at most 4 restock_risks, 4 price_notes and 4 data_gaps, and keep each detail, evidence, why and note under 25 words.`;

type Row = Record<string, unknown>;
const sumBy = (rows: Row[], key: (r: Row) => string, val: (r: Row) => number) => {
  const m: Record<string, number> = {};
  for (const r of rows) m[key(r)] = (m[key(r)] ?? 0) + val(r);
  return m;
};

Deno.serve(withCors(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization header" }, 401);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: u, error: ue } = await sb.auth.getUser();
  if (ue || !u.user) return json({ error: "Invalid session" }, 401);
  const { data: prof } = await sb.from("profiles").select("role").eq("id", u.user.id).single();
  if (!prof || (prof.role !== "manager" && prof.role !== "admin")) return json({ error: "Managers only" }, 403);

  let days = 30;
  try { const b = await req.json(); if ([7, 30, 90].includes(b.days)) days = b.days; } catch { /* default */ }

  const day = 86400000;
  const now = Date.now();
  const cur = new Date(now - days * day).toISOString();
  const prev = new Date(now - 2 * days * day).toISOString();
  const curDate = cur.slice(0, 10);
  const prevDate = prev.slice(0, 10);

  try {
    const [sales, checks, prices, visits, stores] = await Promise.all([
      sb.from("sales_reports").select("store_id, product_name, units_sold, sale_date").gte("sale_date", prevDate).limit(5000),
      sb.from("shelf_checks").select("store_id, analysis, created_at").gte("created_at", cur).limit(1000),
      sb.from("price_reports").select("store_id, product_name, price_idr, is_promo, created_at").gte("created_at", cur).limit(3000),
      sb.from("store_visits").select("store_id, is_within_geofence, visit_started_at").gte("visit_started_at", cur).limit(3000),
      sb.from("stores").select("id, name"),
    ]);
    for (const r of [sales, checks, prices, visits, stores]) if (r.error) return json({ error: r.error.message }, 500);

    const sname: Record<string, string> = {};
    for (const s of stores.data ?? []) sname[s.id as string] = s.name as string;
    const nm = (id: unknown) => sname[id as string] ?? "unknown store";

    const salesRows = (sales.data ?? []) as Row[];
    const curSales = salesRows.filter((r) => (r.sale_date as string) >= curDate);
    const prevSales = salesRows.filter((r) => (r.sale_date as string) < curDate);
    const top = (m: Record<string, number>) => Object.entries(m).sort((a, b) => b[1] - a[1]).slice(0, 15);

    const flagged: Record<string, { low: number; out: number; stores: Set<string> }> = {};
    for (const c of (checks.data ?? []) as Row[]) {
      const ps = ((c.analysis as Row)?.products ?? []) as Row[];
      for (const p of ps) {
        if (p.status !== "low" && p.status !== "out") continue;
        const k = String(p.name);
        flagged[k] ??= { low: 0, out: 0, stores: new Set() };
        flagged[k][p.status as "low" | "out"]++;
        flagged[k].stores.add(nm(c.store_id));
      }
    }

    const priceRows = (prices.data ?? []) as Row[];
    const byProd: Record<string, number[]> = {};
    for (const p of priceRows) (byProd[String(p.product_name)] ??= []).push(p.price_idr as number);

    const visitRows = (visits.data ?? []) as Row[];
    const summary = {
      period_days: days,
      sales_rows: { current: curSales.length, previous: prevSales.length },
      units_by_product_current: top(sumBy(curSales, (r) => String(r.product_name), (r) => r.units_sold as number)),
      units_by_product_previous: top(sumBy(prevSales, (r) => String(r.product_name), (r) => r.units_sold as number)),
      units_by_store_current: top(sumBy(curSales, (r) => nm(r.store_id), (r) => r.units_sold as number)),
      shelf_checks: { count: (checks.data ?? []).length,
        flagged_products: Object.entries(flagged).map(([product, v]) => ({ product, low: v.low, out: v.out, stores: [...v.stores].slice(0, 8) })).slice(0, 25) },
      price_checks: { count: priceRows.length, promo_count: priceRows.filter((p) => p.is_promo).length,
        by_product: Object.entries(byProd).slice(0, 25).map(([product, v]) => ({ product, n: v.length, min: Math.min(...v), max: Math.max(...v) })) },
      visits: { count: visitRows.length, outside_zone: visitRows.filter((v) => v.is_within_geofence === false).length },
    };

    const usage: Usage = { input_tokens: 0, output_tokens: 0, cost_usd: 0 };
    const reply = await askClaude([{ type: "text", text: `Data for the last ${days} days (and the ${days} days before for sales):\n${JSON.stringify(summary)}` }], SYSTEM, 6000, usage);
    // Best effort: a failed usage log must not lose the result.
    await sb.from("ai_usage").insert({ fn: "sales-insights", model: MODEL, ...usage });
    const insight = parseJson(reply);
    const { data: row, error: ie } = await sb.from("ai_insights").insert({
      created_by: u.user.id, period_days: days, insight, data_summary: summary, model: MODEL,
    }).select().single();
    if (ie) return json({ error: `Could not save insight: ${ie.message}` }, 500);
    return json({ insight: row });
  } catch (e) {
    return json({ error: (e as Error).message }, 502);
  }
}));
