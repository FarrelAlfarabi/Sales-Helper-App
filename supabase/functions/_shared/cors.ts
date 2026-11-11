// Browsers (the Flutter web app) send an OPTIONS "preflight" request before
// any call that carries an Authorization header. Without these headers the
// browser blocks the real request and the app only sees "kode 0".
// Access is still checked per request with the caller's JWT, so allowing
// any origin here does not widen who can use the functions.
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Handler = (req: Request) => Response | Promise<Response>;

/** Answers the preflight and adds CORS headers to every response. */
export function withCors(handler: Handler): Handler {
  return async (req: Request) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    const res = await handler(req);
    const headers = new Headers(res.headers);
    for (const [k, v] of Object.entries(corsHeaders)) headers.set(k, v);
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
  };
}
