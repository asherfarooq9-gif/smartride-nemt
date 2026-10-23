import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartride_core/smartride_core.dart' show ErrorReporter;

/// The device's current position, or null when location services are off or
/// permission is denied. Never throws: callers decide how to explain it.
Future<Position?> currentPositionOrNull() async {
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
        timeLimit: Duration(seconds: 10),
      ),
    );
  } on TimeoutException {
    // A fix did not arrive in time; a recent one is still good enough to dispatch.
    return Geolocator.getLastKnownPosition();
  } on Exception catch (e, st) {
    // Plugin/platform failure: callers treat null as "no location" and tell
    // the user, but the cause must not vanish.
    ErrorReporter.report('Could not read the device location', e, st);
    return null;
  }
}

/// GPS settings for a driver streaming during a ride. On Android a foreground
/// notification keeps the stream alive with the screen off; on iOS the
/// background-location mode does (see Info.plist).
LocationSettings driverTrackingSettings() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'SmartRide',
          notificationText: 'Sharing your location with the patient',
          enableWakeLock: true,
        ),
      );
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    default:
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
  }
}

/// Indirection so tests can supply a fake position without the plugin.
final locationReaderProvider =
    Provider<Future<Position?> Function()>((ref) => currentPositionOrNull);
