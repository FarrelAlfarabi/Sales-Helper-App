# Zonein: attendance rules and features (as built)

Source: migration files and app code in the repo. "Not enforced" means the app does not check it at all.

## 1. Attendance rules (Absensi)

Enforced
- Clock in needs GPS on and location permission granted. If not, it fails.
- Clock in needs a selfie from the front camera. Clock out needs a selfie too.
- Clock in time is set by the database. Clock out time comes from the phone clock.
- GPS accuracy (meters) is saved with each clock in and out. It is shown to managers but never rejects anything.
- While a record has no clock out, the screen only offers "Absen Pulang". So the app blocks a second clock in until you clock out.
- Employees see their own records. Managers and admins see all records.
- Selfies are in a private storage bucket. Only the owner and managers/admins can open them.

NOT enforced
- No radius or geofence for attendance. Anyone can clock in from anywhere. Location is only a record.
- No work hours, no shift, no "late" status, no overtime. The app cannot say who is late.
- No limit of one clock in per day. No auto close. If someone forgets to clock out, the record stays open (even into the next day) until they clock out.
- No fake GPS detection.
- No manager approval or correction flow for attendance.
- Approved leave does not block or change attendance.

Gap you should know about (not fixed)
- The database rule lets a rep update any column of their own attendance row. Through the API a rep could change times or coordinates of their own record, because only the app UI stops it. Same for store visits: the "inside zone" flag is recomputed only when coordinates or store change, so a rep could set it directly. Fix is a small database change (restrict updates, or lock those columns). I have not made it. Say if you want it.

## 2. Store visits
- Rep picks an assigned store, takes a store photo, GPS captured.
- Server computes the distance to the store and the flag "inside zone" from the store's radius (default 100 m, set per store). The rep cannot send these values on insert.
- Outside the radius: the visit is still saved, but flagged "outside zone" in the manager report. It is not blocked.
- No visit end time is recorded (the column exists but nothing sets it).
- No fake GPS detection.

## 3. Features by role

### Field rep (sales)
- Absensi: clock in and out with selfie + GPS (rules above).
- Kunjungan Toko: check in at an assigned store with photo, then Ketersediaan di Rak: photo of main shelf, checkout display, secondary display. Not required to photograph all three.
- Cek Rak: photo of a shelf aisle, AI returns restock actions. AI accuracy on real shop photos is not tested yet.
- Input Penjualan: units sold per product, store, date. No money value. No edit after save.
- Harga: report shelf price and promo flag per product and store.
- Cuti: request sick, permit, off day, leave. Can cancel while pending. No leave balance.
- Laporan Kehadiran: own attendance history, max 200 rows, date filter.
- Ringkasan Aktivitas: this month's counts of attendance, visits (inside / outside zone), pending leave.
- Rep only works in stores assigned to them.

### Manager (also has all rep features)
- Wawasan AI: AI summary of sales, price and shelf data for a period. Uses AI credit. Credit card is an estimate against a $5 budget, not an official balance.
- Kelola Toko: add and edit stores, location, radius. CSV import.
- Penugasan Toko: assign reps to stores. CSV import.
- Tinjau Pengajuan Cuti: approve or reject. Any manager or admin can review anyone (no per-employee supervisor).
- Laporan Absensi: all employees' attendance with selfie, location, accuracy.
- Laporan Kunjungan Toko: all visits, distance, inside/outside zone, zone map.

### Admin
- Same as manager.
- Tambah Karyawan: only the account farrel.abi.saleh@gmail.com sees it and the server also checks that email. Gilang and Maria are admins but do not see this menu.
- No change-password screen yet. No screen to disable or delete a user.

## 4. Known gaps
- Attendance and store visit rows can be edited by their owner through the API (see the gap under section 1).
- No change-password screen, no disable or delete user.

## 4b. Data and privacy
- No retention policy: selfies and photos are kept forever. This is a legal question under Indonesia's UU PDP that needs your decision.

## 5. Help in the app
- Help button (?) on every screen with: what it does, who uses it, steps, rules, and a red list of "not built / not checked". All in Indonesian.
- A description line under every home menu item.
- A "Panduan Zonein" help sheet on the home screen.
