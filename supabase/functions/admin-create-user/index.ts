// Creates a new employee account (Supabase Auth user + profile via the
// existing handle_new_user trigger). This runs server-side specifically
// because it needs the service_role key to call auth.admin.createUser --
// that key must never reach the Flutter client, so this is the only place
// account creation can safely happen without shipping an admin key to
// every phone running the app.
//
// AUTHORIZATION: gated on the caller's own verified email matching
// ADMIN_EMAIL exactly, requested explicitly by the project owner as a
// hard-coded belt on top of (not instead of) the normal role check --
// so even if another row somehow got role='admin', it still couldn't
// call this function. Falls back to a literal default if the ADMIN_EMAIL
// secret isn't set (see PROJECT_NOTES.md for how to set it instead).
//
// NOT YET TEST-INVOKED end to end -- deployed and reviewed, but exercising
// it needs a real logged-in session's JWT, which isn't available from
// this environment. Verify with a real request before relying on it.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") ?? "farrel.abi.saleh@gmail.com").toLowerCase();

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const ALLOWED_ROLES = ["field_rep", "manager", "admin"];

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), { status: 401 });
  }

  // Validate the caller's JWT against Supabase Auth itself -- not just
  // decoding the token client-side and trusting its claims.
  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: callerData, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerData.user) {
    return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401 });
  }

  const callerEmail = (callerData.user.email ?? "").toLowerCase();
  if (callerEmail !== ADMIN_EMAIL) {
    return new Response(JSON.stringify({ error: "Not authorized" }), { status: 403 });
  }

  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // Belt and suspenders: also require role = admin on the profile,
  // checked with the service-role client (this function IS the trusted
  // server-side context, so bypassing RLS here is intentional).
  const { data: callerProfile } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", callerData.user.id)
    .single();
  if (callerProfile?.role !== "admin") {
    return new Response(JSON.stringify({ error: "Not authorized" }), { status: 403 });
  }

  let body: { email?: string; password?: string; full_name?: string; role?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), { status: 400 });
  }

  const { email, password, full_name, role } = body;
  if (!email || !password || !full_name) {
    return new Response(
      JSON.stringify({ error: "email, password, and full_name are required" }),
      { status: 400 },
    );
  }
  if (password.length < 8) {
    return new Response(
      JSON.stringify({ error: "Password must be at least 8 characters" }),
      { status: 400 },
    );
  }
  const chosenRole = ALLOWED_ROLES.includes(role ?? "") ? role : "field_rep";

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name, role: chosenRole },
  });

  if (createError) {
    return new Response(JSON.stringify({ error: createError.message }), { status: 400 });
  }

  return new Response(
    JSON.stringify({ id: created.user?.id, email: created.user?.email }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
