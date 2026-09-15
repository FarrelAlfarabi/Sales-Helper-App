/// Build-time config, passed via --dart-define (never hardcoded, never
/// committed as a literal). The Supabase anon/publishable key is safe to
/// ship in a client build -- that's what it's for -- but it still
/// shouldn't be a hardcoded string in source control, since rotating it
/// later means grepping for a magic value instead of editing one place.
///
/// Run with, e.g.:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://eucnjnsqmpwiwkupnxku.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_dSGk6pG_mIv2wsMeGbu5Kw_JPWo0Ldl
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
