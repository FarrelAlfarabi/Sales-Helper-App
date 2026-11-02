import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Map with a pin, and optionally a red zone circle (store geofence).
class ZoneMap extends StatelessWidget {
  const ZoneMap({
    super.key,
    required this.point,
    this.zoneCenter,
    this.zoneRadiusMeters,
    this.height = 220,
  });

  final LatLng point;
  final LatLng? zoneCenter;
  final double? zoneRadiusMeters;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(initialCenter: zoneCenter ?? point, initialZoom: 17),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.zonein',
            ),
            if (zoneCenter != null && zoneRadiusMeters != null)
              CircleLayer(circles: [
                CircleMarker(
                  point: zoneCenter!,
                  radius: zoneRadiusMeters!,
                  useRadiusInMeter: true,
                  color: Colors.red.withValues(alpha: 0.25),
                  borderColor: Colors.red,
                  borderStrokeWidth: 2,
                ),
              ]),
            MarkerLayer(markers: [
              Marker(
                point: point,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
