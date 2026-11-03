import 'package:flutter/material.dart';
import '../../core/help.dart';
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
  // Saldo API yang dibeli (USD). Ubah angka ini kalau top up.
  static const _budgetUsd = 5.0;
  double? _spent;
  int _calls = 0;

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
      setState(() =>
          _row = rows.isEmpty ? null : Map<String, dynamic>.from(rows.first));
      await _loadUsage();
    } catch (e) {
      setState(() => _error = 'Gagal memuat: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadUsage() async {
    try {
      final rows =
          await supabase.from('ai_usage').select('cost_usd').limit(10000);
      var sum = 0.0;
      for (final r in rows) {
        sum += double.tryParse('${r['cost_usd']}') ?? 0;
      }
      if (mounted)
        setState(() {
          _spent = sum;
          _calls = rows.length;
        });
    } catch (_) {
      // Tabel belum ada atau tidak ada akses: kartu kredit disembunyikan.
    }
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await supabase.functions
          .invoke('sales-insights', body: {'days': _days});
      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);
      setState(() => _row = Map<String, dynamic>.from(data['insight'] as Map));
      await _loadUsage();
    } on FunctionException catch (e) {
      setState(() =>
          _error = 'Gagal membuat: ${e.details ?? e.reasonPhrase ?? e.status}');
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
        [...((ins?[k] as List?) ?? const [])]
            .map((e) => e is Map ? e.cast<String, dynamic>() : {'text': '$e'})
            .toList();

    return Scaffold(
      appBar: AppBar(
          title: const Text('Wawasan AI'),
          actions: const [HelpButton(HelpTopic.insights)],
        bottom: const HelpBar(HelpTopic.insights),
      ),
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
                if (_spent != null) ...[
                  const SizedBox(height: 12),
                  _CreditCard(
                      budget: _budgetUsd, spent: _spent!, calls: _calls),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_busy ? 'Menganalisis...' : 'Buat wawasan'),
                  onPressed: _busy ? null : _generate,
                ),
                if (_busy)
                  const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator()),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: cs.error))),
                if (ins == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Text(
                        'Belum ada wawasan. Buat setelah sales mengisi penjualan, cek rak, dan harga.'),
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
                      _Item(
                          title: '${f['title'] ?? ''}',
                          body: '${f['detail'] ?? ''}',
                          foot: '${f['evidence'] ?? ''}'),
                  ]),
                  _Section('Risiko stok habis', [
                    for (final r in list('restock_risks'))
                      _Item(
                        title: '${r['product'] ?? ''}',
                        body: '${r['why'] ?? ''}',
                        foot: ((r['stores'] as List?) ?? const []).join(', '),
                      ),
                  ]),
                  _Section('Catatan harga', [
                    for (final p in list('price_notes'))
                      _Item(title: '${p['text'] ?? p}')
                  ]),
                  _Section('Tindakan', [
                    for (final a in list('actions'))
                      _Item(
                          title: '${a['action'] ?? ''}',
                          body: '${a['why'] ?? ''}',
                          foot: 'Untuk: ${a['who'] ?? ''}'),
                  ]),
                  _Section('Data yang kurang', [
                    for (final g in list('data_gaps'))
                      _Item(title: '${g['text'] ?? g}')
                  ]),
                  const SizedBox(height: 16),
                  Text(
                      'Ringkasan AI dari angka yang diisi di aplikasi. Periksa angka penting sebelum bertindak.',
                      style: t.bodySmall),
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
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...items
        ],
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
            if (foot != null && foot!.isNotEmpty)
              Text(foot!, style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Perkiraan sisa saldo API: saldo dibeli dikurangi biaya yang dicatat tiap
/// panggilan AI. Biaya dihitung dari jumlah token di respons API dan harga
/// per model, jadi ini perkiraan. Saldo resmi ada di console Anthropic.
class _CreditCard extends StatelessWidget {
  const _CreditCard(
      {required this.budget, required this.spent, required this.calls});
  final double budget;
  final double spent;
  final int calls;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final left = (budget - spent).clamp(0, budget).toDouble();
    final frac = (spent / budget).clamp(0, 1).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Perkiraan sisa kredit AI', style: t.titleSmall),
          const SizedBox(height: 4),
          Text(
              '\$${left.toStringAsFixed(2)} dari \$${budget.toStringAsFixed(2)}',
              style: t.headlineSmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: frac),
          const SizedBox(height: 8),
          Text(
            'Terpakai sekitar \$${spent.toStringAsFixed(2)} dari $calls panggilan AI. '
            'Ini perkiraan dari jumlah token dan harga model. Saldo asli ada di console Anthropic.',
            style: t.bodySmall,
          ),
        ]),
      ),
    );
  }
}
