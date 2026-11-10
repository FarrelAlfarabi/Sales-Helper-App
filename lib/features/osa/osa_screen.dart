import 'package:flutter/material.dart';
import '../../core/help.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo_capture.dart';
import '../../core/supabase_client.dart';
import '../execution/execution_form_screen.dart';
import '../pricing/pricing_screen.dart';
import '../sales/sales_entry_screen.dart';
import '../shelf_check/shelf_check_screen.dart';

/// On Shelf Availability: log product placement photos for a store visit
/// (main shelf, checkout/COC cashier display, secondary display). Matches
/// the placement_type enum in the product_placements table.
///
/// Not run on a real device -- no Flutter SDK available in this
/// environment. Needs verification on actual hardware before shipping.
class OsaScreen extends StatefulWidget {
  const OsaScreen({
    super.key,
    required this.storeVisitId,
    required this.storeId,
    this.storeName = '',
    this.notice,
  });

  final String storeVisitId;
  final String storeId;
  final String storeName;

  /// Peringatan dari check-in (mis. di luar zona), ditampilkan di atas.
  final String? notice;

  @override
  State<OsaScreen> createState() => _OsaScreenState();
}

class _OsaScreenState extends State<OsaScreen> with SafeSetState<OsaScreen> {
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
        // Lama kunjungan: dicatat saat sales menekan selesai.
        'visit_ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.storeVisitId);
      if (!mounted) return;
      showToast(context, 'Kunjungan tersimpan.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan permintaan restock: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

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
      setState(() => _error = friendlyError(e));
    } finally {
      setState(() => _saving[placementType] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.storeName.isEmpty ? 'Di toko' : widget.storeName),
          actions: const [HelpButton(HelpTopic.osa)],
        bottom: const HelpBar(HelpTopic.osa),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.notice != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE8CC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A4A05)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.notice!,
                        style: const TextStyle(color: Color(0xFF5C2C03))),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            Text('1. Foto rak',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Foto setiap lokasi rak yang ada di toko ini. Boleh dilewati jika tidak ada.',
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
            const SizedBox(height: 20),
            Text('2. Lainnya di toko ini (opsional)',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _MoreChip(
                icon: Icons.auto_awesome_outlined,
                label: 'Cek rak dengan AI',
                onTap: () => _open(ShelfCheckScreen(initialStoreId: widget.storeId)),
              ),
              _MoreChip(
                icon: Icons.campaign_outlined,
                label: 'Foto kampanye',
                onTap: () => _open(ExecutionFormScreen(initialStoreId: widget.storeId)),
              ),
              _MoreChip(
                icon: Icons.point_of_sale,
                label: 'Catat penjualan',
                onTap: () => _open(SalesEntryScreen(initialStoreId: widget.storeId)),
              ),
              _MoreChip(
                icon: Icons.sell_outlined,
                label: 'Catat harga',
                onTap: () => _open(PricingScreen(initialStoreId: widget.storeId)),
              ),
            ]),
            const SizedBox(height: 20),
            Text('3. Selesai',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
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
              child: Text(_finishing ? 'Menyimpan...' : 'Selesai kunjungan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        label: Text(label),
        onPressed: onTap,
      );
}
