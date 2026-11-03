# Zonein

Field-sales app for PT. Logic Soft Computer: attendance with selfie and GPS,
store visits checked against a store zone, shelf photos, sales and price
reports, leave requests, and AI insights for managers. Flutter (web first)
on a Supabase backend. All text inside the app is Indonesian.

## Roles

- **Sales (field_rep):** sees only their own data and their assigned stores.
- **Manager:** also sees everyone's data, manages stores and assignments, reviews leave, uses AI insights.
- **Admin:** same as manager. Only the account set in `home_screen.dart` (`_kAdminEmail`) sees "Tambah Karyawan".

Attendance and visit rules, and what is not enforced, are in
[docs/ATTENDANCE_AND_FEATURES.md](docs/ATTENDANCE_AND_FEATURES.md).

## Repo layout

| Path | What it is |
| --- | --- |
| `lib/` | Flutter app (`core/`, `features/`) |
| `web/` | Web shell: `index.html` (loader and error screen), `vercel.json` (cache headers, SPA rewrite) |
| `supabase/migrations/` | Database schema, RLS policies, storage buckets, RPCs |
| `supabase/functions/` | Edge functions: `shelf-check`, `sales-insights`, `admin-create-user` (shared code in `_shared/`) |
| `demo/` | Static clickable demo, deployed separately |
| `assets/google_fonts/` | Bundled Public Sans (app does not fetch fonts at runtime) |
| `docs/` | Feature notes and walkthrough |
| `PROJECT_NOTES.md` | Build log and decisions |

## Configuration (names only, never commit values)

App, passed at build or run time with `--dart-define`:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (the publishable key from the Supabase dashboard)

Edge functions, set as Supabase secrets:
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_MODEL` (optional)
- `ADMIN_EMAIL` (used by `admin-create-user`)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase

Never put the service role key or the Anthropic key in the app or in git.

## Run locally

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-publishable-key>
```

Android and iOS folders are not committed. Generate them with
`flutter create --org com.logicsoft.zonein --platforms=android,ios .` and add
camera and location permissions before building for phones.

## Backend

Apply the files in `supabase/migrations/` in order, then deploy the functions in
`supabase/functions/`. Self sign-up is off. Accounts are created by an admin.

## Deploy (web)

1. Build:
   ```bash
   flutter build web --release --no-web-resources-cdn \
     --dart-define=SUPABASE_URL=<your-url> --dart-define=SUPABASE_ANON_KEY=<your-publishable-key>
   ```
2. Version the app code file for long caching: in `build/web/flutter_bootstrap.js`
   change `"mainJsPath":"main.dart.js"` to `"mainJsPath":"main.dart.js?v=<first 10 chars of sha1 of main.dart.js>"`.
3. Copy `web/vercel.json` into `build/web/`.
4. Commit the contents of `build/web/` to the `web-build` branch (an orphan branch holding only build output) and
   deploy that branch with Vercel (project `zonein-app`). The `demo/` folder deploys as its own Vercel project.

`web-build` is generated output. Do not edit it by hand and do not merge it into `main`.

## Known gaps

See "Known gaps" in `docs/ATTENDANCE_AND_FEATURES.md` and `PROJECT_NOTES.md`.
