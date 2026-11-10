import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';

/// Daftar aksi sales di rak. Kode di sini harus sama dengan constraint
/// shelf_check_actions_codes di migrasi 20261108110000.
const kShelfActionLabels = <String, String>{
  'rearranged': 'Menata ulang / merapikan produk',
  'filled_gap': 'Mengisi rak kosong (restok)',
  'placed_new_product': 'Menaruh produk baru di rak',
  'moved_better_position': 'Memindah produk ke posisi lebih baik',
  'installed_promo': 'Memasang materi promo (banner, wobbler, dll)',
  'fixed_price_tag': 'Memasang / memperbaiki label harga',
  'secondary_display': 'Memasang display tambahan',
  'removed_damaged': 'Menarik produk rusak atau kedaluwarsa',
  'negotiated_space': 'Negosiasi ruang rak dengan toko',
  'no_action': 'Tidak ada tindakan',
};

/// Mengubah hasil query (kolom `actions`) menjadi daftar kode.
List<String> shelfActionCodes(Object? v) =>
    [...((v as List?) ?? const [])].map((e) => '$e').toList();

/// PostgREST bisa mengembalikan relasi satu-ke-satu sebagai Map atau List.
Map<String, dynamic>? firstRelation(Object? v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is List && v.isNotEmpty && v.first is Map) {
    return Map<String, dynamic>.from(v.first as Map);
  }
  return null;
}

/// Kartu "Yang kamu kerjakan di rak". Sales pemilik cek rak bisa mengisi dan
/// mengubah; manajer hanya melihat.
class ShelfActionsCard extends StatefulWidget {
  const ShelfActionsCard({
    super.key,
    required this.shelfCheckId,
    required this.canEdit,
  });

  final String shelfCheckId;
  final bool canEdit;

  @override
  State<ShelfActionsCard> createState() => _ShelfActionsCardState();
}

class _ShelfActionsCardState extends State<ShelfActionsCard> with SafeSetState<ShelfActionsCard> {
  final _note = TextEditingController();
  final Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final row = await supabase
          .from('shelf_check_actions')
          .select('actions, note')
          .eq('shelf_check_id', widget.shelfCheckId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        if (row != null) {
          _selected
            ..clear()
            ..addAll(shelfActionCodes(row['actions']));
          _note.text = (row['note'] ?? '') as String;
          _saved = true;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat catatan: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.from('shelf_check_actions').upsert({
        'shelf_check_id': widget.shelfCheckId,
        'employee_id': supabase.auth.currentUser!.id,
        'actions': _selected.toList(),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      }, onConflict: 'shelf_check_id');
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Catatan tersimpan')));
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal menyimpan: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    // Tampilan baca saja (manajer, atau sales lain).
    if (!widget.canEdit) {
      final chosen = kShelfActionLabels.keys.where(_selected.contains).toList();
      final note = _note.text.trim();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chosen.isEmpty && note.isEmpty)
                  Text('Sales belum mencatat tindakan di rak ini.',
                      style: t.bodySmall)
                else ...[
                  for (final c in chosen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle,
                                size: 18, color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(kShelfActionLabels[c]!)),
                          ]),
                    ),
                  if (note.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(note)),
                ],
                if (_error != null)
                  Text(_error!, style: TextStyle(color: cs.error)),
              ]),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Centang yang sudah kamu kerjakan di rak ini.',
              style: t.bodySmall),
          const SizedBox(height: 4),
          for (final e in kShelfActionLabels.entries)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(e.value),
              value: _selected.contains(e.key),
              onChanged: (v) => setState(() {
                _saved = false;
                if (v == true) {
                  _selected.add(e.key);
                  // "Tidak ada tindakan" tidak boleh bersama aksi lain.
                  if (e.key == 'no_action') {
                    _selected.removeWhere((k) => k != 'no_action');
                  } else {
                    _selected.remove('no_action');
                  }
                } else {
                  _selected.remove(e.key);
                }
              }),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 1000,
            onChanged: (_) => setState(() => _saved = false),
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              helperText:
                  'Contoh: promo diskon dipasang di rak tengah, produk baru di sebelah kiri.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan...' : 'Simpan catatan'),
            ),
            if (_saved && !_saving)
              const Padding(
                  padding: EdgeInsets.only(left: 12), child: Text('Tersimpan')),
          ]),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: cs.error))),
        ]),
      ),
    );
  }
}
