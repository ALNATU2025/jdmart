import 'package:geolocator/geolocator.dart';

/// GPS access for live delivery tracking.
class LocationService {
  /// Asks for permission if needed. Returns an error message, or null when OK.
  static Future<String?> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Turn on Location (GPS) on your device to share your position.';
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) return 'Allow location access to share your live position.';
      if (p == LocationPermission.deniedForever) {
        return 'Location is blocked for JDMart. Allow it in your phone or browser settings.';
      }
      return null;
    } catch (e) {
      return "Couldn't access your location ($e).";
    }
  }

  /// Position updates every ~15 metres of movement.
  static Stream<Position> positions() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
      );

  static Future<Position?> current() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  /// Straight-line distance in metres.
  static double distance(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  static String formatDistance(double metres) =>
      metres < 1000 ? '${metres.round()} m' : '${(metres / 1000).toStringAsFixed(metres < 10000 ? 1 : 0)} km';
}
