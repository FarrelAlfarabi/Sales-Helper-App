# Zonein

Field-force attendance, geofenced store visits, and on-shelf availability
reporting for PT. Logic Soft Computer. Flutter app + Supabase backend.

See `PROJECT_NOTES.md` for the running build log, scope decisions, and
known gaps. See `docs/WALKTHROUGH.md` for a client-facing feature
walkthrough.

## Status

Schema and RLS policies are live on Supabase. The `lib/` Dart source is
written but **has not been compiled or run** -- this repo was built in an
environment with no Flutter SDK installed, so `flutter analyze` / `flutter
run` have not been executed. Treat the app code as a first draft that
needs a real build-and-run pass before it's trusted.

## Backend (Supabase)

- Project: `zonein`, ref `eucnjnsqmpwiwkupnxku`, region `ap-southeast-1`.
- URL: `https://eucnjnsqmpwiwkupnxku.supabase.co`
- Publishable key (safe to embed client-side):
  `sb_publishable_dSGk6pG_mIv2wsMeGbu5Kw_JPWo0Ldl`
- Migrations live in `supabase/migrations/`, applied directly to the live
  project (see PROJECT_NOTES.md for how each was verified).

### First admin/manager account

Self-signup is disabled by design (see PROJECT_NOTES.md). To create the
first account:

1. Supabase Dashboard -> Authentication -> Add user (or the Admin API),
   with `full_name` and `role` in the user's metadata.
2. If you didn't set `role` in metadata, promote manually:
   ```sql
   update public.profiles set role = 'admin' where id = '<user-uuid>';
   ```

## Frontend (Flutter)

This repo currently has `pubspec.yaml` and `lib/` but no generated native
platform folders (`android/`, `ios/`, `web/`) -- those need to be generated
locally with a real Flutter SDK, which this build environment did not have:

```bash
flutter create --org com.logicsoft.zonein --platforms=android,ios,web .
flutter pub get
```

That will scaffold `android/`, `ios/`, `web/` alongside the existing
`lib/` and `pubspec.yaml` without overwriting them.

Then run against the live Supabase project:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://eucnjnsqmpwiwkupnxku.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_dSGk6pG_mIv2wsMeGbu5Kw_JPWo0Ldl
```

Required device permissions (added when you run `flutter create`, but
double-check against the actual generated manifest -- unverified in this
environment):

- Android: `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` in
  `android/app/src/main/AndroidManifest.xml`.
- iOS: `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription` in
  `ios/Runner/Info.plist`.
