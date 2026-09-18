import 'package:flutter/material.dart';

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

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
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
          .select('id, leave_type, start_date, end_date, reason, employee_id, profiles(full_name)')
          .eq('status', 'pending')
          .order('start_date');
      setState(() => _pending = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Failed to load pending requests: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _review(String id, String status) async {
    try {
      await supabase.from('leave_requests').update({
        'status': status,
        'reviewed_by': supabase.auth.currentUser!.id,
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('No pending requests.')),
                    ),
                  for (final r in _pending)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${(r['profiles'] as Map?)?['full_name'] ?? 'Unknown'} -- ${r['leave_type']}',
                        ),
                        subtitle: Text(
                          '${r['start_date']} to ${r['end_date']}'
                          '${r['reason'] != null ? '\n${r['reason']}' : ''}',
                        ),
                        isThreeLine: r['reason'] != null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () => _review(r['id'] as String, 'approved'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _review(r['id'] as String, 'rejected'),
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
