# Zonein -- Demo Walkthrough

For whoever demos this to PT. Logic Soft Computer or a client. Kept in
sync with every feature actually built -- if it's not in this doc, don't
demo it as working.

**Current state (2026-09-15): schema and backend logic are live and
verified at the database level. The Flutter app has not yet been built or
run on a device.** This doc describes the intended flow so the demo script
is ready once the app is built and tested -- don't present any of this as
already working end to end.

---

## What's real right now

- A live Supabase project with the full data model: employees, stores
  (with geofence), attendance, store visits, product placement photos.
- Real login: an employee account created by an admin, authenticated with
  a real email + password, not a placeholder.
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

## Not built yet

- Manager-facing reports (attendance history, visit history, geofence
  flags) -- data model supports it, no screens yet.
- Pricing module.
- Summary Activity module.
- Leave requests (sick / permit / off day / leave) -- only clock in/out
  exists.
- Web admin panel.

## Known, deliberate limitations to mention if asked

- Geofencing catches "wrong location," not "spoofed GPS app on a modified
  phone" -- that needs a separate hardening pass if it becomes a real
  concern.
- No photo retention policy yet -- selfies and store photos are kept
  indefinitely until we decide otherwise.
- No offline support -- a field rep with no signal can't submit until
  they have signal again.
