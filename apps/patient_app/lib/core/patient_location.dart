import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smartride_core/smartride_core.dart' show ErrorReporter;

/// Where the patient's location stands. Opening the home screen only ever
/// *reads* this; asking the user for permission is always a deliberate tap.
enum LocationStatus {
  loading,
  granted,

  /// Permission is granted but no fix arrived (indoors, GPS warming up).
  noFix,
  denied,
  deniedForever,
  serviceOff,
}

class PatientLocation {
  const PatientLocation(this.status, [this.position]);

  final LocationStatus status;
  final Position? position;

  bool get hasPosition => position != null;
}

/// The plugin calls behind [PatientLocationNotifier], so tests can fake them.
abstract class LocationGateway {
  Future<bool> serviceEnabled();
  Future<LocationPermission> permission();
  Future<LocationPermission> requestPermission();
  Future<Position?> position();
  Future<void> openSettings();
}

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> permission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position?> position() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      // No live fix in time: report none rather than show an old position.
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}

final locationGatewayProvider =
    Provider<LocationGateway>((ref) => const GeolocatorGateway());

/// A stream of live GPS fixes, never a saved position. It only reports fixes
/// the phone takes while it is listened to, and it never shows a permission
/// prompt (the stream errors if location is not allowed). A function, so tests
/// can fake it.
final livePositionStreamProvider = Provider<Stream<Position> Function()>(
  (ref) => () => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ),
);

final patientLocationProvider =
    StateNotifierProvider<PatientLocationNotifier, PatientLocation>(
  (ref) => PatientLocationNotifier(ref.watch(locationGatewayProvider)),
);

class PatientLocationNotifier extends StateNotifier<PatientLocation> {
  PatientLocationNotifier(this._gateway)
      : super(const PatientLocation(LocationStatus.loading));

  final LocationGateway _gateway;

  /// Reads the current state without ever showing a permission prompt.
  Future<void> refresh() => _read(prompt: false);

  /// Shows the permission dialog if the permission is merely denied, and reads
  /// the position. Never opens settings; use it when a screen opens because of a
  /// deliberate tap (such as the emergency confirmation).
  Future<void> prompt() => _read(prompt: true);

  /// For a deliberate user action (recenter, enable location). Prompts once if
  /// the permission has not been refused for good; otherwise opens settings.
  Future<void> request() async {
    try {
      if (await _gateway.permission() == LocationPermission.deniedForever) {
        await _gateway.openSettings();
        return;
      }
    } on Exception catch (e, st) {
      ErrorReporter.report('Could not read location permission', e, st);
    }
    await prompt();
  }

  Future<void> _read({required bool prompt}) async {
    try {
      if (!await _gateway.serviceEnabled()) {
        _set(const PatientLocation(LocationStatus.serviceOff));
        return;
      }
      var permission = await _gateway.permission();
      if (permission == LocationPermission.denied && prompt) {
        permission = await _gateway.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _set(const PatientLocation(LocationStatus.deniedForever));
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _set(const PatientLocation(LocationStatus.denied));
        return;
      }
      final fix = await _gateway.position();
      _set(
        fix == null
            ? const PatientLocation(LocationStatus.noFix)
            : PatientLocation(LocationStatus.granted, fix),
      );
    } on Exception catch (e, st) {
      ErrorReporter.report('Could not read the device location', e, st);
      _set(const PatientLocation(LocationStatus.noFix));
    }
  }

  /// Applies a live fix from the position stream.
  void applyLiveFix(Position fix) =>
      _set(PatientLocation(LocationStatus.granted, fix));

  void _set(PatientLocation value) {
    if (mounted) state = value;
  }
}
