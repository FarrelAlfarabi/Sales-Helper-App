import 'package:flutter/material.dart';

import '../../core/help.dart';
import 'package:latlong2/latlong.dart';

import '../../core/signed_photo.dart';
import '../../core/supabase_client.dart';
import '../../core/zone_map.dart';

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
            'check_in_latitude, check_in_longitude, store_photo_url, '
            'profiles(full_name), stores(name, code, latitude, longitude, geofence_radius_meters)',
          )
          .order('visit_started_at', ascending: false)
          .limit(200);
      setState(() => _visits = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      setState(() => _error = 'Gagal memuat kunjungan toko: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Laporan Kunjungan Toko'),
          actions: const [HelpButton(HelpTopic.visitReport)],
        bottom: const HelpBar(HelpTopic.visitReport),
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
                  if (_visits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('Belum ada kunjungan toko.')),
                    ),
                  for (final v in _visits)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          v['is_within_geofence'] == true
                              ? Icons.check_circle
                              : Icons.warning,
                          color: v['is_within_geofence'] == true
                              ? Colors.green
                              : Colors.orange,
                        ),
                        title: Text(
                          '${(v['profiles'] as Map?)?['full_name'] ?? '?'} -> '
                          '${(v['stores'] as Map?)?['name'] ?? '?'}',
                        ),
                        subtitle: Text(
                          '${v['visit_started_at']}\n'
                          'Jarak: ${(v['distance_from_store_meters'] as num?)?.toStringAsFixed(0) ?? '?'}m '
                          '(${v['is_within_geofence'] == true ? 'inside zone' : 'OUTSIDE zone'})',
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => VisitDetailScreen(visit: v)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Visit detail: store photo plus the check-in point against the store's
/// zone circle, like ViewLT's "Zonasi Toko" view.
class VisitDetailScreen extends StatelessWidget {
  const VisitDetailScreen({super.key, required this.visit});
  final Map<String, dynamic> visit;

  @override
  Widget build(BuildContext context) {
    final store = (visit['stores'] as Map?) ?? const {};
    final inside = visit['is_within_geofence'] == true;
    final point = LatLng((visit['check_in_latitude'] as num).toDouble(),
        (visit['check_in_longitude'] as num).toDouble());
    final center = (store['latitude'] != null && store['longitude'] != null)
        ? LatLng((store['latitude'] as num).toDouble(),
            (store['longitude'] as num).toDouble())
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Zonasi Toko')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${store['name'] ?? '?'} (${store['code'] ?? ''})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Chip(
            avatar: Icon(inside ? Icons.check_circle : Icons.warning,
                color: inside ? Colors.green : Colors.orange),
            label: Text(inside ? 'Dalam Zona' : 'Luar Zona'),
          ),
          const SizedBox(height: 12),
          ZoneMap(
            point: point,
            zoneCenter: center,
            zoneRadiusMeters:
                (store['geofence_radius_meters'] as num?)?.toDouble(),
            height: 280,
          ),
          const SizedBox(height: 16),
          SignedPhoto(
              bucket: 'store-visit-photos',
              path: visit['store_photo_url'] as String?),
        ],
      ),
    );
  }
}
