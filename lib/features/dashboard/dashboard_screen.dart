import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../shelf_check/shelf_actions.dart';
import '../shelf_check/shelf_check_screen.dart';

/// Dasbor manajer (Option A): lima angka hari ini, kunjungan terbaru,
/// daftar "perlu perhatian", dan cek rak terbaru. Semua dari data asli.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onOpen});

  /// Dipakai tombol di daftar perhatian untuk pindah halaman (nama halaman).
  final void Function(String page)? onOpen;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _Attn {
  _Attn(this.title, this.sub, {this.warn = false});
  final String title;
  final String sub;
  final bool warn;
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  int _present = 0, _visits = 0, _outside = 0, _gaps = 0, _pending = 0;
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _shelf = [];
  final List<_Attn> _attn = [];

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
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final res = await Future.wait<dynamic>([
        supabase.from('attendance_records').select('id').gte('clock_in_at', start),
        supabase
            .from('store_visits')
            .select(
                'id, visit_started_at, is_within_geofence, distance_from_store_meters, profiles(full_name), stores(name, geofence_radius_meters)')
            .order('visit_started_at', ascending: false)
            .limit(40),
        supabase
            .from('shelf_checks')
            .select('id, employee_id, summary, analysis, photo_path, created_at, stores(name), '
                'profiles(full_name), shelf_check_actions(actions, note)')
            .order('created_at', ascending: false)
            .limit(20),
        supabase
            .from('leave_requests')
            .select('id, start_date, created_at')
            .eq('status', 'pending')
            .order('created_at'),
      ]);
      final att = List<Map<String, dynamic>>.from(res[0] as List);
      final visits = List<Map<String, dynamic>>.from(res[1] as List);
      final shelf = List<Map<String, dynamic>>.from(res[2] as List);
      final leave = List<Map<String, dynamic>>.from(res[3] as List);

      bool today(dynamic iso) {
        final d = DateTime.tryParse('$iso')?.toLocal();
        return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
      }

      final vToday = visits.where((v) => today(v['visit_started_at'])).toList();
      final outToday = vToday.where((v) => v['is_within_geofence'] == false).toList();
      final sToday = shelf.where((s) => today(s['created_at'])).toList();
      var gaps = 0;
      for (final s in sToday) {
        final a = (s['analysis'] as Map?) ?? const {};
        final g = a['gaps'];
        if (g is List) gaps += g.length;
      }

      final attn = <_Attn>[];
      for (final s in shelf.take(8)) {
        final a = (s['analysis'] as Map?) ?? const {};
        final acts = a['key_actions'];
        if (acts is List && acts.isNotEmpty && attn.where((x) => !x.warn).length < 2) {
          final first = (acts.first as Map?) ?? const {};
          final txt = '${first['action'] ?? ''}';
          if (txt.isNotEmpty) {
            attn.add(_Attn(txt, '${(s['stores'] as Map?)?['name'] ?? ''}, dari cek rak'));
          }
        }
      }
      if (leave.isNotEmpty) {
        final oldest = DateTime.tryParse('${leave.first['created_at']}')?.toLocal();
        attn.add(_Attn('${leave.length} pengajuan cuti menunggu persetujuan',
            oldest == null ? '' : 'Yang terlama sejak ${DateFormat('d MMM', 'id').format(oldest)}',
            warn: true));
      }
      for (final v in outToday.take(3)) {
        final who = (v['profiles'] as Map?)?['full_name'] ?? 'Karyawan';
        final store = (v['stores'] as Map?)?['name'] ?? 'toko';
        final d = (v['distance_from_store_meters'] as num?)?.round();
        attn.add(_Attn('$who check-in di luar zona', d == null ? 'di $store' : '$d m dari $store',
            warn: true));
      }

      setState(() {
        _present = att.length;
        _visits = vToday.length;
        _outside = outToday.length;
        _gaps = gaps;
        _pending = leave.length;
        _recent = visits.take(8).toList();
        _shelf = shelf.take(3).toList();
        _attn
          ..clear()
          ..addAll(attn);
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat dasbor: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('EEEE, d MMM', 'id').format(DateTime.now());

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                children: [
                  Text('Dasbor', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$date, semua toko.', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: cs.error)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _load, child: const Text('Muat ulang')),
                  ] else ...[
                    LayoutBuilder(builder: (context, c) {
                      final cols = c.maxWidth >= 720 ? 5 : (c.maxWidth >= 420 ? 3 : 2);
                      final w = (c.maxWidth - 8 * (cols - 1)) / cols;
                      Widget tile(String label, int n) => SizedBox(
                            width: w,
                            child: _Tile(label: label, value: '$n'),
                          );
                      return Wrap(spacing: 8, runSpacing: 8, children: [
                        tile('Absen masuk', _present),
                        tile('Kunjungan', _visits),
                        tile('Luar zona', _outside),
                        tile('Celah rak', _gaps),
                        tile('Cuti menunggu', _pending),
                      ]);
                    }),
                    const SizedBox(height: 24),
                    LayoutBuilder(builder: (context, c) {
                      final wide = c.maxWidth >= 760;
                      final visits = _Section(
                        title: 'Kunjungan toko terbaru',
                        child: _recent.isEmpty
                            ? const _Empty('Belum ada kunjungan.')
                            : _VisitTable(rows: _recent),
                      );
                      final attn = _Section(
                        title: 'Perlu perhatian',
                        child: _attn.isEmpty
                            ? const _Empty('Tidak ada yang perlu perhatian sekarang.')
                            : Column(children: [
                                for (final a in _attn) _AttnCard(a),
                              ]),
                      );
                      return wide
                          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(flex: 3, child: visits),
                              const SizedBox(width: 28),
                              Expanded(flex: 2, child: attn),
                            ])
                          : Column(children: [attn, const SizedBox(height: 20), visits]);
                    }),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Cek rak terbaru',
                      child: _shelf.isEmpty
                          ? const _Empty('Belum ada cek rak.')
                          : LayoutBuilder(builder: (context, c) {
                              final cols = c.maxWidth >= 720 ? 3 : 1;
                              final w = (c.maxWidth - 8 * (cols - 1)) / cols;
                              return Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final s in _shelf)
                                  SizedBox(
                                    width: w,
                                    child: _ShelfCard(s),
                                  ),
                              ]);
                            }),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        Text(value,
            style: t.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _AttnCard extends StatelessWidget {
  const _AttnCard(this.a);
  final _Attn a;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: a.warn ? const Color(0xFFD9822B) : cs.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (a.sub.isNotEmpty)
                Text(a.sub, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard(this.s);
  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final when = DateTime.tryParse('${s['created_at']}')?.toLocal();
    final store = (s['stores'] as Map?)?['name'] ?? 'Toko';
    final act = firstRelation(s['shelf_check_actions']);
    final codes = shelfActionCodes(act?['actions']);
    final note = '${act?['note'] ?? ''}'.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ShelfResultScreen(check: s))),
      child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$store${when == null ? '' : ', ${DateFormat('d MMM HH:mm', 'id').format(when)}'}',
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('${s['summary'] ?? 'Tanpa ringkasan'}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        if (codes.isEmpty && note.isEmpty)
          Text('Belum ada catatan tindakan sales',
              style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: cs.onSurfaceVariant))
        else ...[
          Text('Tindakan sales: ${codes.map((c) => kShelfActionLabels[c] ?? c).join(', ')}',
              maxLines: 3, overflow: TextOverflow.ellipsis, style: t.bodySmall),
          if (note.isNotEmpty)
            Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
        ],
      ]),
    ));
  }
}

class _VisitTable extends StatelessWidget {
  const _VisitTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final head = t.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600);
    Widget cell(Widget w, int flex) => Expanded(flex: flex, child: w);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          cell(Text('Karyawan', style: head), 3),
          cell(Text('Toko', style: head), 3),
          cell(Text('Waktu', style: head), 2),
          cell(Text('Zona', style: head), 3),
        ]),
      ),
      for (var i = 0; i < rows.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: i.isEven ? cs.surfaceContainerHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            cell(Text('${(rows[i]['profiles'] as Map?)?['full_name'] ?? '-'}', style: t.bodyMedium), 3),
            cell(Text('${(rows[i]['stores'] as Map?)?['name'] ?? '-'}', style: t.bodyMedium), 3),
            cell(
                Text(
                    () {
                      final d = DateTime.tryParse('${rows[i]['visit_started_at']}')?.toLocal();
                      return d == null ? '-' : DateFormat('HH:mm').format(d);
                    }(),
                    style: t.bodyMedium),
                2),
            cell(Align(alignment: Alignment.centerLeft, child: _ZoneTag(rows[i]['is_within_geofence'] as bool?)), 3),
          ]),
        ),
    ]);
  }
}

class _ZoneTag extends StatelessWidget {
  const _ZoneTag(this.inside);
  final bool? inside;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warn = inside == false;
    final bg = warn ? const Color(0xFFFBE8CC) : cs.primaryContainer;
    final fg = warn ? const Color(0xFF9A4A05) : cs.primary;
    final text = inside == null ? 'Belum dicek' : (warn ? 'Luar zona' : 'Dalam zona');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
