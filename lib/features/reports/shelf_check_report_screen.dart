import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/signed_photo.dart';
import '../../core/supabase_client.dart';
import '../shelf_check/shelf_actions.dart';
import '../shelf_check/shelf_check_screen.dart';

/// Manajer/admin: riwayat Cek Rak semua sales, lengkap dengan foto dan
/// tindakan yang dicatat sales. Ketuk satu baris untuk hasil AI lengkap.
/// Hanya 100 terbaru, tanpa filter.
class ShelfCheckReportScreen extends StatefulWidget {
  const ShelfCheckReportScreen({super.key});

  @override
  State<ShelfCheckReportScreen> createState() => _ShelfCheckReportScreenState();
}

class _ShelfCheckReportScreenState extends State<ShelfCheckReportScreen> with SafeSetState<ShelfCheckReportScreen> {
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
      final rows = await supabase
          .from('shelf_checks')
          .select('id, employee_id, summary, analysis, photo_path, created_at, '
              'profiles(full_name), stores(name, code), '
              'shelf_check_actions(actions, note)')
          .order('created_at', ascending: false)
          .limit(100);
      setState(() => _rows = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Gagal memuat riwayat cek rak: ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Cek Rak')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(_error!, style: TextStyle(color: cs.error))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_rows.isEmpty)
                        const Text('Belum ada cek rak.'),
                      for (final r in _rows) _row(context, r, t),
                    ],
                  ),
                ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> r, TextTheme t) {
    final act = firstRelation(r['shelf_check_actions']);
    final codes = shelfActionCodes(act?['actions']);
    final note = (act?['note'] ?? '').toString().trim();
    final who = (r['profiles'] as Map?)?['full_name'] ?? 'Sales';
    final store = (r['stores'] as Map?)?['name'] ?? 'Toko';
    final when = DateFormat('dd MMM HH:mm')
        .format(DateTime.parse(r['created_at']).toLocal());
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ShelfResultScreen(check: r))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 96,
              child: SignedPhoto(
                  bucket: 'osa-photos',
                  path: r['photo_path'] as String?,
                  height: 96),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$store', style: t.titleSmall),
                    Text('$who  ·  $when', style: t.bodySmall),
                    const SizedBox(height: 6),
                    if (codes.isEmpty && note.isEmpty)
                      Text('Belum ada catatan tindakan',
                          style: t.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic))
                    else ...[
                      for (final c in codes)
                        Text('• ${kShelfActionLabels[c] ?? c}',
                            style: t.bodySmall),
                      if (note.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(note,
                                maxLines: 3, overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
