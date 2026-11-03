import 'package:flutter/material.dart';

import '../../core/help.dart';
import '../../core/supabase_client.dart';
import 'csv_import_screen.dart';

/// Manager/admin: list stores and add new ones.
///
/// SCOPE SHORTCUT: latitude/longitude are typed in by hand, no map picker.
/// Getting a store's coordinates wrong here directly breaks geofencing for
/// every visit to that store, so whoever enters this should look the
/// address up on Google Maps and copy the coordinates precisely -- there's
/// no in-app safeguard against a typo. A map-pin picker is future work.
///
/// Not run on a real device.
class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await supabase.from('stores').select().order('name');
      setState(() => _stores = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Gagal memuat toko: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openAddStoreForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewStoreSheet(),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toko'),
        actions: [
          const HelpButton(HelpTopic.stores),
          IconButton(
            tooltip: 'Impor dari CSV',
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      const CsvImportScreen(kind: CsvImportKind.stores)));
              _load();
            },
          ),
        ],
        bottom: const HelpBar(HelpTopic.stores),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStoreForm,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Toko'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  for (final s in _stores)
                    Card(
                      child: ListTile(
                        title: Text('${s['name']} (${s['code']})'),
                        subtitle: Text(
                          '${s['address'] ?? 'No address'}\n'
                          'Geofence: ${s['geofence_radius_meters']}m radius'
                          '${s['is_active'] == false ? ' -- INACTIVE' : ''}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _NewStoreSheet extends StatefulWidget {
  const _NewStoreSheet();

  @override
  State<_NewStoreSheet> createState() => _NewStoreSheetState();
}

class _NewStoreSheetState extends State<_NewStoreSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await supabase.from('stores').insert({
        'code': _codeController.text.trim(),
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'latitude': double.parse(_latController.text.trim()),
        'longitude': double.parse(_lngController.text.trim()),
        'geofence_radius_meters': int.parse(_radiusController.text.trim()),
        'created_by': supabase.auth.currentUser!.id,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Toko Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Kode toko'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama toko'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Alamat (opsional)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Lintang'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null ? 'Tidak valid' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Bujur'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    validator: (v) =>
                        double.tryParse(v ?? '') == null ? 'Tidak valid' : null,
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _radiusController,
              decoration:
                  const InputDecoration(labelText: 'Radius geofence (meter)'),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  int.tryParse(v ?? '') == null ? 'Tidak valid' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
