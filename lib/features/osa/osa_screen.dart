import 'package:flutter/material.dart';
import '../../core/help.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo_capture.dart';
import '../../core/supabase_client.dart';

/// On Shelf Availability: log product placement photos for a store visit
/// (main shelf, checkout/COC cashier display, secondary display). Matches
/// the placement_type enum in the product_placements table.
///
/// Not run on a real device -- no Flutter SDK available in this
/// environment. Needs verification on actual hardware before shipping.
class OsaScreen extends StatefulWidget {
  const OsaScreen({super.key, required this.storeVisitId});

  final String storeVisitId;

  @override
  State<OsaScreen> createState() => _OsaScreenState();
}

class _OsaScreenState extends State<OsaScreen> {
  static const _placementLabels = {
    'main_shelf': 'Rak Utama',
    'checkout_display': 'Display Kasir',
    'secondary_display': 'Display Tambahan',
  };

  bool _restock = false;
  final _restockNote = TextEditingController();
  bool _finishing = false;

  @override
  void dispose() {
    _restockNote.dispose();
    super.dispose();
  }

  /// Simpan permintaan restock toko ini, lalu tutup alur kunjungan.
  Future<void> _finish() async {
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      await supabase.from('store_visits').update({
        'restock_requested': _restock,
        'restock_note': _restock && _restockNote.text.trim().isNotEmpty
            ? _restockNote.text.trim()
            : null,
      }).eq('id', widget.storeVisitId);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan permintaan restock: $e');
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  final Map<String, bool> _saving = {};
  final Map<String, bool> _saved = {};
  String? _error;

  Future<void> _logPlacement(String placementType) async {
    setState(() {
      _saving[placementType] = true;
      _error = null;
    });
    try {
      final photo = await PhotoCapture.capture(source: ImageSource.camera);
      if (photo == null) return;

      final userId = supabase.auth.currentUser!.id;
      final bytes = await photo.readAsBytes();
      final path = '$userId/${widget.storeVisitId}_${placementType}_'
          '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('osa-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      await supabase.from('product_placements').insert({
        'store_visit_id': widget.storeVisitId,
        'placement_type': placementType,
        'photo_url': path,
      });

      setState(() => _saved[placementType] = true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _saving[placementType] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Ketersediaan di Rak'),
          actions: const [HelpButton(HelpTopic.osa)],
        bottom: const HelpBar(HelpTopic.osa),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Foto setiap lokasi rak yang sesuai.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: colorScheme.error)),
              const SizedBox(height: 16),
            ],
            for (final entry in _placementLabels.entries)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  leading: Icon(
                    _saved[entry.key] == true
                        ? Icons.check_circle
                        : Icons.camera_alt_outlined,
                    color: _saved[entry.key] == true
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  title: Text(entry.value),
                  subtitle: _saving[entry.key] == true
                      ? const Text('Mengunggah...')
                      : (_saved[entry.key] == true
                          ? const Text('Tersimpan')
                          : null),
                  trailing: _saving[entry.key] == true
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _saving[entry.key] == true
                      ? null
                      : () => _logPlacement(entry.key),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Column(children: [
                SwitchListTile(
                  title: const Text('Toko minta restock'),
                  subtitle: const Text('Nyalakan jika toko meminta barang ditambah'),
                  value: _restock,
                  onChanged: _finishing ? null : (v) => setState(() => _restock = v),
                ),
                if (_restock)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: TextField(
                      controller: _restockNote,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Barang yang diminta (opsional)',
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _finishing ? null : _finish,
              child: Text(_finishing ? 'Menyimpan...' : 'Selesai'),
            ),
          ],
        ),
      ),
    );
  }
}
