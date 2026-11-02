import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';

/// Manager/admin: AI insights on FMCG sales. Calls the sales-insights Edge
/// Function, which sends only aggregated numbers to Claude and stores the
/// answer. Shows the latest stored insight first so opening the screen is
/// free; generating a new one costs an API call. Needs migration
/// 20261030100000 and the deployed function.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _days = 30;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _row;

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    try {
      final rows = await supabase
          .from('ai_insights')
          .select()
          .order('created_at', ascending: false)
          .limit(1);
      setState(() => _row = rows.isEmpty ? null : Map<String, dynamic>.from(rows.first));
    } catch (e) {
      setState(() => _error = 'Gagal memuat: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await supabase.functions.invoke('sales-insights', body: {'days': _days});
      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);
      setState(() => _row = Map<String, dynamic>.from(data['insight'] as Map));
    } on FunctionException catch (e) {
      setState(() => _error = 'Gagal membuat: ${e.details ?? e.reasonPhrase ?? e.status}');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ins = (_row?['insight'] as Map?)?.cast<String, dynamic>();
    List<Map<String, dynamic>> list(String k) =>
        [...((ins?[k] as List?) ?? const [])].map((e) => e is Map ? e.cast<String, dynamic>() : {'text': '$e'}).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Wawasan AI')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 hari')),
                      ButtonSegment(value: 30, label: Text('30 hari')),
                      ButtonSegment(value: 90, label: Text('90 hari')),
                    ],
                    selected: {_days},
                    onSelectionChanged: (s) => setState(() => _days = s.first),
                  ),
                ]),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_busy ? 'Menganalisis...' : 'Buat wawasan'),
                  onPressed: _busy ? null : _generate,
                ),
                if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                if (_error != null)
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: cs.error))),
                if (ins == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Text('Belum ada wawasan. Buat setelah sales mengisi penjualan, cek rak, dan harga.'),
                  ),
                if (ins != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    '${_row!['period_days']} hari terakhir, dibuat '
                    '${DateFormat('dd MMM HH:mm').format(DateTime.parse(_row!['created_at']).toLocal())}',
                    style: t.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text('${ins['headline'] ?? ''}', style: t.titleLarge),
                  _Section('Temuan', [
                    for (final f in list('findings'))
                      _Item(title: '${f['title'] ?? ''}', body: '${f['detail'] ?? ''}', foot: '${f['evidence'] ?? ''}'),
                  ]),
                  _Section('Risiko stok habis', [
                    for (final r in list('restock_risks'))
                      _Item(
                        title: '${r['product'] ?? ''}',
                        body: '${r['why'] ?? ''}',
                        foot: ((r['stores'] as List?) ?? const []).join(', '),
                      ),
                  ]),
                  _Section('Catatan harga', [for (final p in list('price_notes')) _Item(title: '${p['text'] ?? p}')]),
                  _Section('Tindakan', [
                    for (final a in list('actions'))
                      _Item(title: '${a['action'] ?? ''}', body: '${a['why'] ?? ''}', foot: 'Untuk: ${a['who'] ?? ''}'),
                  ]),
                  _Section('Data yang kurang', [for (final g in list('data_gaps')) _Item(title: '${g['text'] ?? g}')]),
                  const SizedBox(height: 16),
                  Text('Ringkasan AI dari angka yang diisi di aplikasi. Periksa angka penting sebelum bertindak.', style: t.bodySmall),
                ],
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.items);
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 6), ...items],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.title, this.body, this.foot});
  final String title;
  final String? body;
  final String? foot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (body != null && body!.isNotEmpty) Text(body!),
            if (foot != null && foot!.isNotEmpty) Text(foot!, style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}
