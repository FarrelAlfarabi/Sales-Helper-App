import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../core/help.dart';
import '../../core/location.dart';
import '../../core/supabase_client.dart';
import '../../core/theme_controller.dart';
import '../account/change_password_dialog.dart';
import '../attendance/clock_in_screen.dart';
import '../leave/leave_screen.dart';
import '../pricing/pricing_screen.dart';
import '../reports/attendance_report_screen.dart';
import '../sales/sales_entry_screen.dart';
import '../store_visit/store_visit_screen.dart';
import '../summary/summary_screen.dart';

/// Beranda sales: "apa yang harus saya lakukan sekarang". Menampilkan status
/// absen hari ini, satu tombol langkah berikutnya, dan daftar toko tugas
/// (terdekat dulu) dengan tanda sudah atau belum dikunjungi hari ini.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.name, this.embedded = false});

  final String name;

  /// true jika tampil di dalam lembar desktop (tanpa tombol akun di AppBar).
  final bool embedded;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

enum _Phase { notIn, working, allDone, out }

class _TodayScreenState extends State<TodayScreen>
    with SafeSetState<TodayScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _open; // absen masuk yang belum ditutup
  bool _clockedOutToday = false;
  List<Map<String, dynamic>> _stores = [];
  final Map<String, int> _visitsToday = {}; // store_id -> jumlah
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _stores.isEmpty && _open == null;
      _error = null;
    });
    try {
      final uid = supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final res = await Future.wait<dynamic>([
        supabase
            .from('attendance_records')
            .select('id, clock_in_at, clock_out_at')
            .eq('employee_id', uid)
            .or('clock_out_at.is.null,clock_in_at.gte."$start"')
            .order('clock_in_at', ascending: false)
            .limit(5),
        supabase
            .from('store_assignments')
            .select('stores(id, name, code, address, latitude, longitude, geofence_radius_meters, is_active)')
            .eq('employee_id', uid)
            .eq('is_active', true),
        supabase
            .from('store_visits')
            .select('store_id')
            .eq('employee_id', uid)
            .gte('visit_started_at', start),
      ]);
      final att = List<Map<String, dynamic>>.from(res[0] as List);
      final stores = <Map<String, dynamic>>[
        for (final r in res[1] as List)
          if (r['stores'] != null && (r['stores'] as Map)['is_active'] != false)
            Map<String, dynamic>.from(r['stores'] as Map),
      ];
      final visits = <String, int>{};
      for (final v in res[2] as List) {
        final id = '${v['store_id']}';
        visits[id] = (visits[id] ?? 0) + 1;
      }
      setState(() {
        _open = att.where((a) => a['clock_out_at'] == null).firstOrNull;
        _clockedOutToday = _open == null && att.any((a) => a['clock_out_at'] != null);
        _stores = stores;
        _visitsToday
          ..clear()
          ..addAll(visits);
        _sortStores();
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
    // Lokasi untuk urutan "terdekat": tidak memaksa izin di layar ini.
    final pos = await tryCurrentPosition();
    if (pos != null) {
      setState(() {
        _pos = pos;
        _sortStores();
      });
    }
  }

  void _sortStores() {
    _stores.sort((a, b) {
      final va = _visited(a) ? 1 : 0, vb = _visited(b) ? 1 : 0;
      if (va != vb) return va - vb; // belum dikunjungi dulu
      final da = distanceToStore(_pos, a), db = distanceToStore(_pos, b);
      if (da != null && db != null) return da.compareTo(db);
      return '${a['name']}'.compareTo('${b['name']}');
    });
  }

  bool _visited(Map<String, dynamic> s) => (_visitsToday['${s['id']}'] ?? 0) > 0;

  int get _visitedCount => _stores.where(_visited).length;

  _Phase get _phase {
    if (_open == null) return _clockedOutToday ? _Phase.out : _Phase.notIn;
    if (_stores.isNotEmpty && _visitedCount >= _stores.length) return _Phase.allDone;
    return _Phase.working;
  }

  Map<String, dynamic>? get _nextStore =>
      _stores.where((s) => !_visited(s)).firstOrNull;

  Future<void> _go(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  void _visit([String? storeId]) =>
      _go(StoreVisitScreen(initialStoreId: storeId ?? _nextStore?['id'] as String?));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('EEEE, d MMMM', 'id').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hari ini'),
        actions: [
          if (!widget.embedded) const ThemeButton(),
          const HelpButton(HelpTopic.guide),
          if (!widget.embedded) const AccountMenuButton(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      Text('Halo, ${widget.name}',
                          style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(date, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: cs.error)),
                        TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba lagi')),
                        const SizedBox(height: 8),
                      ],
                      _NextStepCard(
                        phase: _phase,
                        openSince: _open?['clock_in_at'],
                        nextStore: _nextStore,
                        distance: _nextStore == null ? null : distanceToStore(_pos, _nextStore!),
                        visited: _visitedCount,
                        total: _stores.length,
                        onClock: () => _go(const ClockInScreen()),
                        onVisit: _visit,
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(
                          child: Text('Toko hari ini',
                              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        if (_stores.isNotEmpty)
                          Text('$_visitedCount dari ${_stores.length} dikunjungi',
                              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ]),
                      if (_stores.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: _visitedCount / _stores.length,
                            minHeight: 6,
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (_stores.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Belum ada toko yang ditugaskan kepadamu. Hubungi manajer.'),
                        ),
                      for (final s in _stores)
                        _StoreRow(
                          store: s,
                          visited: _visited(s),
                          distance: distanceToStore(_pos, s),
                          onTap: () => _visit(s['id'] as String),
                        ),
                      const SizedBox(height: 24),
                      Text('Lainnya', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _QuickGrid(items: [
                        _Quick(Icons.point_of_sale, 'Penjualan', () => _go(const SalesEntryScreen())),
                        _Quick(Icons.sell_outlined, 'Harga', () => _go(const PricingScreen())),
                        _Quick(Icons.beach_access_outlined, 'Cuti', () => _go(const LeaveScreen())),
                        _Quick(Icons.badge_outlined, 'Riwayat absen',
                            () => _go(const AttendanceReportScreen(mine: true))),
                        _Quick(Icons.insights_outlined, 'Ringkasan bulan ini',
                            () => _go(const SummaryScreen())),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.phase,
    required this.openSince,
    required this.nextStore,
    required this.distance,
    required this.visited,
    required this.total,
    required this.onClock,
    required this.onVisit,
  });

  final _Phase phase;
  final dynamic openSince;
  final Map<String, dynamic>? nextStore;
  final double? distance;
  final int visited;
  final int total;
  final VoidCallback onClock;
  final VoidCallback onVisit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final since = openSince == null
        ? null
        : DateFormat('HH.mm', 'id').format(DateTime.parse('$openSince').toLocal());

    late final IconData icon;
    late final String title;
    late final String sub;
    String? action;
    VoidCallback? onAction;

    switch (phase) {
      case _Phase.notIn:
        icon = Icons.wb_sunny_outlined;
        title = 'Belum absen masuk';
        sub = 'Mulai hari dengan absen masuk. Butuh selfie dan lokasi.';
        action = 'Absen masuk';
        onAction = onClock;
      case _Phase.working:
        icon = Icons.storefront_outlined;
        title = nextStore == null ? 'Sudah absen masuk' : 'Berikutnya: ${nextStore!['name']}';
        sub = [
          if (since != null) 'Masuk pukul $since',
          if (distance != null) '${fmtDistance(distance!)} dari sini',
          if (total > 0) '$visited dari $total toko selesai',
        ].join(' · ');
        if (nextStore != null) {
          action = 'Mulai kunjungan';
          onAction = onVisit;
        }
      case _Phase.allDone:
        icon = Icons.task_alt;
        title = 'Semua toko sudah dikunjungi';
        sub = 'Kerja bagus. Absen pulang jika pekerjaan hari ini selesai.';
        action = 'Absen pulang';
        onAction = onClock;
      case _Phase.out:
        icon = Icons.nightlight_outlined;
        title = 'Sudah absen pulang';
        sub = 'Sampai jumpa besok. $visited toko dikunjungi hari ini.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: cs.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(sub, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
        if (action != null) ...[
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: onAction,
            child: Text(action),
          ),
        ],
        if (phase == _Phase.working) ...[
          const SizedBox(height: 4),
          TextButton(onPressed: onClock, child: const Text('Absen pulang')),
        ],
      ]),
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({
    required this.store,
    required this.visited,
    required this.distance,
    required this.onTap,
  });

  final Map<String, dynamic> store;
  final bool visited;
  final double? distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final sub = [
      if (distance != null) fmtDistance(distance!),
      if ('${store['address'] ?? ''}'.trim().isNotEmpty) '${store['address']}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(visited ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: visited ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${store['name']}',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              Text(visited ? 'Selesai' : 'Kunjungi',
                  style: t.labelLarge?.copyWith(
                      color: visited ? cs.onSurfaceVariant : cs.primary,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Quick {
  const _Quick(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.items});
  final List<_Quick> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 5 : 3;
      final w = (c.maxWidth - 8 * (cols - 1)) / cols;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final it in items)
          SizedBox(
            width: w,
            child: Material(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: it.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  child: Column(children: [
                    Icon(it.icon, color: cs.primary),
                    const SizedBox(height: 6),
                    Text(it.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}
