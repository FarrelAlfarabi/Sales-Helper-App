import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

// Re-exported so any file that imports this one for `supabase`/`initSupabase`
// also gets Supabase types (AuthException, FileOptions, etc.) without a
// separate import -- `import` isn't transitive in Dart, so without this an
// unresolved AuthException/FileOptions silently crashes the web compiler
// instead of giving a clean error (found via a real `flutter run` failure).
export 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
