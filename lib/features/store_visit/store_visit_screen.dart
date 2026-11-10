import 'package:flutter/material.dart';
import '../../core/help.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/location.dart';
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
  const StoreVisitScreen({super.key, this.initialStoreId});

  /// Toko yang dipilih dari beranda "Hari ini".
  final String? initialStoreId;

  @override
  State<StoreVisitScreen> createState() => _StoreVisitScreenState();
}

class _StoreVisitScreenState extends State<StoreVisitScreen> with SafeSetState<StoreVisitScreen> {
  List<Map<String, dynamic>> _assignedStores = [];
  late String? _selectedStoreId = widget.initialStoreId;
  Position? _pos;
  bool _suggested = false;
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
          .select('store_id, stores(id, name, code, latitude, longitude, geofence_radius_meters, is_active)')
          .eq('employee_id', userId)
          .eq('is_active', true);
      setState(() {
        _assignedStores = [
          for (final r in rows)
            if (r['stores'] != null && (r['stores'] as Map)['is_active'] != false)
              Map<String, dynamic>.from(r['stores'] as Map),
        ];
        if (!_assignedStores.any((s) => s['id'] == _selectedStoreId)) {
          _selectedStoreId = null;
        }
      });
      _suggestNearest();
    } catch (e) {
      setState(() => _error = 'Gagal memuat toko tugas: ${friendlyError(e)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Urutkan toko dari yang terdekat dan pilih otomatis yang paling dekat,
  /// kecuali sales sudah memilih toko dari beranda.
  Future<void> _suggestNearest() async {
    final pos = await tryCurrentPosition(askPermission: true);
    if (pos == null || !mounted) return;
    setState(() {
      _pos = pos;
      _assignedStores.sort((a, b) =>
          (distanceToStore(pos, a) ?? double.infinity)
              .compareTo(distanceToStore(pos, b) ?? double.infinity));
      if (_selectedStoreId == null && _assignedStores.isNotEmpty) {
        final d = distanceToStore(pos, _assignedStores.first);
        if (d != null && d <= 1000) {
          _selectedStoreId = _assignedStores.first['id'] as String;
          _suggested = true;
        }
      }
    });
  }

  Future<void> _submitVisit() async {
    if (_selectedStoreId == null) {
      setState(() => _error = 'Pilih toko dulu.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan lokasi mati. Aktifkan GPS untuk check-in.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi diperlukan untuk kunjungan toko.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final photo = await PhotoCapture.capture(source: ImageSource.camera);
      if (photo == null) throw Exception('Foto toko wajib diisi.');

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

      // Peringatan luar zona ditampilkan di layar berikutnya, karena layar
      // ini langsung tertutup oleh Ketersediaan di Rak.
      final notice = isWithinGeofence == false
          ? 'Kunjungan tercatat, tetapi kamu berada ${distance?.toStringAsFixed(0) ?? '?'} m dari toko, di luar zona. Ini ditandai di laporan manajer.'
          : null;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OsaScreen(
              storeVisitId: inserted['id'] as String,
              storeId: _selectedStoreId!,
              storeName: '${_assignedStores.firstWhere((s) => s['id'] == _selectedStoreId, orElse: () => {})['name'] ?? ''}',
              notice: notice),
        ),
      );
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Kunjungan Toko'),
          actions: const [HelpButton(HelpTopic.storeVisit)],
        bottom: const HelpBar(HelpTopic.storeVisit),
      ),
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
                        decoration: const InputDecoration(labelText: 'Toko'),
                        items: _assignedStores
                            .map((s) {
                              final d = distanceToStore(_pos, s);
                              return DropdownMenuItem(
                                value: s['id'] as String,
                                child: Text(
                                  '${s['name']}${d == null ? '' : ' · ${fmtDistance(d)}'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            })
                            .toList(),
                        onChanged: (v) => setState(() {
                          _selectedStoreId = v;
                          _suggested = false;
                        }),
                      ),
                      if (_suggested)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Dipilih otomatis: toko terdekat dari lokasimu.',
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Langkahnya: ambil foto depan toko, lokasi dicatat otomatis, lalu isi foto rak.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        const SizedBox(height: 16),
                      ],
                      FilledButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                            _submitting ? 'Mengirim...' : 'Foto toko dan check-in'),
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
            Icon(Icons.storefront_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('Belum ada toko yang ditugaskan kepadamu.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Muat ulang')),
          ],
        ),
      ),
    );
  }
}
