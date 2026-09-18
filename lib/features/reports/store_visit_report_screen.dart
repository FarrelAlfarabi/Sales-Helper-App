import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';

/// Manager/admin: store visit history across all employees, with the
/// server-computed geofence flag surfaced directly -- this is the report
/// that actually exercises the "was this employee really there" question.
///
/// SCOPE SHORTCUT: no filtering/pagination, most recent 200 only, no
/// photo display. See PROJECT_NOTES.md.
///
/// Not run on a real device.
class StoreVisitReportScreen extends StatefulWidget {
  const StoreVisitReportScreen({super.key});

  @override
  State<StoreVisitReportScreen> createState() => _StoreVisitReportScreenState();
}

class _StoreVisitReportScreenState extends State<StoreVisitReportScreen> {
  List<Map<String, dynamic>> _visits = [];
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
          .from('store_visits')
          .select(
            'id, visit_started_at, distance_from_store_meters, is_within_geofence, '
            'profiles(full_name), stores(name, code)',
          )
          .order('visit_started_at', ascending: false)
          .limit(200);
      setState(() => _visits = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Failed to load store visits: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Visit Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_visits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('No store visits yet.')),
                    ),
                  for (final v in _visits)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          v['is_within_geofence'] == true ? Icons.check_circle : Icons.warning,
                          color: v['is_within_geofence'] == true ? Colors.green : Colors.orange,
                        ),
                        title: Text(
                          '${(v['profiles'] as Map?)?['full_name'] ?? '?'} -> '
                          '${(v['stores'] as Map?)?['name'] ?? '?'}',
                        ),
                        subtitle: Text(
                          '${v['visit_started_at']}\n'
                          'Distance: ${(v['distance_from_store_meters'] as num?)?.toStringAsFixed(0) ?? '?'}m '
                          '(${v['is_within_geofence'] == true ? 'inside zone' : 'OUTSIDE zone'})',
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
