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
