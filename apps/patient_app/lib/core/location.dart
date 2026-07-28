import 'package:geolocator/geolocator.dart';

/// Requests location permission if needed and returns the device's current
/// position, or null if permission is denied/unavailable. Every ride-create
/// call needs this — the backend requires pickup_lat/pickup_lng on both
/// emergency and scheduled rides, they are not optional.
Future<Position?> getCurrentPositionSafe() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  } on Exception {
    return null;
  }
}
