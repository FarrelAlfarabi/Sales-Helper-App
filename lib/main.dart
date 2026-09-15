import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client.dart' as core;
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await core.initSupabase();
  runApp(const ZoneinApp());
}

class ZoneinApp extends StatelessWidget {
  const ZoneinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zonein',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF12896F),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Routes to Login or Home based on the real Supabase Auth session -- there
/// is no "logged in" state outside of an actual auth.users session.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStateStream = core.supabase.auth.onAuthStateChange;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        core.supabase.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? core.supabase.auth.currentSession;
        return session == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}
