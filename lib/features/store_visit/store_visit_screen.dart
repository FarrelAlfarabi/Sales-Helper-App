import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo_capture.dart';
import '../../core/supabase_client.dart';
import '../osa/osa_screen.dart';

/// Store visit: pick an assigned store, capture a store photo + location.
///
/// TRUST MODEL: this screen submits raw check-in coordinates only. Whether
/// that's actually "inside the zone" is decided by the database trigger
/// (compute_store_visit_geofence, see migrations), never by this client --
/// we read is_within_geofence back from the inserted row rather than
/// computing and sending it ourselves. See PROJECT_NOTES.md for what this
/// does and doesn't defend against (GPS spoofing via mock-location apps
/// is NOT covered by this MVP).
///
/// Not run on a real device -- no Flutter SDK available in this
/// environment. Needs verification on actual hardware before shipping.
class StoreVisitScreen extends StatefulWidget {
  const StoreVisitScreen({super.key});

  @override
  State<StoreVisitScreen> createState() => _StoreVisitScreenState();
}

class _StoreVisitScreenState extends State<StoreVisitScreen> {
  List<Map<String, dynamic>> _assignedStores = [];
  String? _selectedStoreId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssignedStores();
  }

  Future<void> _loadAssignedStores() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      final rows = await supabase
          .from('store_assignments')
          .select('store_id, stores(id, name, code)')
          .eq('employee_id', userId)
          .eq('is_active', true);
      setState(() {
        _assignedStores = rows
            .map((r) => r['stores'] as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      setState(() => _error = 'Failed to load assigned stores: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitVisit() async {
    if (_selectedStoreId == null) {
      setState(() => _error = 'Select a store first.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are off. Turn on GPS to check in.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to visit a store.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final photo = await PhotoCapture.capture(source: ImageSource.camera);
      if (photo == null) throw Exception('A store photo is required.');

      final userId = supabase.auth.currentUser!.id;
      final bytes = await photo.readAsBytes();
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('store-visit-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      // is_within_geofence and distance_from_store_meters are NOT sent --
      // they're overwritten server-side by the geofence trigger regardless
      // of what we put here.
      final inserted = await supabase
          .from('store_visits')
          .insert({
            'employee_id': userId,
            'store_id': _selectedStoreId,
            'check_in_latitude': position.latitude,
            'check_in_longitude': position.longitude,
            'check_in_accuracy_meters': position.accuracy,
            'store_photo_url': path,
          })
          .select()
          .single();

      final isWithinGeofence = inserted['is_within_geofence'] as bool?;
      final distance = inserted['distance_from_store_meters'] as num?;

      if (!mounted) return;

      if (isWithinGeofence == false) {
        setState(() => _error =
            'Visit recorded, but you were ${distance?.toStringAsFixed(0)}m from the store '
            '-- outside its geofence. This will show as flagged in reports.');
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OsaScreen(storeVisitId: inserted['id'] as String),
        ),
      );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Visit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assignedStores.isEmpty
              ? _EmptyState(onRetry: _loadAssignedStores)
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStoreId,
                        decoration: const InputDecoration(labelText: 'Store'),
                        items: _assignedStores
                            .map((s) => DropdownMenuItem(
                                  value: s['id'] as String,
                                  child: Text('${s['name']} (${s['code']})'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedStoreId = v),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        const SizedBox(height: 16),
                      ],
                      FilledButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: Text(_submitting ? 'Submitting...' : 'Send Visit'),
                        onPressed: _submitting ? null : _submitVisit,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('No stores are assigned to you yet.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
