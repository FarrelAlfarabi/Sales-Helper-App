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

/// Home menu, mirroring the reference deck's layout plus what's been added
/// since: Attendance, Leave, Store Visit (which leads into On Shelf
/// Availability), and -- for manager/admin only -- Store management,
/// Store assignments, Leave review, and the two reports. Pricing and
/// Summary Activity are still placeholders: the reference deck names them
/// but describes no actual functionality, so there's nothing to build
/// them from yet. See PROJECT_NOTES.md.
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
    final email = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonein'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Signed in as $email', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              if (!_loadingRole && _isManagerOrAdmin)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Manager tools', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              Expanded(
                child: _loadingRole
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _MenuTile(
                            icon: Icons.calendar_today,
                            label: 'Attendance',
                            onTap: () => _push(context, const ClockInScreen()),
                          ),
                          const _MenuTile(icon: Icons.sell, label: 'Pricing (not built yet)'),
                          _MenuTile(
                            icon: Icons.storefront,
                            label: 'Store Visit',
                            onTap: () => _push(context, const StoreVisitScreen()),
                          ),
                          const _MenuTile(
                            icon: Icons.shelves,
                            label: 'On Shelf Availability (via Store Visit)',
                          ),
                          const _MenuTile(
                            icon: Icons.summarize,
                            label: 'Summary Activity (not built yet)',
                          ),
                          _MenuTile(
                            icon: Icons.beach_access,
                            label: 'Leave',
                            onTap: () => _push(context, const LeaveScreen()),
                          ),
                          if (_isManagerOrAdmin) ...[
                            _MenuTile(
                              icon: Icons.store,
                              label: 'Manage Stores',
                              onTap: () => _push(context, const StoreManagementScreen()),
                            ),
                            _MenuTile(
                              icon: Icons.assignment_ind,
                              label: 'Store Assignments',
                              onTap: () => _push(context, const StoreAssignmentScreen()),
                            ),
                            _MenuTile(
                              icon: Icons.fact_check,
                              label: 'Review Leave Requests',
                              onTap: () => _push(context, const LeaveReviewScreen()),
                            ),
                            _MenuTile(
                              icon: Icons.assessment,
                              label: 'Attendance Report',
                              onTap: () => _push(context, const AttendanceReportScreen()),
                            ),
                            _MenuTile(
                              icon: Icons.map,
                              label: 'Store Visit Report',
                              onTap: () => _push(context, const StoreVisitReportScreen()),
                            ),
                          ],
                          if (email.toLowerCase() == _kAdminEmail)
                            _MenuTile(
                              icon: Icons.person_add,
                              label: 'Add Employee',
                              onTap: () => _push(context, const UserManagementScreen()),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: onTap == null ? Colors.grey : null),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: onTap == null ? Colors.grey : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
