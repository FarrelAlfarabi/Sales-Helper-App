import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/supabase_client.dart';

/// Clock in / clock out. Per the reference deck this is selfie + location
/// capture with NO geofence gate -- attendance is a record of where/when
/// someone clocked in, not a "must be at the office" check.
///
/// LOCATION POLICY (see PROJECT_NOTES.md): if location permission is
/// denied or the location service is off, we block the submission
/// entirely rather than silently recording a null/last-known position --
/// a clock-in with no location proves nothing. We do NOT hard-block on
/// poor GPS *accuracy* (common indoors) -- the raw accuracy value is
/// stored so managers can see low-confidence submissions themselves.
///
/// This screen has not been run on a real device -- no Flutter SDK is
/// available in the environment this was written in. Camera/location
/// permission behavior needs verification on actual Android/iOS hardware
/// before this ships.
class ClockInScreen extends StatefulWidget {
  const ClockInScreen({super.key});

  @override
  State<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends State<ClockInScreen> {
  Map<String, dynamic>? _openRecord;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOpenRecord();
  }

  Future<void> _loadOpenRecord() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      final rows = await supabase
          .from('attendance_records')
          .select()
          .eq('employee_id', userId)
          .filter('clock_out_at', 'is', null)
          .order('clock_in_at', ascending: false)
          .limit(1);
      setState(() {
        _openRecord = rows.isEmpty ? null : rows.first as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load attendance status: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Throws if permission is denied or location services are off --
  /// no silent fallback to a stale/null position.
  Future<Position> _requireCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are off. Turn on GPS to clock in.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to clock in.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<XFile?> _captureSelfie() async {
    final picker = ImagePicker();
    return picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
  }

  Future<String> _uploadSelfie(XFile file, String userId) async {
    final bytes = await file.readAsBytes();
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('attendance-selfies').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    // Stored value is the private bucket's object path, not a public URL --
    // callers must request a signed URL to actually view it.
    return path;
  }

  Future<void> _clockIn() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final position = await _requireCurrentPosition();
      final selfie = await _captureSelfie();
      if (selfie == null) throw Exception('Selfie is required to clock in.');

      final userId = supabase.auth.currentUser!.id;
      final selfiePath = await _uploadSelfie(selfie, userId);

      await supabase.from('attendance_records').insert({
        'employee_id': userId,
        'clock_in_latitude': position.latitude,
        'clock_in_longitude': position.longitude,
        'clock_in_accuracy_meters': position.accuracy,
        'clock_in_selfie_url': selfiePath,
      });

      await _loadOpenRecord();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _clockOut() async {
    if (_openRecord == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final position = await _requireCurrentPosition();
      final selfie = await _captureSelfie();
      if (selfie == null) throw Exception('Selfie is required to clock out.');

      final userId = supabase.auth.currentUser!.id;
      final selfiePath = await _uploadSelfie(selfie, userId);

      await supabase.from('attendance_records').update({
        'clock_out_at': DateTime.now().toUtc().toIso8601String(),
        'clock_out_latitude': position.latitude,
        'clock_out_longitude': position.longitude,
        'clock_out_accuracy_meters': position.accuracy,
        'clock_out_selfie_url': selfiePath,
      }).eq('id', _openRecord!['id']);

      await _loadOpenRecord();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _openRecord == null
                          ? 'You are not clocked in.'
                          : 'Clocked in at ${_openRecord!['clock_in_at']}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                    ],
                    FilledButton.icon(
                      icon: Icon(_openRecord == null ? Icons.login : Icons.logout),
                      label: Text(_submitting
                          ? 'Submitting...'
                          : (_openRecord == null ? 'Clock In' : 'Clock Out')),
                      onPressed: _submitting
                          ? null
                          : (_openRecord == null ? _clockIn : _clockOut),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
