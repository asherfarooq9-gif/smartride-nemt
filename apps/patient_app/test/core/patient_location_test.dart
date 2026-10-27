import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patient_app/core/patient_location.dart';

Position _at(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 10, 27),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _FakeGateway implements LocationGateway {
  _FakeGateway({
    this.isServiceOn = true,
    this.current = LocationPermission.whileInUse,
    this.afterRequest = LocationPermission.whileInUse,
    this.fix,
  });

  bool isServiceOn;
  LocationPermission current;
  LocationPermission afterRequest;
  Position? fix;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<bool> serviceEnabled() async => isServiceOn;

  @override
  Future<LocationPermission> permission() async => current;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    current = afterRequest;
    return current;
  }

  @override
  Future<Position?> position() async => fix;

  @override
  Future<void> openSettings() async => settingsOpened++;
}

ProviderContainer _container(_FakeGateway gateway) {
  final c = ProviderContainer(
    overrides: [locationGatewayProvider.overrideWithValue(gateway)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('opening home never prompts for permission', () async {
    final gateway = _FakeGateway(current: LocationPermission.denied);
    final c = _container(gateway);

    await c.read(patientLocationProvider.notifier).refresh();

    expect(c.read(patientLocationProvider).status, LocationStatus.denied);
    expect(gateway.requests, 0);
  });

  test('with permission, the real position is used', () async {
    final gateway = _FakeGateway(fix: _at(31.52, 74.36));
    final c = _container(gateway);

    await c.read(patientLocationProvider.notifier).refresh();

    final state = c.read(patientLocationProvider);
    expect(state.status, LocationStatus.granted);
    expect(state.position?.latitude, 31.52);
    expect(state.position?.longitude, 74.36);
  });

  test('permission but no fix yet is reported, not invented', () async {
    final c = _container(_FakeGateway(fix: null));

    await c.read(patientLocationProvider.notifier).refresh();

    final state = c.read(patientLocationProvider);
    expect(state.status, LocationStatus.noFix);
    expect(state.position, isNull);
  });

  test('location services off is its own state', () async {
    final c = _container(_FakeGateway(isServiceOn: false));

    await c.read(patientLocationProvider.notifier).refresh();

    expect(c.read(patientLocationProvider).status, LocationStatus.serviceOff);
  });

  test('permanently denied is reported so the UI can open settings', () async {
    final c = _container(
      _FakeGateway(current: LocationPermission.deniedForever),
    );

    await c.read(patientLocationProvider.notifier).refresh();

    expect(
      c.read(patientLocationProvider).status,
      LocationStatus.deniedForever,
    );
  });

  test('asking from a user action prompts once and then reads the position',
      () async {
    final gateway = _FakeGateway(
      current: LocationPermission.denied,
      afterRequest: LocationPermission.whileInUse,
      fix: _at(33.0, 73.0),
    );
    final c = _container(gateway);

    await c.read(patientLocationProvider.notifier).request();

    expect(gateway.requests, 1);
    expect(c.read(patientLocationProvider).status, LocationStatus.granted);
    expect(c.read(patientLocationProvider).position?.latitude, 33.0);
  });

  test('asking and being refused stays denied', () async {
    final gateway = _FakeGateway(
      current: LocationPermission.denied,
      afterRequest: LocationPermission.denied,
    );
    final c = _container(gateway);

    await c.read(patientLocationProvider.notifier).request();

    expect(c.read(patientLocationProvider).status, LocationStatus.denied);
  });

  test('asking when permanently denied opens settings instead of prompting',
      () async {
    final gateway = _FakeGateway(current: LocationPermission.deniedForever);
    final c = _container(gateway);

    await c.read(patientLocationProvider.notifier).request();

    expect(gateway.requests, 0);
    expect(gateway.settingsOpened, 1);
  });

  test('prompting for permission never opens settings by itself', () async {
    final gateway = _FakeGateway(current: LocationPermission.deniedForever);
    final c = _container(gateway);

    await c.read(patientLocationProvider.notifier).prompt();

    expect(gateway.settingsOpened, 0);
    expect(gateway.requests, 0);
    expect(
      c.read(patientLocationProvider).status,
      LocationStatus.deniedForever,
    );
  });

  test('prompting shows the permission dialog when it is merely denied',
      () async {
    final gateway = _FakeGateway(
      current: LocationPermission.denied,
      afterRequest: LocationPermission.whileInUse,
      fix: _at(33.0, 73.0),
    );
    final c = _container(gateway);

    await c.read(patientLocationProvider.notifier).prompt();

    expect(gateway.requests, 1);
    expect(c.read(patientLocationProvider).status, LocationStatus.granted);
  });

  test('starts in the loading state', () {
    final c = _container(_FakeGateway());

    expect(c.read(patientLocationProvider).status, LocationStatus.loading);
  });
}
