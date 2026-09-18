import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';

/// Employee-facing: submit a leave request and see your own request
/// history. Does NOT interact with clock-in/clock-out in any way -- that
/// interaction (e.g. blocking clock-in during approved leave) was an
/// explicit non-decision, not built. See PROJECT_NOTES.md.
///
/// Not run on a real device.
class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  static const _typeLabels = {
    'sick': 'Sick Leave',
    'permit': 'Permit',
    'off_day': 'Off Day',
    'leave': 'Leave',
  };

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      final rows = await supabase
          .from('leave_requests')
          .select()
          .eq('employee_id', userId)
          .order('start_date', ascending: false);
      setState(() => _requests = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Failed to load leave requests: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String id) async {
    try {
      await supabase.from('leave_requests').delete().eq('id', id);
      await _loadRequests();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _openRequestForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewLeaveRequestSheet(),
    );
    if (result == true) _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRequestForm,
        icon: const Icon(Icons.add),
        label: const Text('Request'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('No leave requests yet.')),
                    ),
                  for (final r in _requests)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${_typeLabels[r['leave_type']] ?? r['leave_type']}: '
                          '${r['start_date']} to ${r['end_date']}',
                        ),
                        subtitle: Text(
                          'Status: ${r['status']}'
                          '${r['reason'] != null ? '\n${r['reason']}' : ''}',
                        ),
                        isThreeLine: r['reason'] != null,
                        trailing: r['status'] == 'pending'
                            ? IconButton(
                                icon: const Icon(Icons.cancel_outlined),
                                onPressed: () => _cancel(r['id'] as String),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _NewLeaveRequestSheet extends StatefulWidget {
  const _NewLeaveRequestSheet();

  @override
  State<_NewLeaveRequestSheet> createState() => _NewLeaveRequestSheetState();
}

class _NewLeaveRequestSheetState extends State<_NewLeaveRequestSheet> {
  String _type = 'sick';
  DateTime? _start;
  DateTime? _end;
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _submit() async {
    if (_start == null || _end == null) {
      setState(() => _error = 'Pick a start and end date.');
      return;
    }
    if (_end!.isBefore(_start!)) {
      setState(() => _error = 'End date must be on or after the start date.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      await supabase.from('leave_requests').insert({
        'employee_id': userId,
        'leave_type': _type,
        'start_date': fmt(_start!),
        'end_date': fmt(_end!),
        'reason': _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New Leave Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'sick', child: Text('Sick Leave')),
              DropdownMenuItem(value: 'permit', child: Text('Permit')),
              DropdownMenuItem(value: 'off_day', child: Text('Off Day')),
              DropdownMenuItem(value: 'leave', child: Text('Leave')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_start == null ? 'Start date' : _start.toString().split(' ').first),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(isStart: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_end == null ? 'End date' : _end.toString().split(' ').first),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(isStart: false),
          ),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            maxLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Submitting...' : 'Submit'),
          ),
        ],
      ),
    );
  }
}
