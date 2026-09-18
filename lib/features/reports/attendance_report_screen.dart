import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';

/// Manager/admin: attendance history across all employees.
///
/// SCOPE SHORTCUT: no filtering/pagination -- pulls the most recent 200
/// records. Fine for a demo, will need real pagination once there's
/// enough data for this to matter. Selfie photos are not displayed here
/// (would need a signed URL per photo, per row) -- shows only the
/// location/accuracy data. See PROJECT_NOTES.md.
///
/// Not run on a real device.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  List<Map<String, dynamic>> _records = [];
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
          .from('attendance_records')
          .select('id, clock_in_at, clock_out_at, clock_in_accuracy_meters, profiles(full_name)')
          .order('clock_in_at', ascending: false)
          .limit(200);
      setState(() => _records = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Failed to load attendance: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('No attendance records yet.')),
                    ),
                  for (final r in _records)
                    Card(
                      child: ListTile(
                        title: Text((r['profiles'] as Map?)?['full_name'] as String? ?? 'Unknown'),
                        subtitle: Text(
                          'In: ${r['clock_in_at']}\n'
                          'Out: ${r['clock_out_at'] ?? 'Still clocked in'}\n'
                          'GPS accuracy: ${r['clock_in_accuracy_meters'] ?? 'n/a'}m',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
