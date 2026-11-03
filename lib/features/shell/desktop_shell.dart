import 'package:flutter/material.dart';

import '../../core/help.dart';
import '../../core/supabase_client.dart';
import '../admin/store_assignment_screen.dart';
import '../admin/store_management_screen.dart';
import '../admin/user_management_screen.dart';
import '../attendance/clock_in_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../insights/insights_screen.dart';
import '../leave/leave_review_screen.dart';
import '../leave/leave_screen.dart';
import '../pricing/pricing_screen.dart';
import '../reports/attendance_report_screen.dart';
import '../reports/sales_price_screen.dart';
import '../reports/store_visit_report_screen.dart';
import '../sales/sales_entry_screen.dart';
import '../shelf_check/shelf_check_screen.dart';
import '../store_visit/store_visit_screen.dart';
import '../summary/summary_screen.dart';

class _Item {
  const _Item(this.label, this.build);
  final String label;
  final Widget Function() build;
}

class _Group {
  const _Group(this.title, this.items);
  final String title;
  final List<_Item> items;
}

/// Tata letak layar lebar (Option A "Lembar Kerja"): sidebar di atas kanvas
/// hijau muda dan lembar putih berisi halaman. Dipakai di layar >= 900 px.
/// Layar sempit tetap memakai menu ponsel.
class DesktopShell extends StatefulWidget {
  const DesktopShell({
    super.key,
    required this.isManager,
    required this.isAdminAccount,
    required this.name,
    required this.roleLabel,
  });

  final bool isManager;
  final bool isAdminAccount;
  final String name;
  final String roleLabel;

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  late final List<_Group> _groups = _buildGroups();
  late _Item _current = _groups.first.items.first;

  List<_Group> _buildGroups() {
    if (!widget.isManager) {
      return [
        _Group('Pekerjaanmu', [
          _Item('Absensi', () => const ClockInScreen()),
          _Item('Kunjungan toko', () => const StoreVisitScreen()),
          _Item('Cek rak', () => const ShelfCheckScreen()),
          _Item('Input penjualan', () => const SalesEntryScreen()),
          _Item('Harga', () => const PricingScreen()),
          _Item('Cuti', () => const LeaveScreen()),
        ]),
        _Group('Ringkasan', [
          _Item('Laporan kehadiran', () => const AttendanceReportScreen(mine: true)),
          _Item('Ringkasan aktivitas', () => const SummaryScreen()),
        ]),
      ];
    }
    return [
      _Group('Ringkasan', [
        _Item('Dasbor', () => const DashboardScreen()),
        _Item('Absensi', () => const AttendanceReportScreen()),
        _Item('Kunjungan toko', () => const StoreVisitReportScreen()),
      ]),
      _Group('Data lapangan', [
        _Item('Cek rak', () => const ShelfCheckScreen()),
        _Item('Penjualan dan harga', () => const SalesPriceScreen()),
        _Item('Wawasan AI', () => const InsightsScreen()),
      ]),
      _Group('Orang dan toko', [
        _Item('Persetujuan cuti', () => const LeaveReviewScreen()),
        _Item('Penugasan toko', () => const StoreAssignmentScreen()),
        _Item('Toko', () => const StoreManagementScreen()),
        if (widget.isAdminAccount) _Item('Karyawan', () => const UserManagementScreen()),
      ]),
      _Group('Pekerjaanmu', [
        _Item('Absensi saya', () => const ClockInScreen()),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvas = dark ? const Color(0xFF0A100E) : cs.surfaceContainerHighest;

    return Scaffold(
      backgroundColor: canvas,
      body: Row(children: [
        SizedBox(
          width: 224,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 24, 8, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Text('Zonein',
                    style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
              ),
              Expanded(
                child: ListView(children: [
                  for (final g in _groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Text(g.title,
                          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    ),
                    for (final it in g.items) _NavTile(
                      label: it.label,
                      selected: identical(it, _current),
                      onTap: () => setState(() => _current = it),
                    ),
                  ],
                ]),
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.name, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(widget.roleLabel, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              _NavTile(label: 'Panduan', selected: false, onTap: () => showHelpSheet(context, HelpTopic.guide)),
              _NavTile(label: 'Keluar', selected: false, onTap: () => supabase.auth.signOut()),
            ]),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: cs.surface,
                // Navigator sendiri per halaman: layar yang dibuka dari dalam
                // (mis. impor CSV) tetap tampil di dalam lembar putih.
                child: Navigator(
                  key: ValueKey(_current.label),
                  onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _current.build()),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? cs.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
