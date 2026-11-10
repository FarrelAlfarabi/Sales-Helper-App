import 'package:flutter/material.dart';

import '../../core/help.dart';
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

class _LeaveScreenState extends State<LeaveScreen> with SafeSetState<LeaveScreen> {
  static const _statusId = {
    'pending': 'menunggu',
    'approved': 'disetujui',
    'rejected': 'ditolak'
  };
  static const _typeLabels = {
    'sick': 'Sakit',
    'permit': 'Izin',
    'off_day': 'Hari Libur',
    'leave': 'Cuti',
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
      setState(() => _error = 'Gagal memuat pengajuan cuti: ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String id) async {
    final ok = await confirmDialog(context,
        title: 'Batalkan pengajuan ini?', yes: 'Batalkan', no: 'Tidak');
    if (!ok) return;
    try {
      await supabase.from('leave_requests').delete().eq('id', id);
      await _loadRequests();
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _openRequestForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewLeaveRequestSheet(),
    );
    if (result == true) {
      _loadRequests();
      if (mounted) showToast(context, 'Pengajuan terkirim.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Cuti'),
          actions: const [HelpButton(HelpTopic.leave)],
        bottom: const HelpBar(HelpTopic.leave),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRequestForm,
        icon: const Icon(Icons.add),
        label: const Text('Ajukan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (_requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('Belum ada pengajuan cuti.')),
                    ),
                  for (final r in _requests)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${_typeLabels[r['leave_type']] ?? r['leave_type']}: '
                          '${fmtDateRange(r['start_date'], r['end_date'])}',
                        ),
                        subtitle: Text(
                          'Status: ${_statusId[r['status']] ?? r['status']}'
                          '${r['reason'] != null ? '\n${r['reason']}' : ''}',
                        ),
                        isThreeLine: r['reason'] != null,
                        trailing: r['status'] == 'pending'
                            ? IconButton(
                                tooltip: 'Batalkan pengajuan',
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

class _NewLeaveRequestSheetState extends State<_NewLeaveRequestSheet> with SafeSetState<_NewLeaveRequestSheet> {
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
      initialDate: (isStart ? _start : (_end ?? _start)) ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _submit() async {
    if (_start == null || _end == null) {
      setState(() => _error = 'Pilih tanggal mulai dan selesai.');
      return;
    }
    if (_end!.isBefore(_start!)) {
      setState(
          () => _error = 'Tanggal selesai tidak boleh sebelum tanggal mulai.');
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
        'reason': _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
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
          const Text('Pengajuan Cuti Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Jenis'),
            items: const [
              DropdownMenuItem(value: 'sick', child: Text('Sakit')),
              DropdownMenuItem(value: 'permit', child: Text('Izin')),
              DropdownMenuItem(value: 'off_day', child: Text('Hari Libur')),
              DropdownMenuItem(value: 'leave', child: Text('Cuti')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_start == null
                ? 'Tanggal mulai'
                : 'Mulai: ${fmtDate(_start!.toIso8601String().substring(0, 10))}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(isStart: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_end == null
                ? 'Tanggal selesai'
                : 'Selesai: ${fmtDate(_end!.toIso8601String().substring(0, 10))}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(isStart: false),
          ),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Alasan (opsional)'),
            maxLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Mengirim...' : 'Kirim'),
          ),
        ],
      ),
    );
  }
}
