import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';

/// Manajer/admin: ringkasan harian per salesman. Berapa toko dikunjungi dan
/// berapa toko minta restock pada tanggal yang dipilih. Ketuk baris untuk
/// melihat daftar tokonya.
class DailyVisitSummaryScreen extends StatefulWidget {
  const DailyVisitSummaryScreen({super.key});

  @override
  State<DailyVisitSummaryScreen> createState() => _DailyVisitSummaryScreenState();
}

class _RepRow {
  _RepRow(this.id, this.name);
  final String id;
  final String name;
  final List<Map<String, dynamic>> visits = [];

  int get storesVisited => visits.map((v) => v['store_id']).toSet().length;
  int get storesRestock =>
      visits.where((v) => v['restock_requested'] == true).map((v) => v['store_id']).toSet().length;
  int get outside => visits.where((v) => v['is_within_geofence'] == false).length;
}

class _DailyVisitSummaryScreenState extends State<DailyVisitSummaryScreen> {
  DateTime _day = DateTime.now();
  bool _loading = true;
  String? _error;
  List<_RepRow> _rows = [];

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
      final start = DateTime(_day.year, _day.month, _day.day);
      final end = start.add(const Duration(days: 1));
      final res = await Future.wait<dynamic>([
        supabase
            .from('profiles')
            .select('id, full_name')
            .eq('role', 'field_rep')
            .eq('is_active', true)
            .order('full_name'),
        supabase
            .from('store_visits')
            .select('id, employee_id, store_id, visit_started_at, is_within_geofence, '
                'restock_requested, restock_note, stores(name, code)')
            .gte('visit_started_at', start.toUtc().toIso8601String())
            .lt('visit_started_at', end.toUtc().toIso8601String())
            .order('visit_started_at')
            .limit(2000),
      ]);
      final byId = <String, _RepRow>{
        for (final p in List<Map<String, dynamic>>.from(res[0] as List))
          p['id'] as String: _RepRow(p['id'] as String, p['full_name'] as String? ?? '?'),
      };
      for (final v in List<Map<String, dynamic>>.from(res[1] as List)) {
        final id = v['employee_id'] as String;
        // Akun non-salesman (mis. manajer) yang ikut berkunjung tetap ditampilkan.
        byId.putIfAbsent(id, () => _RepRow(id, 'Pengguna lain'));
        byId[id]!.visits.add(v);
      }
      final rows = byId.values.toList()
        ..sort((a, b) {
          final c = b.storesVisited.compareTo(a.storesVisited);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = 'Gagal memuat ringkasan kunjungan: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (d != null) {
      setState(() => _day = d);
      _load();
    }
  }

  void _shift(int days) {
    final next = _day.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _day = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final label = DateFormat('EEEE, d MMMM y', 'id').format(_day);
    final totalVisited = _rows.fold<int>(0, (a, r) => a + r.storesVisited);
    final totalRestock = _rows.fold<int>(0, (a, r) => a + r.storesRestock);
    final isToday = DateUtils.isSameDay(_day, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan Kunjungan Harian')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Hari sebelumnya',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(label),
                  onPressed: _pickDay,
                ),
              ),
              IconButton(
                tooltip: 'Hari berikutnya',
                icon: const Icon(Icons.chevron_right),
                onPressed: isToday ? null : () => _shift(1),
              ),
            ]),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: TextStyle(color: cs.error))
            else if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(children: [
                Expanded(child: _Tile('Toko dikunjungi', '$totalVisited')),
                const SizedBox(width: 12),
                Expanded(child: _Tile('Toko minta restock', '$totalRestock', warn: totalRestock > 0)),
              ]),
              const SizedBox(height: 16),
              if (_rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: Text('Belum ada salesman aktif.')),
                )
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(children: [
                        Expanded(flex: 4, child: Text('Salesman', style: t.labelMedium)),
                        Expanded(flex: 2, child: Text('Dikunjungi', style: t.labelMedium, textAlign: TextAlign.end)),
                        Expanded(flex: 2, child: Text('Restock', style: t.labelMedium, textAlign: TextAlign.end)),
                        const SizedBox(width: 24),
                      ]),
                    ),
                    const Divider(height: 1),
                    for (final r in _rows)
                      InkWell(
                        onTap: r.visits.isEmpty
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => _RepVisitsScreen(row: r, day: _day))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Expanded(
                              flex: 4,
                              child: Text(r.name,
                                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(r.visits.isEmpty ? '0 (belum ada)' : '${r.storesVisited} toko',
                                  textAlign: TextAlign.end,
                                  style: t.bodyMedium?.copyWith(
                                      color: r.visits.isEmpty ? cs.onSurfaceVariant : null)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('${r.storesRestock} toko',
                                  textAlign: TextAlign.end,
                                  style: t.bodyMedium?.copyWith(
                                      fontWeight: r.storesRestock > 0 ? FontWeight.w700 : null,
                                      color: r.storesRestock > 0 ? cs.error : cs.onSurfaceVariant)),
                            ),
                            SizedBox(
                              width: 24,
                              child: r.visits.isEmpty
                                  ? null
                                  : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 8),
              Text('Dihitung per toko, jadi dua kunjungan ke toko yang sama dihitung satu.',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, {this.warn = false});
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: t.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: warn ? cs.error : null)),
        ]),
      ),
    );
  }
}

/// Daftar toko yang dikunjungi satu salesman pada satu hari.
class _RepVisitsScreen extends StatelessWidget {
  const _RepVisitsScreen({required this.row, required this.day});
  final _RepRow row;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final hm = DateFormat('HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(row.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(DateFormat('EEEE, d MMMM y', 'id').format(day), style: t.titleMedium),
          const SizedBox(height: 4),
          Text('${row.storesVisited} toko dikunjungi, ${row.storesRestock} minta restock',
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final v in row.visits)
            Card(
              child: ListTile(
                title: Text('${(v['stores'] as Map?)?['name'] ?? '?'} (${(v['stores'] as Map?)?['code'] ?? ''})'),
                subtitle: Text([
                  'Jam ${hm.format(DateTime.parse(v['visit_started_at'] as String).toLocal())}',
                  v['is_within_geofence'] == false ? 'Di luar zona' : 'Dalam zona',
                  if (v['restock_requested'] == true)
                    'Minta restock${(v['restock_note'] as String?)?.isNotEmpty == true ? ': ${v['restock_note']}' : ''}',
                ].join('\n')),
                isThreeLine: v['restock_requested'] == true,
                trailing: v['restock_requested'] == true
                    ? Chip(
                        label: const Text('Restock'),
                        backgroundColor: cs.errorContainer,
                        labelStyle: TextStyle(color: cs.onErrorContainer),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
