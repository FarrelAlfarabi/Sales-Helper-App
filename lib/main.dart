import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_client.dart' as core;
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase init used to be awaited here, before runApp() -- meaning
  // nothing painted at all (a blank white tab, no spinner, no error) until
  // it finished. If that call is slow or silently stuck (blocked network,
  // wrong URL/key), the user just sees a permanently white screen with no
  // signal anything is wrong. Found from a real "white screen" report with
  // no console errors -- moved init to run *after* the first frame, behind
  // a visible loading/error state (see BootGate below).
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
      home: const BootGate(),
    );
  }
}

/// Runs Supabase init with a visible loading state and a hard timeout, so a
/// slow/blocked network call shows an error instead of an indefinite blank
/// screen. 15s is a guess for a debug web build on a Codespace, not a
/// measured value -- revisit if it's too tight for slower connections.
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  late final Future<void> _init = core.initSupabase().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          'Timed out connecting to Supabase after 15s. Check your network '
          'connection and that --dart-define=SUPABASE_URL and '
          '--dart-define=SUPABASE_ANON_KEY were passed correctly.',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to start Zonein:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return const AuthGate();
      },
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
