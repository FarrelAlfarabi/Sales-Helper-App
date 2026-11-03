import 'package:flutter/material.dart';

import '../../core/help.dart';
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
import '../shell/desktop_shell.dart';
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
      final row = await supabase
          .from('profiles')
          .select('role, full_name')
          .eq('id', userId)
          .single();
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

    // Layar lebar (laptop): sidebar + lembar kerja. Ponsel tetap memakai menu di bawah.
    if (!_loadingRole && MediaQuery.of(context).size.width >= 900) {
      return DesktopShell(
        isManager: _isManagerOrAdmin,
        isAdminAccount: isAdminAccount,
        name: (_fullName != null && _fullName!.isNotEmpty) ? _fullName! : email,
        roleLabel: isAdminAccount ? 'Admin' : (_isManagerOrAdmin ? 'Manajer' : 'Sales'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonein'),
        actions: [
          const HelpButton(HelpTopic.guide),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
        bottom: const HelpBar(HelpTopic.guide),
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Halo,',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                                Text(
                                  (_fullName != null && _fullName!.isNotEmpty)
                                      ? _fullName!
                                      : email,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              isAdminAccount ? 'Admin' : (_isManagerOrAdmin ? 'Manajer' : 'Sales'),
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SectionHeader('Pekerjaanmu'),
                    _MenuRow(
                      icon: Icons.calendar_today,
                      label: 'Absensi',
                      subtitle:
                          'masuk dan pulang kerja, dengan selfie dan lokasi',
                      onTap: () => _push(context, const ClockInScreen()),
                    ),
                    _MenuRow(
                      icon: Icons.storefront,
                      label: 'Kunjungan Toko',
                      subtitle:
                          'check-in toko dengan foto, lalu isi ketersediaan di rak',
                      onTap: () => _push(context, const StoreVisitScreen()),
                    ),
                    _MenuRow(
                      icon: Icons.photo_camera_back_outlined,
                      label: 'Cek Rak',
                      subtitle:
                          'foto lorong rak, AI beri daftar produk yang perlu restok',
                      onTap: () => _push(context, const ShelfCheckScreen()),
                    ),
                    _MenuRow(
                      icon: Icons.point_of_sale,
                      label: 'Input Penjualan',
                      subtitle: 'catat unit terjual per toko dan tanggal',
                      onTap: () => _push(context, const SalesEntryScreen()),
                    ),
                    _MenuRow(
                      icon: Icons.beach_access,
                      label: 'Cuti',
                      subtitle: 'ajukan sakit, izin, libur, atau cuti',
                      onTap: () => _push(context, const LeaveScreen()),
                    ),
                    _MenuRow(
                      icon: Icons.sell,
                      label: 'Harga',
                      subtitle: 'laporkan harga rak dan promo di toko',
                      onTap: () => _push(context, const PricingScreen()),
                    ),
                    _MenuRow(
                      icon: Icons.assignment_ind_outlined,
                      label: 'Laporan Kehadiran',
                      subtitle: 'riwayat absensimu',
                      onTap: () => _push(
                          context, const AttendanceReportScreen(mine: true)),
                    ),
                    _MenuRow(
                      icon: Icons.summarize,
                      label: 'Ringkasan Aktivitas',
                      subtitle: 'angka absen, kunjungan, dan cuti bulan ini',
                      onTap: () => _push(context, const SummaryScreen()),
                    ),
                    if (_isManagerOrAdmin) ...[
                      _SectionHeader('Alat Manajer'),
                      _MenuRow(
                        icon: Icons.auto_awesome,
                        label: 'Wawasan AI',
                        subtitle:
                            'AI membaca penjualan, stok, dan harga lalu menyarankan tindakan',
                        onTap: () => _push(context, const InsightsScreen()),
                      ),
                      _MenuRow(
                        icon: Icons.store,
                        label: 'Kelola Toko',
                        subtitle:
                            'tambah atau ubah toko, titik lokasi, radius; bisa impor CSV',
                        onTap: () =>
                            _push(context, const StoreManagementScreen()),
                      ),
                      _MenuRow(
                        icon: Icons.assignment_ind,
                        label: 'Penugasan Toko',
                        subtitle: 'tentukan sales mana memegang toko mana',
                        onTap: () =>
                            _push(context, const StoreAssignmentScreen()),
                      ),
                      _MenuRow(
                        icon: Icons.fact_check,
                        label: 'Tinjau Pengajuan Cuti',
                        subtitle: 'setujui atau tolak cuti karyawan',
                        onTap: () => _push(context, const LeaveReviewScreen()),
                      ),
                      _MenuRow(
                        icon: Icons.assessment,
                        label: 'Laporan Absensi',
                        subtitle:
                            'absensi semua karyawan dengan selfie dan lokasi',
                        onTap: () =>
                            _push(context, const AttendanceReportScreen()),
                      ),
                      _MenuRow(
                        icon: Icons.map,
                        label: 'Laporan Kunjungan Toko',
                        subtitle:
                            'kunjungan sales, jarak dari toko, di dalam atau luar zona',
                        onTap: () =>
                            _push(context, const StoreVisitReportScreen()),
                      ),
                    ],
                    if (isAdminAccount) ...[
                      _SectionHeader('Admin'),
                      _MenuRow(
                        icon: Icons.person_add,
                        label: 'Tambah Karyawan',
                        subtitle: 'buat akun baru dan tentukan perannya',
                        onTap: () =>
                            _push(context, const UserManagementScreen()),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 22, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!,
                              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
