import 'package:flutter/material.dart';

import '../../core/help.dart';
import '../../core/supabase_client.dart';

/// Manager/admin: review pending leave requests from all employees.
/// RLS only lets manager/admin update these rows at all, so this screen
/// being reachable is not itself the access control -- the database is.
///
/// Not run on a real device.
class LeaveReviewScreen extends StatefulWidget {
  const LeaveReviewScreen({super.key});

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> with SafeSetState<LeaveReviewScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  String? _error;

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
      final rows = await supabase
          .from('leave_requests')
          .select(
              'id, leave_type, start_date, end_date, reason, employee_id, profiles!leave_requests_employee_id_fkey(full_name)')
          .eq('status', 'pending')
          .order('start_date');
      setState(() => _pending = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Gagal memuat pengajuan: ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _review(String id, String status) async {
    final ok = await confirmDialog(context,
        title: status == 'approved' ? 'Setujui pengajuan ini?' : 'Tolak pengajuan ini?',
        message: 'Keputusan tidak bisa diubah dari aplikasi.',
        yes: status == 'approved' ? 'Setujui' : 'Tolak');
    if (!ok) return;
    try {
      await supabase.from('leave_requests').update({
        'status': status,
        'reviewed_by': supabase.auth.currentUser!.id,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await _load();
      if (mounted) {
        showToast(context,
            status == 'approved' ? 'Pengajuan disetujui.' : 'Pengajuan ditolak.');
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Pengajuan Cuti'),
          actions: const [HelpButton(HelpTopic.leaveReview)],
        bottom: const HelpBar(HelpTopic.leaveReview),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (_pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child:
                          Center(child: Text('Tidak ada pengajuan tertunda.')),
                    ),
                  for (final r in _pending)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${(r['profiles'] as Map?)?['full_name'] ?? 'Tidak diketahui'}, ${kLeaveTypeLabels[r['leave_type']] ?? r['leave_type']}',
                        ),
                        subtitle: Text(
                          fmtDateRange(r['start_date'], r['end_date']) +
                          '${r['reason'] != null ? '\n${r['reason']}' : ''}',
                        ),
                        isThreeLine: r['reason'] != null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Setujui',
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              onPressed: () =>
                                  _review(r['id'] as String, 'approved'),
                            ),
                            IconButton(
                              tooltip: 'Tolak',
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () =>
                                  _review(r['id'] as String, 'rejected'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
