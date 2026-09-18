# Zonein -- Project Notes

Running log, session by session. Not rewritten after the fact to look
cleaner -- if a decision turned out wrong, a later entry says so instead of
silently editing an earlier one.

---

## Session 1 -- 2026-09-15

### Context

Client-facing reference material: a company profile deck for PT. Logic
Soft Computer describing their existing product "ViewLT" (Attendance with
selfie+GPS clock-in, Store Visit with geofence "zonasi" validation, On
Shelf Availability product placement photos, plus Pricing and Summary
Activity modules mentioned but not detailed). We're building a
from-scratch app in that same space, not modifying ViewLT -- renamed to
**Zonein** per the user's explicit request to pick an original name.

### Decisions made this session

- **Platform target: Flutter, Android/iOS primary, web secondary/admin
  only.** Selfie+GPS is the trust mechanism for attendance/visits; mobile
  browsers give weaker location APIs (no fused provider, background
  throttling) and get killed by OS memory management mid-shift. Android
  prioritized over iOS first, matching the likely field-rep device
  profile in Indonesia. Web is for the manager/admin report views only.
- **Deploy target (assumed, not confirmed with real accounts):** Play
  Store for Android, TestFlight for iOS once built, Vercel for the web
  admin. I have no Play Console / Apple Developer / Vercel account access
  in this environment -- this is a plan, not something verified end to
  end.
- **App name: Zonein.** User asked me to pick; this one plays on "in the
  zone" (geofence) / "zoning in."
- **Supabase project: created new, dedicated project** (`zonein`, ref
  `eucnjnsqmpwiwkupnxku`, region `ap-southeast-1`, $0/month cost
  confirmed before creating) rather than reusing the account's existing
  `FarrelAlfarabi's Project` (which was INACTIVE and is presumed leftover
  from the prior Flutter+Supabase MVP -- reusing it would have mixed two
  apps' schemas/auth in one database). This was a real cost/data decision,
  so I asked before picking.
- **Real Supabase Auth from the first migration, no fake-verification
  shortcut.** `profiles` is 1:1 with `auth.users`, populated only via a
  trigger on `auth.users` insert. There is no public self-signup path in
  the schema or the login screen -- accounts are provisioned by an admin
  (dashboard or Admin API). This is the explicit deviation from the prior
  project the user called out up front.

### Schema (applied as 9 migrations, `supabase/migrations/`, all verified
live against the `zonein` project via `list_tables` + read-back queries,
not just "it didn't error")

1. `extensions_and_helpers` -- `pgcrypto`, `set_updated_at()` trigger fn,
   `distance_meters()` haversine fn. **Verified**: called it directly --
   same point returns 0.00m, a known ~0.0088deg latitude shift returns
   978.5m (expected ~979m from 111,320m/degree latitude), so the formula
   itself is confirmed correct, not just "compiled."
2. `profiles` -- `employee_role` enum (`field_rep`/`manager`/`admin`),
   table, `handle_new_user()` trigger on `auth.users`.
3. `stores` -- includes `geofence_radius_meters` (default 100, per-store
   override).
4. `store_assignments` -- which employees can visit which stores.
5. `attendance_records` -- clock in/out, selfie path + lat/lng/accuracy
   for each. **No geofence check** -- matches the reference deck, which
   only geofences store visits, not attendance.
6. `store_visits` -- check-in lat/lng/accuracy, `distance_from_store_meters`
   and `is_within_geofence` **computed server-side by a trigger**
   (`compute_store_visit_geofence`), recalculated from the store's own
   stored lat/lng/radius on every insert/coordinate update. The client
   cannot set these two columns to whatever it wants.
7. `product_placements` -- OSA photos (`main_shelf` / `checkout_display`
   / `secondary_display`), tied to a `store_visit_id`.
8. `rls_policies` -- `is_manager_or_admin()` helper (security definer, so
   it doesn't recurse into the RLS policy it's used inside), then 14
   policies total across all 6 tables. Verified via `pg_policies` query
   after applying -- count and coverage matched what was written.
9. `storage_buckets` -- three private buckets (`attendance-selfies`,
   `store-visit-photos`, `osa-photos`), `public = false`, path convention
   `{employee_id}/{filename}` with matching storage RLS (own folder to
   insert, own folder or manager to read).

**What "verified" means here, precisely**: `list_tables(verbose)` showing
the right columns/FKs/RLS-enabled flags, a direct call to
`distance_meters()` with known inputs, and a `pg_policies` read-back. What
I did **not** do: insert a real `store_visits` row through the trigger
end-to-end, because that needs a real `employee_id` FK'd to a real
`auth.users` row, and I wasn't going to fabricate a fake auth user just to
test a trigger -- that's exactly the kind of shortcut this project is
supposed to avoid. First real end-to-end test happens when the app creates
a real test employee account.

### Geofencing: what "inside the store zone" actually means here

- Each store has `latitude`, `longitude`, `geofence_radius_meters`
  (default 100m, override per store).
- On every store visit, the server (not the client) computes the haversine
  distance from the submitted check-in coordinates to the store's stored
  center, and sets `is_within_geofence = distance <= radius`.
- **100m default is a guess, not a measurement.** Urban Jakarta GPS
  accuracy is typically 5-20m outdoors with clear sky, much worse indoors
  (mall stores get multipath drift off structure/walls) -- 100m may be too
  tight for some indoor stores and needs a per-store adjustment once we
  see real data.
- **Accuracy is recorded, not enforced.** `check_in_accuracy_meters`
  stores the device-reported horizontal accuracy at capture time. We do
  NOT reject a submission for poor accuracy (e.g. accuracy_m > 50) --
  that would make the app unusable in malls where indoor GPS is routinely
  bad. Instead the number is visible to managers reviewing reports so a
  suspicious "accuracy: 500m, marked inside zone" case is investigable,
  not hidden.
- **Denied permission / GPS off:** the app blocks the submission entirely
  (see `clock_in_screen.dart` / `store_visit_screen.dart`) -- there is no
  fallback to a null or last-known position. A clock-in or visit with no
  real location proves nothing.
- **What this does NOT defend against: GPS spoofing.** A mock-location
  app on a rooted/jailbroken or developer-unlocked device can feed fake
  coordinates to the OS location API before our code ever sees them.
  Real defense against that needs device-integrity attestation (Play
  Integrity API / Apple DeviceCheck), which is explicitly out of scope
  for this MVP pass. Don't let "geofenced" quietly imply "spoof-proof" in
  any client conversation about this.

### Explicit scope shortcuts / deferred features

- **Leave types deferred.** The reference deck's Attendance menu shows
  Sick Leave / Permit / Off Day / Leave buttons alongside Clock In/Out.
  Only clock-in/clock-out is modeled (`attendance_records`). Leave-request
  workflow (with approval?) is a real feature with its own questions
  (who approves, does it block clock-in) -- deferred, not forgotten.
- **Pricing and Summary Activity modules are not built.** The user's own
  request scoped the initial schema to employees/stores/attendance/store
  visits/product placement; Pricing and Summary Activity are mentioned in
  the reference deck but weren't in that list. Home screen has disabled
  placeholder tiles for both so the UI doesn't silently imply they exist.
- **Photo retention is undecided and currently indefinite.** Selfies and
  store/OSA photos, tied to employee identity + GPS + timestamp,
  accumulate forever in Supabase Storage with no deletion policy. This is
  a real data-privacy question (Indonesia's UU PDP likely treats
  employee-identifying photos with location/time metadata as personal
  data) with cost implications too (storage grows unbounded). **Needs a
  decision from the client/user on a retention period** -- not something
  to pick silently.
- **No image compression/resizing before upload.** Selfies and store
  photos upload at whatever resolution the camera returns. Fine for an
  MVP demo, will matter for mobile data usage and storage cost at real
  volume.
- **No offline queue.** If a field rep has no signal when clocking in or
  visiting a store, the submission just fails right now -- there's no
  local queue-and-retry. Real field conditions (basements, rural stores)
  will hit this.
- **Package API note:** `geolocator`'s `getCurrentPosition` deprecated the
  old `desiredAccuracy` parameter in favor of `locationSettings:
  LocationSettings(...)` -- confirmed by downloading the actual
  `geolocator` 14.0.3 package source from pub.dev and grepping it (not
  from memory), since the brief specifically asked for that check. Package
  versions in `pubspec.yaml` (`supabase_flutter` 2.17.2, `geolocator`
  14.0.3, `image_picker` 1.2.3, `permission_handler` 13.0.2) are each
  pub.dev's actual latest at time of writing, also checked live rather
  than assumed.

### What's NOT verified (be honest about this)

- **No Flutter SDK in this build environment.** `flutter analyze`,
  `flutter pub get`, `flutter run` -- none of these have been run. The
  Dart code in `lib/` is a first draft, not a build-verified one.
- **No native platform folders yet** (`android/`, `ios/`, `web/`) --
  these need `flutter create` run locally (see README.md) before this
  can build at all.
- **Camera/location permission behavior is unverified on real
  Android/iOS.** This is exactly the category of thing the brief called
  out as needing real-device testing, not assumed-from-docs testing.
- **Storage bucket RLS policies are applied and read back via
  `pg_policies`-equivalent checks, but not exercised with a real upload**
  (same reason as the store_visits trigger -- no real employee account
  created yet in this session).

### Next

1. Run `flutter create` locally, `flutter pub get`, `flutter analyze` --
   fix whatever that surfaces (there will likely be something; this was
   written without a compiler).
2. Create a real first admin account + a test employee account, then
   actually exercise clock-in and a store visit against the live project
   to get a genuine end-to-end verification instead of a schema-level one.
3. Decide photo retention policy (needs the user).
4. Decide leave-request scope (needs the user, since it changes the
   Attendance data model).
5. Pricing and Summary Activity: not started, no schema yet.

---

## Session 2 -- 2026-09-16

User ran the app for real (`flutter run -d web-server`) on a GitHub
Codespace -- first actual compiler run this project has had. It found
real bugs, exactly as expected/flagged in Session 1.

### Bug found and fixed: missing imports crashed the web compiler

`login_screen.dart`, `clock_in_screen.dart`, `store_visit_screen.dart`,
and `osa_screen.dart` all use Supabase types (`AuthException`,
`FileOptions`) but only imported `core/supabase_client.dart` -- not
`package:supabase_flutter/supabase_flutter.dart` directly. Dart imports
are not transitive, so those types were unresolved. Two symptoms from one
root cause:

- `on AuthException catch (e)` -> `Error: 'AuthException' isn't a type.`
- `const FileOptions(contentType: 'image/jpeg')` (three call sites) ->
  `Error: Not a constant expression.`
- The `AuthException` one was worse than a normal compile error: dartdevc
  (the web dev compiler) doesn't handle an unresolved type flowing into a
  `catch` clause gracefully and crashed outright ("Unsupported operation:
  Unsupported invalid type InvalidType"), which is what produced the
  opaque "Dart compiler exited unexpectedly" failure the user hit first.

**Before assuming the import fix was the whole story**, checked whether
`FileOptions`'s constructor is actually `const`-eligible in the real
installed version (2.8.0 of `storage_client`, resolved via
`supabase_flutter` 2.17.2 -> `supabase` 2.16.1 -> `storage_client` 2.8.0)
by downloading that exact package source from pub.dev and reading the
class definition directly -- confirmed `const FileOptions({...})`, so the
`const` usage was always valid and the error really was just the missing
import, not a second bug.

**Fix**: added `export 'package:supabase_flutter/supabase_flutter.dart';`
to `core/supabase_client.dart` instead of adding the same import to four
files separately -- any file importing `core/supabase_client.dart` for
the `supabase` getter now gets Supabase's types too.

### Still not verified

This fixes the specific compile errors reported. It has **not** been
re-run -- I don't have a Flutter SDK in this environment, only the
package sources I downloaded to check the fix. The user needs to `git
pull` and re-run `flutter run -d web-server` to confirm this was the only
issue; there could be more compile errors behind this one that just
hadn't been reached yet.

Also worth noting for whoever debugs the next one: the Codespaces
`flutter build web` / `flutter run -d web-server` proceeded without web
platform files present ("This application is not configured to build on
the web" was a warning, not a hard stop) -- `flutter create --platforms
android,web .` from the README still needs to actually be run at some
point; it was skipped in this session's test run.

### Bug found and fixed: permanent white screen on slow/stuck init

After the import fix, the user hit a second real issue: the app compiled
and served, but the browser tab just showed a permanent blank white
screen, no spinner, no error, no console output reported.

Root cause: `main()` did `await core.initSupabase()` **before**
`runApp()`. Nothing paints to the screen until `runApp()` is called, so if
that Supabase init call is slow, blocked (e.g. a network/CORS quirk in
the Codespaces container), or just taking a while on a debug web build,
the tab stays blank indefinitely with zero user-visible signal that
anything is happening or wrong.

**Fix**: moved `runApp()` to happen immediately in `main()`, and added a
`BootGate` widget that runs `initSupabase()` afterward, behind a
`FutureBuilder` with a 15s timeout -- shows a spinner while connecting,
an actual error message on failure/timeout, and only then hands off to
`AuthGate`. The 15s figure is a guess for a debug web build on a
Codespace, not measured -- may need tuning.

**Not yet confirmed this was the (only) cause of the white screen** -- I
never got the browser console output from the stuck session to confirm
it definitively; this fix addresses the general failure mode (silent
blank screen on any startup failure) regardless of the specific trigger.
If the white screen recurs after this fix, it'll now show either a
spinner (still loading -- give it longer) or a real error message
(actual bug to chase), which narrows the next debugging step
considerably compared to "it's just white."

By this point the user had created a real admin account through the
Supabase dashboard (`profiles` shows 1 row) -- first real account this
project has had.

---

## Session 3 -- 2026-09-18

User asked to "finish all of it" against the full gap list from Session
2. Pushed back on treating that as one task: some of it is buildable
immediately from the existing schema, some needs a decision first
(building blind wastes real work), some is structurally impossible from
this environment. Built the unambiguous, unblocked part now.

### Added this session (schema + Flutter screens, applied and verified)

- **`leave_requests` migration** (10th migration) -- sick/permit/off-day/
  leave, simple `pending -> approved/rejected` status, reviewed by any
  manager/admin (no reporting-line concept exists), employee can cancel
  only while still pending. Does NOT interact with clock-in/out in any
  way -- deliberately not wired together, since whether approved leave
  should block clock-in is a policy call nobody's made. Verified live via
  `list_tables` (RLS enabled, table present).
- **`lib/features/leave/leave_screen.dart`** -- employee: submit a
  request, see own history, cancel while pending.
- **`lib/features/leave/leave_review_screen.dart`** -- manager: list
  pending requests across everyone, approve/reject.
- **`lib/features/admin/store_management_screen.dart`** -- manager: list
  stores, add a new one. Lat/lng are typed in by hand, no map picker --
  flagged in-file because a typo here silently breaks geofencing for that
  whole store with no in-app safeguard.
- **`lib/features/admin/store_assignment_screen.dart`** -- manager:
  assign a field_rep to a store, view/deactivate current assignments.
  Verified the `upsert(..., onConflict: 'employee_id,store_id')` call
  against postgrest 2.9.1's actual source (downloaded from pub.dev) rather
  than assuming the parameter shape.
- **`lib/features/reports/attendance_report_screen.dart`** and
  **`store_visit_report_screen.dart`** -- manager: read-only history
  views. Visit report surfaces the server-computed `is_within_geofence`
  flag directly, which is the whole point of the trigger from Session 1.
  Both capped at 200 rows, no pagination yet -- fine for a demo, not for
  real volume.
- **`home_screen.dart`** rewritten to fetch the signed-in user's role from
  `profiles` and show the five manager-only tiles only to
  `manager`/`admin`. Note: hiding a tile is a UI convenience, not access
  control -- RLS on the underlying tables is what actually stops a
  `field_rep` from reading/writing manager-only data, same as always.

### Explicitly declined to build blind, asked the user instead

- **Pricing and Summary Activity modules**: the reference deck names
  them with zero description of what they do. There's nothing to build a
  schema from without guessing at business requirements that are the
  client's to define, not mine.
- **In-app employee account creation**: doing this from the Flutter
  client would require either a Supabase Edge Function holding the
  secret `service_role` key (real work, correct architecture) or
  embedding that key in the client app (a severe vulnerability -- it
  would let anyone who decompiles the app read/write the entire
  database, not just create users). Declined to build the insecure
  version regardless of how the request is phrased; asked whether the
  Edge Function is worth building or manual dashboard provisioning stays
  fine.

### Still structurally impossible from this environment (unchanged from
Session 2, restated because "finish all of it" implied otherwise)

- No Flutter SDK here -- `android/`/`ios/` folders still not generated,
  nothing in this session was run or analyzed, same caveat as every prior
  session's code.
- No Play Console / Apple Developer / Vercel accounts -- cannot deploy
  anything anywhere.
- No real phone -- camera/GPS permission behavior for any screen,
  old or new, remains unverified on real hardware.
- Push notifications -- not attempted; needs Firebase/APNs setup plus a
  decision on what should actually trigger one.

### Next

1. Answer on Pricing/Summary Activity scope, and on the Edge Function
   question, before more admin-side work happens.
2. Run `flutter create`, `flutter pub get`, `flutter analyze` on all of
   this -- none of this session's code has been compiled, same caveat as
   every session so far.
3. Exercise the new screens for real now that a real admin account
   exists: add a real store, assign yourself to it, submit a leave
   request, approve it as admin, and see if the reports actually render
   real rows correctly.

---

## Session 4 -- 2026-09-18 (later same day)

User asked for an admin-only dashboard to create new employee accounts
(answering Session 3's open question), gated to their own login
specifically. Also reported the white screen again after Session 3's
push, with no fresh terminal/console output provided yet.

### Security fix found while building this (before the feature itself)

While designing "admin login is the only thing that can access it,"
re-read the `profiles_update_own` RLS policy from Session 1 and found it
never restricted which columns a user could change on their own row --
including `role`. As written since Session 1, **any authenticated
field_rep could have run `update profiles set role = 'admin'` on
themselves from the app and granted themselves admin/manager access.**
This was live for 3 days before being caught.

Fixed via migration `prevent_role_self_escalation`: a `before update`
trigger on `profiles` that raises an exception if `role` changes and the
actor isn't already manager/admin (checked via the existing
`is_manager_or_admin()`, skipped when `auth.uid()` is null, i.e. a
trusted direct-SQL/dashboard context). Verified live: confirmed the
trigger exists in `pg_trigger`, and confirmed a service-context update
still succeeds (didn't break normal SQL-based admin work). **Not**
verified against an actual non-admin authenticated session attempting the
escalation, since that needs a second real test account and a real JWT,
which this environment can't produce -- logic-reviewed, not
exercised end-to-end.

### Also found while testing: the admin account wasn't actually admin

Queried `profiles` directly and found the account created in Session 2
had `role = 'field_rep'`, not `admin` -- the `role` metadata either wasn't
set when the account was created via the dashboard, or wasn't read
correctly. This means **every manager-only tile added in Session 3 was
never actually visible** to the user testing it; that's a likely
contributing factor to confusion about what was/wasn't working, separate
from the white-screen issue. Promoted the account to `admin` directly
via SQL (verified by reading the row back).

### Added: admin-only "Add Employee" feature

- **`supabase/functions/admin-create-user/index.ts`** -- a Supabase Edge
  Function, deployed and ACTIVE. This exists specifically because
  creating a Supabase Auth user requires the `service_role` key, which
  must never reach the Flutter client (embedding it there would let
  anyone who decompiles the app read/write the entire database, not just
  create accounts) -- declined that approach even though it would've
  been less work, as noted in Session 3.
  - Authorization is two independent checks, both required: (1) the
    caller's own JWT is verified against Supabase Auth (not a
    client-supplied claim) and its email must exactly match
    `ADMIN_EMAIL`; (2) the caller's `profiles.role` must be `admin`,
    checked with the service-role client. Requested explicitly: gate this
    to one specific login, not just "any admin."
  - `ADMIN_EMAIL` is read from an environment secret with a hard-coded
    fallback of `farrel.abi.saleh@gmail.com` (the email on file for this
    account) -- **I don't have a tool that can set Supabase Edge Function
    secrets**, so right now the function is actually running on the
    hard-coded fallback, not a secret. To move it to a real secret and
    stop relying on the fallback: Supabase Dashboard -> Edge Functions ->
    `admin-create-user` -> Secrets, add `ADMIN_EMAIL`, or `supabase
    secrets set ADMIN_EMAIL=...` via the CLI. Flagging plainly that this
    email is currently sitting in committed source as plaintext, not a
    secret store, since that's a call about this specific repo's
    visibility the user should make consciously rather than discover
    later.
  - Validates password length (>=8) and constrains `role` to the three
    known enum values before calling `auth.admin.createUser(...)`.
  - **Deployed but not test-invoked end to end.** I have no way to obtain
    a real user JWT from this environment (would need the actual account
    password), so the actual request/response flow through Supabase Auth
    has not been exercised -- the first real use of the "Add Employee"
    screen in the app IS that test. If it fails, the error will come back
    from this function's own checks (401/403/400 with a message) rather
    than a generic crash, which should make it diagnosable.
- **`lib/features/admin/user_management_screen.dart`** -- form (full
  name, email, temporary password, role) that calls the Edge Function via
  `supabase.functions.invoke`. Verified the `invoke()` signature and
  `FunctionException` shape against the actual installed `functions_client`
  2.7.1 source rather than assuming.
- **`home_screen.dart`**: "Add Employee" tile shown only when
  `currentUser.email == 'farrel.abi.saleh@gmail.com'` (case-insensitive),
  not merely `role == 'admin'` -- matches the explicit "use my email"
  request. Same caveat as every other tile: this is display logic only,
  the Edge Function's own checks are the real gate.

### White screen reported again -- unresolved, need fresh diagnostics

No new terminal or browser console output was provided with this report,
so I can't yet tell whether it's: (a) a new compile error from Session
3's additions never actually reaching a clean build, (b) the Session 2
BootGate fix not actually being live (old process still running / not
hot-restarted), or (c) something new. Asked the user directly for the
same diagnostics as before (terminal output since `git pull` and browser
console). Not fixing blind a second time on this one.

### Still open from Session 3, unchanged

- Pricing and Summary Activity: still no spec.
- Native platform folders, real-device verification, deployment, push
  notifications: still not possible from this environment.
