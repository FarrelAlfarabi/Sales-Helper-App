import 'package:geolocator/geolocator.dart';

/// Posisi saat ini tanpa memaksa izin. Mengembalikan null jika GPS mati,
/// izin belum diberikan, atau terlalu lama. Dipakai untuk saran toko
/// terdekat, bukan untuk absen (absen tetap wajib lokasi).
Future<Position?> tryCurrentPosition({bool askPermission = false}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied && askPermission) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Jarak dalam meter dari posisi ke toko, atau null jika tidak diketahui.
double? distanceToStore(Position? pos, Map<String, dynamic> store) {
  final lat = (store['latitude'] as num?)?.toDouble();
  final lng = (store['longitude'] as num?)?.toDouble();
  if (pos == null || lat == null || lng == null) return null;
  return Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
}

/// "120 m" atau "2,4 km".
String fmtDistance(double m) => m < 1000
    ? '${m.round()} m'
    : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
