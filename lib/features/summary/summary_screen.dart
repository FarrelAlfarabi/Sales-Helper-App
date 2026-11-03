import 'package:flutter/material.dart';

import '../../core/help.dart';
import '../../core/supabase_client.dart';

/// "Your Summary" for the signed-in employee, current month. Counts only,
/// from the employee's own rows (RLS already limits to them).
/// ASSUMPTION: the ViewLT deck does not describe this screen, so the
/// contents here (days present, visits, zone compliance, leave) are a
/// reasonable guess, not a copy of ViewLT.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _loading = true;
  String? _error;
  int _days = 0, _visits = 0, _inside = 0, _leave = 0, _pending = 0;

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
      final uid = supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
      final att = await supabase
          .from('attendance_records')
          .select('clock_in_at')
          .eq('employee_id', uid)
          .gte('clock_in_at', from);
      final days = <String>{
        for (final r in att)
          DateTime.parse(r['clock_in_at'])
              .toLocal()
              .toIso8601String()
              .substring(0, 10),
      };
      final vis = await supabase
          .from('store_visits')
          .select('is_within_geofence')
          .eq('employee_id', uid)
          .gte('visit_started_at', from);
      final lv = await supabase
          .from('leave_requests')
          .select('status')
          .eq('employee_id', uid)
          .gte('start_date', from.substring(0, 10));
      setState(() {
        _days = days.length;
        _visits = vis.length;
        _inside = vis.where((v) => v['is_within_geofence'] == true).length;
        _leave = lv.where((l) => l['status'] == 'approved').length;
        _pending = lv.where((l) => l['status'] == 'pending').length;
      });
    } catch (e) {
      setState(() => _error = 'Gagal memuat ringkasan: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Ringkasan Aktivitas'),
          actions: const [HelpButton(HelpTopic.summary)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Bulan ini',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: cs.error)),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _Stat(
                          label: 'Hari hadir',
                          value: '$_days',
                          icon: Icons.calendar_today),
                      _Stat(
                          label: 'Kunjungan toko',
                          value: '$_visits',
                          icon: Icons.storefront),
                      _Stat(
                          label: 'Dalam zona',
                          value: _visits == 0 ? '-' : '$_inside/$_visits',
                          icon: Icons.verified),
                      _Stat(
                          label: 'Cuti disetujui',
                          value: '$_leave',
                          icon: Icons.beach_access),
                    ],
                  ),
                  if (_pending > 0) ...[
                    const SizedBox(height: 12),
                    Text('$_pending pengajuan cuti menunggu persetujuan.'),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: cs.primary),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
