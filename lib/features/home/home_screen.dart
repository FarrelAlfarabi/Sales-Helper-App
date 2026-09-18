import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../admin/store_assignment_screen.dart';
import '../admin/store_management_screen.dart';
import '../admin/user_management_screen.dart';
import '../attendance/clock_in_screen.dart';
import '../leave/leave_review_screen.dart';
import '../leave/leave_screen.dart';
import '../reports/attendance_report_screen.dart';
import '../reports/store_visit_report_screen.dart';
import '../store_visit/store_visit_screen.dart';

// Gates the "Add Employee" tile specifically to this one account, per an
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

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final row = await supabase.from('profiles').select('role').eq('id', userId).single();
      setState(() => _isManagerOrAdmin = row['role'] == 'manager' || row['role'] == 'admin');
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
            tooltip: 'Sign out',
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: _loadingRole
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                            Text('Signed in as', style: Theme.of(context).textTheme.bodySmall),
                            Text(email, style: Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _SectionHeader('Your Work'),
                _MenuRow(
                  icon: Icons.calendar_today,
                  label: 'Attendance',
                  onTap: () => _push(context, const ClockInScreen()),
                ),
                _MenuRow(
                  icon: Icons.storefront,
                  label: 'Store Visit',
                  subtitle: 'includes On Shelf Availability',
                  onTap: () => _push(context, const StoreVisitScreen()),
                ),
                _MenuRow(
                  icon: Icons.beach_access,
                  label: 'Leave',
                  onTap: () => _push(context, const LeaveScreen()),
                ),
                const _MenuRow(icon: Icons.sell, label: 'Pricing', enabled: false, subtitle: 'not built yet'),
                const _MenuRow(icon: Icons.summarize, label: 'Summary Activity', enabled: false, subtitle: 'not built yet'),
                if (_isManagerOrAdmin) ...[
                  _SectionHeader('Manager Tools'),
                  _MenuRow(
                    icon: Icons.store,
                    label: 'Manage Stores',
                    onTap: () => _push(context, const StoreManagementScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.assignment_ind,
                    label: 'Store Assignments',
                    onTap: () => _push(context, const StoreAssignmentScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.fact_check,
                    label: 'Review Leave Requests',
                    onTap: () => _push(context, const LeaveReviewScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.assessment,
                    label: 'Attendance Report',
                    onTap: () => _push(context, const AttendanceReportScreen()),
                  ),
                  _MenuRow(
                    icon: Icons.map,
                    label: 'Store Visit Report',
                    onTap: () => _push(context, const StoreVisitReportScreen()),
                  ),
                ],
                if (isAdminAccount) ...[
                  _SectionHeader('Admin'),
                  _MenuRow(
                    icon: Icons.person_add,
                    label: 'Add Employee',
                    onTap: () => _push(context, const UserManagementScreen()),
                  ),
                ],
                const SizedBox(height: 16),
              ],
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
