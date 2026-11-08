import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';

/// Manajer: kelola kampanye dan daftar foto yang wajib diambil sales.
class CampaignManagementScreen extends StatefulWidget {
  const CampaignManagementScreen({super.key});

  @override
  State<CampaignManagementScreen> createState() => _CampaignManagementScreenState();
}

class _CampaignManagementScreenState extends State<CampaignManagementScreen> {
  List<Map<String, dynamic>> _rows = [];
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
      final rows = await supabase.from('campaigns').select('id, name, photo_slots, is_active').order('name');
      setState(() => _rows = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Gagal memuat kampanye: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: '${row?['name'] ?? ''}');
    final slots = TextEditingController(
      text: row == null
          ? 'Poster di depan toko\nPoster dekat produk\nQR di kasir'
          : List<String>.from(row['photo_slots'] as List).join('\n'),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row == null ? 'Kampanye baru' : 'Ubah kampanye'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama kampanye')),
            const SizedBox(height: 12),
            TextField(
              controller: slots,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                  labelText: 'Foto yang diminta (satu per baris, 1 sampai 6)'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final list = slots.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (name.text.trim().isEmpty || list.isEmpty || list.length > 6) {
      setState(() => _error = 'Isi nama kampanye dan 1 sampai 6 nama foto.');
      return;
    }
    try {
      final data = {'name': name.text.trim(), 'photo_slots': list};
      if (row == null) {
        await supabase.from('campaigns').insert(data);
      } else {
        await supabase.from('campaigns').update(data).eq('id', row['id']);
      }
      await _load();
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan kampanye: $e');
    }
  }

  Future<void> _toggle(Map<String, dynamic> row, bool active) async {
    try {
      await supabase.from('campaigns').update({'is_active': active}).eq('id', row['id']);
      await _load();
    } catch (e) {
      setState(() => _error = 'Gagal mengubah status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Kampanye')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Kampanye baru'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              if (_error != null) Text(_error!, style: TextStyle(color: cs.error)),
              if (_rows.isEmpty) const Center(child: Text('Belum ada kampanye. Tambahkan yang pertama.')),
              for (final r in _rows)
                Card(
                  child: ListTile(
                    title: Text('${r['name']}'),
                    subtitle: Text(List<String>.from(r['photo_slots'] as List).join(' · ')),
                    onTap: () => _edit(r),
                    trailing: Switch(value: r['is_active'] == true, onChanged: (v) => _toggle(r, v)),
                  ),
                ),
            ]),
    );
  }
}
