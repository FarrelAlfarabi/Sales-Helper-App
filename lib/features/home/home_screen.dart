import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../admin/store_assignment_screen.dart';
import '../admin/store_management_screen.dart';
import '../admin/user_management_screen.dart';
import '../attendance/clock_in_screen.dart';
import '../leave/leave_review_screen.dart';
import '../leave/leave_screen.dart';
import '../insights/insights_screen.dart';
import '../pricing/pricing_screen.dart';
import '../reports/attendance_report_screen.dart';
import '../sales/sales_entry_screen.dart';
import '../shelf_check/shelf_check_screen.dart';
import '../reports/store_visit_report_screen.dart';
import '../store_visit/store_visit_screen.dart';
import '../summary/summary_screen.dart';

// Gates the "Tambah Karyawan" tile specifically to this one account, per an
// explicit request that it be reachable only from this login -- not any
// account that happens to have role='admin'. This is a UI convenience
// only: the admin-create-user Edge Function independently re-checks this
// exact email (plus role='admin') server-side, so hiding/showing this
// tile is never itself the real access control.
const _kAdminEmail = 'farrel.abi.saleh@gmail.com';

/// Home menu. Redesigned from a grid-of-icons into grouped rows (a more
/// typical "settings/menu list" pattern) -- reads better once there are
/// 10+ destinations, and a flat list of ListTiles is also a lighter
/// widget tree than a grid of icon+label cells, which matters for the
/// "low device load" goal on top of just looking better.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isManagerOrAdmin = false;
  bool _loadingRole = true;
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final row = await supabase.from('profiles').select('role, full_name').eq('id', userId).single();
      setState(() {
        _isManagerOrAdmin = row['role'] == 'manager' || row['role'] == 'admin';
        _fullName = row['full_name'] as String?;
      });
    } catch (_) {
      // Role check failing just hides manager tiles -- RLS is still the
      // real access control on every underlying table/screen regardless.
    } finally {
      setState(() => _loadingRole = false);
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final email = supabase.auth.currentUser?.email ?? '';
    final isAdminAccount = email.toLowerCase() == _kAdminEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonein'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: _loadingRole
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Halo,', style: Theme.of(context).textTheme.bodySmall),
                            Text(
                              (_fullName != null && _fullName!.isNotEmpty) ? _fullName! : email,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _SectionHeader('Pekerjaanmu'),
                _MenuRow(
                  icon: Icons.calendar_today,
                  label: 'Absensi',
                  onTap: () => _push(context, const ClockInScreen()),
                ),
                _MenuRow(
                  icon: Icons.storefront,
                  label: 'Kunjungan Toko',
                  subtitle: 'termasuk Ketersediaan di Rak',
                  onTap: () => _push(context, const StoreVisitScreen()),
                ),
                _MenuRow(
                  icon: Icons.photo_camera_back_outlined,
                  label: 'Cek Rak',
                  subtitle: 'foto lorong rak, dapat peringatan restok',
                  onTap: () => _push(context, const ShelfCheckScreen()),
                ),
                _MenuRow(
                  icon: Icons.point_of_sale,
                  label: 'Input Penjualan',
                  onTap: () => _push(context, const SalesEntryScreen()),
                ),
                _MenuRow(
                  icon: Icons.beach_access,
                  label: 'Cuti',
                  onTap: () => _push(context, const LeaveScreen()),
                ),
                _MenuRow(
                  icon: Icons.sell,
                  label: 'Harga',
                  onTap: () => _push(context, const PricingScreen()),
                ),
                _MenuRow(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Laporan Kehadiran',
                  subtitle: 'riwayat absensimu',
                  onTap: () => _push(context, const AttendanceReportScreen(mine: true)),
                ),
                _MenuRow(
                  icon: Icons.summarize,
                  label: 'Ringkasan Aktivitas',
                  onTap: () => _push(context, const SummaryScreen()),
                ),
                if (_isManagerOrAdmin) ...[
                  _SectionHeader('Alat Manajer'),
                  _MenuRow(
                    icon: Icons.auto_awesome,
                    label: 'Wawasan AI',
                    subtitle: 'ringkasan penjualan, stok, dan harga',
                    onTap: () => _push(context, const InsightsScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.store,
                    label: 'Kelola Toko',
                    onTap: () => _push(context, const StoreManagementScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.assignment_ind,
                    label: 'Penugasan Toko',
                    onTap: () => _push(context, const StoreAssignmentScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.fact_check,
                    label: 'Tinjau Pengajuan Cuti',
                    onTap: () => _push(context, const LeaveReviewScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.assessment,
                    label: 'Laporan Absensi',
                    onTap: () => _push(context, const AttendanceReportScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.map,
                    label: 'Laporan Kunjungan Toko',
                    onTap: () => _push(context, const StoreVisitReportScreen()),
                  ),
                ],
                if (isAdminAccount) ...[
                  _SectionHeader('Admin'),
                  _MenuRow(
                    icon: Icons.person_add,
                    label: 'Tambah Karyawan',
                    onTap: () => _push(context, const UserManagementScreen()),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = !enabled || onTap == null;

    return ListTile(
      leading: Icon(icon, color: isDisabled ? colorScheme.outline : colorScheme.primary),
      title: Text(label, style: isDisabled ? TextStyle(color: colorScheme.outline) : null),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: isDisabled ? null : const Icon(Icons.chevron_right),
      onTap: isDisabled ? null : onTap,
    );
  }
}
