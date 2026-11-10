import 'package:flutter/material.dart';
import '../../core/theme_controller.dart';

import '../../core/supabase_client.dart';

/// Real Supabase Auth login -- email/password against a real
/// auth.users session. No fake/local "verification"; if the credentials
/// are wrong, Supabase rejects it and the user stays on this screen.
///
/// SCOPE: employee accounts are provisioned by an admin (Supabase
/// dashboard or Admin API), not self-signup -- there is deliberately no
/// "create account" link here. See PROJECT_NOTES.md.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SafeSetState<LoginScreen> {
  bool _obscure = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // On success, AuthGate's onAuthStateChange listener swaps to HomeScreen.
    } on AuthException catch (e) {
      setState(() => _errorMessage = friendlyError(e));
    } catch (e) {
      setState(() => _errorMessage = 'Gagal masuk: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [ThemeButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Zonein',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Mulai aktivitasmu hari ini",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Email wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _isSubmitting ? null : _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Kata sandi',
                      suffixIcon: IconButton(
                        tooltip: _obscure
                            ? 'Tampilkan kata sandi'
                            : 'Sembunyikan kata sandi',
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Kata sandi wajib diisi'
                        : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(_errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _signIn,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Masuk'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Lupa kata sandi? Hubungi admin untuk mengatur ulang.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}
