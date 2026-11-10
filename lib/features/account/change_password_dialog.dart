import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';

/// Ganti kata sandi akun yang sedang masuk. Karyawan menerima kata sandi awal
/// dari admin, jadi harus ada cara menggantinya sendiri.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
  if (ok == true && context.mounted) {
    showToast(context, 'Kata sandi berhasil diganti.');
  }
}

/// Konfirmasi sebelum keluar, supaya tidak keluar karena salah ketuk.
Future<void> confirmSignOut(BuildContext context) async {
  final ok = await confirmDialog(context,
      title: 'Keluar dari Zonein?', yes: 'Keluar');
  if (ok) await supabase.auth.signOut();
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog>
    with SafeSetState<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: _new.text));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ganti kata sandi'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _new,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Kata sandi baru',
                helperText: 'Minimal 8 karakter',
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? 'Tampilkan kata sandi'
                      : 'Sembunyikan kata sandi',
                  icon:
                      Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Minimal 8 karakter' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _again,
              obscureText: _obscure,
              decoration:
                  const InputDecoration(labelText: 'Ulangi kata sandi baru'),
              onFieldSubmitted: (_) => _saving ? null : _save(),
              validator: (v) =>
                  v != _new.text ? 'Kedua kata sandi tidak sama' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan')),
      ],
    );
  }
}
