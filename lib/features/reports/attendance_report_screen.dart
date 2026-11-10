import 'package:flutter/material.dart';
import '../../core/help.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/signed_photo.dart';
import '../../core/supabase_client.dart';
import '../../core/zone_map.dart';

/// Presence report. [mine] = true shows only the signed-in employee's own
/// history (field rep view); false shows everyone (manager/admin, RLS decides).
/// Has a date-range filter; still capped at 200 rows, no pagination.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key, this.mine = false});

  final bool mine;

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> with SafeSetState<AttendanceReportScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  DateTimeRange? _range;

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
      var q = supabase.from('attendance_records').select(
            'id, clock_in_at, clock_out_at, clock_in_latitude, clock_in_longitude, '
            'clock_in_accuracy_meters, clock_in_selfie_url, clock_out_selfie_url, profiles(full_name)',
          );
      if (widget.mine) q = q.eq('employee_id', supabase.auth.currentUser!.id);
      if (_range != null) {
        q = q.gte('clock_in_at', _range!.start.toUtc().toIso8601String()).lt(
            'clock_in_at',
            _range!.end.add(const Duration(days: 1)).toUtc().toIso8601String());
      }
      final rows = await q.order('clock_in_at', ascending: false).limit(200);
      setState(() => _records = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Gagal memuat absensi: ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (r != null) {
      _range = r;
      _load();
    }
  }

  static String _t(String? iso) => iso == null
      ? '-'
      : DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mine ? 'Laporan Kehadiran' : 'Laporan Absensi'),
        actions: [
          if (_range != null)
            IconButton(
              tooltip: 'Hapus filter',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () {
                _range = null;
                _load();
              },
            ),
          IconButton(
              tooltip: 'Filter tanggal',
              icon: const Icon(Icons.filter_list),
              onPressed: _pickRange),
          HelpButton(
              widget.mine ? HelpTopic.myAttendance : HelpTopic.attendanceAll),
        ],
        bottom: HelpBar(widget.mine ? HelpTopic.myAttendance : HelpTopic.attendanceAll),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: cs.error)),
                  if (_records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('Belum ada data absensi.')),
                    ),
                  for (final r in _records)
                    Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => PresenceDetailScreen(record: r)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEE, dd-MM-yyyy').format(
                                    DateTime.parse(r['clock_in_at']).toLocal()),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (r['profiles'] as Map?)?['full_name']
                                        as String? ??
                                    'Tidak diketahui',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                      child: _TimeChip(
                                          label: 'Absen Masuk',
                                          value: _t(r['clock_in_at']))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _TimeChip(
                                          label: 'Absen Pulang',
                                          value: _t(r['clock_out_at']))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ]),
    );
  }
}

/// Presence detail: times, both selfies, and the clock-in location on a map.
class PresenceDetailScreen extends StatelessWidget {
  const PresenceDetailScreen({super.key, required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final lat = (r['clock_in_latitude'] as num).toDouble();
    final lng = (r['clock_in_longitude'] as num).toDouble();
    String fmt(String? iso) => iso == null
        ? 'Belum'
        : DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Kehadiran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
              (r['profiles'] as Map?)?['full_name'] as String? ??
                  'Tidak diketahui',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _TimeChip(
                    label: 'Absen Masuk', value: fmt(r['clock_in_at']))),
            const SizedBox(width: 8),
            Expanded(
                child: _TimeChip(
                    label: 'Absen Pulang', value: fmt(r['clock_out_at']))),
          ]),
          const SizedBox(height: 20),
          Text('Foto', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: SignedPhoto(
                    bucket: 'attendance-selfies',
                    path: r['clock_in_selfie_url'] as String?)),
            const SizedBox(width: 8),
            Expanded(
                child: SignedPhoto(
                    bucket: 'attendance-selfies',
                    path: r['clock_out_selfie_url'] as String?)),
          ]),
          const SizedBox(height: 20),
          Text('Lokasi', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ZoneMap(point: LatLng(lat, lng)),
          const SizedBox(height: 6),
          Text(
              'Akurasi GPS: ${(r['clock_in_accuracy_meters'] as num?) == null ? 'tidak tercatat' : '${(r['clock_in_accuracy_meters'] as num).round()} m'}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
