import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Gets the current position with a longer timeout and fallback to last known.
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('LocationService: GPS/location services are disabled.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        debugPrint('LocationService: Location permission was not granted.');
        return null;
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: Location permission permanently denied. '
            'User must enable it in Settings.');
        return null;
      }

      // Try current position with generous timeout (30s for cold GPS fix)
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
        debugPrint('LocationService: Got current position: '
            '${position.latitude},${position.longitude}');
        return position;
      } on TimeoutException {
        debugPrint('LocationService: getCurrentPosition timed out. '
            'Trying last known position...');

        // Fallback: try last known position
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          debugPrint('LocationService: Using last known position: '
              '${lastKnown.latitude},${lastKnown.longitude}');
          return lastKnown;
        }
        debugPrint('LocationService: No last known position available.');
        return null;
      }
    } catch (error) {
      debugPrint('LocationService error: $error');
      // Last resort: try last known position on any error
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;
      } catch (_) {}
      return null;
    }
  }

  /// Returns a user-friendly status message about location availability.
  Future<String> getLocationStatus() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Location services are disabled on this device.';
    }
    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return 'Location permission not granted.';
      case LocationPermission.deniedForever:
        return 'Location permission permanently denied. Please enable it in Settings.';
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return 'Location permission granted.';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine location permission status.';
    }
  }
}
