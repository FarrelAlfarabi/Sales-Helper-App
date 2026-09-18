# Zonein -- Demo Walkthrough

For whoever demos this to PT. Logic Soft Computer or a client. Kept in
sync with every feature actually built -- if it's not in this doc, don't
demo it as working.

**Current state (2026-09-18): schema and backend logic are live and
verified at the database level, with a real admin account created. The
Flutter app has not yet been compiled, analyzed, or run on a device from
this project's side** -- don't present any of this as already working end
to end until that's actually been done.

---

## What's real right now

- A live Supabase project with the full data model: employees, stores
  (with geofence), attendance, store visits, product placement photos,
  leave requests.
- Real login: a real admin account exists, authenticated with a real
  email + password, not a placeholder.
- The rule that decides "was this employee actually at the store" runs on
  the server, not the phone -- so it can't be tricked by just saying yes.

## What's built but unverified on a device

- **Login** -- email + password, real Supabase session.
- **Attendance (Clock In / Clock Out)** -- take a selfie, capture GPS
  location, submit. No geofence check on attendance (matches the
  reference product) -- it's a location record, not an "are you at the
  office" gate.
- **Store Visit** -- pick from your assigned stores, take a photo of the
  store, submit your location. The server checks whether that location
  falls inside the store's configured radius and marks the visit
  accordingly; you'll see a warning in the app if you were outside it.
- **On Shelf Availability** -- after a store visit, log a photo for each
  shelf location that applies (main shelf, checkout display, secondary
  display).
- **Leave requests** -- submit sick/permit/off-day/leave with a date
  range and reason; cancel while still pending.
- **Manager tools** (only visible to `manager`/`admin` accounts):
  - Add and list stores (geofence center + radius set by hand -- no map
    picker yet)
  - Assign employees to stores
  - Approve/reject pending leave requests
  - Attendance report and store visit report across all employees, with
    the geofence "inside/outside zone" flag shown directly on each visit
- **Add Employee** (visible only to one specific admin login) -- creates
  a real Supabase Auth account via a server-side function, so the
  database's admin key never touches the phone. Deployed, but not yet
  exercised with a real request from the app -- first real use of this
  screen doubles as its test.

## Not built yet

- Pricing module -- no spec exists for what this should do yet.
- Summary Activity module -- same.
- Web admin panel as a distinct experience -- manager tools currently
  live inside the same app as the field-rep flows, just gated by role.

## Fixed along the way, worth knowing about

- A gap in the original permissions let any employee grant themselves
  admin access by editing their own profile. Closed before the admin
  dashboard was built, since it would have defeated the point of
  restricting the dashboard at all. No evidence it was exploited --
  found during review, not from an incident.

## Known, deliberate limitations to mention if asked

- Geofencing catches "wrong location," not "spoofed GPS app on a modified
  phone" -- that needs a separate hardening pass if it becomes a real
  concern.
- No photo retention policy yet -- selfies and store photos are kept
  indefinitely until we decide otherwise.
- No offline support -- a field rep with no signal can't submit until
  they have signal again.
- Leave requests don't affect attendance in any way -- approving a leave
  request doesn't block or flag a clock-in on that date. That's a policy
  decision nobody's made yet, not an oversight.
- Reports show at most the 200 most recent rows, no pagination or
  filtering yet.
