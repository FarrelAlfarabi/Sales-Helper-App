import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';

/// Create new employee accounts. Only reachable from the home screen's
/// tile logic when the signed-in email matches the hard-coded admin
/// email, but that's a UI convenience, not the real access control -- the
/// `admin-create-user` Edge Function independently re-checks both that
/// exact email AND role='admin' server-side before creating anything, so
/// this screen being visible/reachable is never itself a security
/// boundary.
///
/// Not run on a real device. The Edge Function it calls has been deployed
/// but not yet exercised with a real request -- first use of this screen
/// IS that test.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _role = 'field_rep';
  bool _submitting = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final response = await supabase.functions.invoke(
        'admin-create-user',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _fullNameController.text.trim(),
          'role': _role,
        },
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        setState(() => _error = data['error'] as String);
        return;
      }

      setState(() {
        _successMessage = 'Created ${_emailController.text.trim()} as $_role.';
        _emailController.clear();
        _passwordController.clear();
        _fullNameController.clear();
        _role = 'field_rep';
      });
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] : e.reasonPhrase;
      setState(() => _error = message?.toString() ?? 'Request failed (${e.status}).');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Employee')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary password',
                  helperText: 'At least 8 characters. Share this with the employee directly.',
                ),
                validator: (v) =>
                    (v == null || v.length < 8) ? 'At least 8 characters' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'field_rep', child: Text('Field Rep')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v!),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Text(_successMessage!, style: const TextStyle(color: Colors.green)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Creating...' : 'Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
