import 'package:flutter/material.dart';

import '../../core/help.dart';
import '../../core/supabase_client.dart';
import '../admin/store_assignment_screen.dart';
import '../admin/store_management_screen.dart';
import '../admin/user_management_screen.dart';
import '../attendance/clock_in_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../execution/campaign_management_screen.dart';
import '../execution/execution_form_screen.dart';
import '../execution/execution_gallery_screen.dart';
import '../leave/leave_review_screen.dart';
import '../leave/leave_screen.dart';
import '../pricing/pricing_screen.dart';
import '../reports/attendance_report_screen.dart';
import '../reports/sales_price_screen.dart';
import '../reports/shelf_check_report_screen.dart';
import '../reports/store_visit_report_screen.dart';
import '../sales/sales_entry_screen.dart';
import '../shelf_check/shelf_check_screen.dart';
import '../store_visit/store_visit_screen.dart';
import '../summary/summary_screen.dart';

class _Item {
  const _Item(this.label, this.icon, this.build);
  final String label;
  final IconData icon;
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
          _Item('Absensi', Icons.fingerprint, () => const ClockInScreen()),
          _Item('Kunjungan toko', Icons.storefront_outlined, () => const StoreVisitScreen()),
          _Item('Cek rak', Icons.photo_camera_outlined, () => const ShelfCheckScreen()),
          _Item('Laporan eksekusi', Icons.campaign_outlined, () => const ExecutionFormScreen()),
          _Item('Input penjualan', Icons.point_of_sale, () => const SalesEntryScreen()),
          _Item('Harga', Icons.sell_outlined, () => const PricingScreen()),
          _Item('Cuti', Icons.beach_access_outlined, () => const LeaveScreen()),
        ]),
        _Group('Ringkasan', [
          _Item('Laporan kehadiran', Icons.badge_outlined, () => const AttendanceReportScreen(mine: true)),
          _Item('Ringkasan aktivitas', Icons.insights_outlined, () => const SummaryScreen()),
        ]),
      ];
    }
    return [
      _Group('Ringkasan', [
        _Item('Dasbor', Icons.space_dashboard_outlined, () => const DashboardScreen()),
        _Item('Absensi', Icons.event_available_outlined, () => const AttendanceReportScreen()),
        _Item('Kunjungan toko', Icons.pin_drop_outlined, () => const StoreVisitReportScreen()),
      ]),
      _Group('Data lapangan', [
        _Item('Galeri foto', Icons.photo_library_outlined, () => const ExecutionGalleryScreen()),
        _Item('Cek rak', Icons.photo_camera_outlined, () => const ShelfCheckReportScreen()),
        _Item('Penjualan dan harga', Icons.bar_chart_outlined, () => const SalesPriceScreen()),
      ]),
      _Group('Orang dan toko', [
        _Item('Persetujuan cuti', Icons.fact_check_outlined, () => const LeaveReviewScreen()),
        _Item('Penugasan toko', Icons.assignment_ind_outlined, () => const StoreAssignmentScreen()),
        _Item('Toko', Icons.store_mall_directory_outlined, () => const StoreManagementScreen()),
        _Item('Kampanye', Icons.campaign_outlined, () => const CampaignManagementScreen()),
        if (widget.isAdminAccount) _Item('Karyawan', Icons.group_outlined, () => const UserManagementScreen()),
      ]),
      _Group('Pekerjaanmu', [
        _Item('Absensi saya', Icons.fingerprint, () => const ClockInScreen()),
        _Item('Laporan eksekusi', Icons.campaign_outlined, () => const ExecutionFormScreen()),
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
                      padding: const EdgeInsets.fromLTRB(12, 22, 12, 6),
                      child: Row(children: [
                        Text(g.title.toUpperCase(),
                            style: t.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9)),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6))),
                      ]),
                    ),
                    for (final it in g.items) _NavTile(
                      label: it.label,
                      icon: it.icon,
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
              _NavTile(label: 'Panduan', icon: Icons.help_outline, selected: false, onTap: () => showHelpSheet(context, HelpTopic.guide)),
              _NavTile(label: 'Keluar', icon: Icons.logout, selected: false, onTap: () => supabase.auth.signOut()),
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
  const _NavTile({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = cs.primary.withValues(alpha: dark ? 0.22 : 0.14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? fill : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: cs.primary.withValues(alpha: dark ? 0.12 : 0.08),
          child: Stack(children: [
            Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
              alignment: Alignment.centerLeft,
              child: Row(children: [
                Icon(icon, size: 20, color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.85)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ),
              ]),
            ),
            if (selected)
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
