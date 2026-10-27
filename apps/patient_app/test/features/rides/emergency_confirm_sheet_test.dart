import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/features/rides/emergency_confirm_sheet.dart';

Position _at(double lat, double lng, {double accuracy = 18}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 10, 27),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _Gateway implements LocationGateway {
  _Gateway({
    this.isServiceOn = true,
    this.permissionState = LocationPermission.whileInUse,
    this.afterRequest = LocationPermission.whileInUse,
    this.fix,
  });
  bool isServiceOn;
  LocationPermission permissionState;
  LocationPermission afterRequest;
  Position? fix;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<bool> serviceEnabled() async => isServiceOn;
  @override
  Future<LocationPermission> permission() async => permissionState;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    permissionState = afterRequest;
    return permissionState;
  }

  @override
  Future<Position?> position() async => fix;
  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// A home with a button that opens the confirm sheet, like the SOS button.
Widget _app(_Gateway gateway, {VoidCallback? onCall}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, __) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showEmergencyConfirm(context, onCall: onCall),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/symptoms',
      builder: (_, __) => const Scaffold(body: Text('symptoms screen')),
    ),
  ]);
  return ProviderScope(
    overrides: [locationGatewayProvider.overrideWithValue(gateway)],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the real pickup location and lets the patient continue',
      (tester) async {
    final gateway = _Gateway(fix: _at(31.5204, 74.3587, accuracy: 18));
    await tester.pumpWidget(_app(gateway));
    await _open(tester);

    expect(find.text('Using your current location'), findsOneWidget);
    expect(find.textContaining('18 m'), findsOneWidget);
    expect(find.textContaining('31.5204'), findsOneWidget);
    expect(find.textContaining('74.3587'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('symptoms screen'), findsOneWidget);
  });

  testWidgets('cancel closes the sheet without going anywhere', (tester) async {
    await tester.pumpWidget(_app(_Gateway(fix: _at(31.5, 74.3))));
    await _open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Using your current location'), findsNothing);
    expect(find.text('symptoms screen'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('Call 1122 is always available', (tester) async {
    var called = 0;
    await tester.pumpWidget(
      _app(_Gateway(fix: _at(31.5, 74.3)), onCall: () => called++),
    );
    await _open(tester);

    await tester.tap(find.text('Call 1122'));

    expect(called, 1);
  });

  testWidgets('without permission it asks, then shows the location',
      (tester) async {
    final gateway = _Gateway(
      permissionState: LocationPermission.denied,
      afterRequest: LocationPermission.whileInUse,
      fix: _at(33.0, 73.0),
    );
    await tester.pumpWidget(_app(gateway));
    await _open(tester);

    expect(gateway.requests, 1);
    expect(find.text('Using your current location'), findsOneWidget);
  });

  testWidgets('refused permission blocks Continue and offers a fix',
      (tester) async {
    final gateway = _Gateway(
      permissionState: LocationPermission.denied,
      afterRequest: LocationPermission.denied,
    );
    await tester.pumpWidget(_app(gateway));
    await _open(tester);

    expect(find.text('Using your current location'), findsNothing);
    expect(find.text('Turn on location'), findsOneWidget);
    final continueButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull);
    expect(find.text('Call 1122'), findsOneWidget);
  });

  testWidgets('permanently denied sends the patient to settings',
      (tester) async {
    final gateway = _Gateway(permissionState: LocationPermission.deniedForever);
    await tester.pumpWidget(_app(gateway));
    await _open(tester);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(gateway.settingsOpened, 1);
  });

  testWidgets('no fix yet offers a retry instead of inventing a location',
      (tester) async {
    final gateway = _Gateway(fix: null);
    await tester.pumpWidget(_app(gateway));
    await _open(tester);

    expect(find.text('We cannot find you yet'), findsOneWidget);
    expect(find.text('Using your current location'), findsNothing);

    gateway.fix = _at(33.1, 73.1);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Using your current location'), findsOneWidget);
  });

  testWidgets('services off is explained', (tester) async {
    final gateway = _Gateway(isServiceOn: false);
    await tester.pumpWidget(_app(gateway));
    await _open(tester);

    expect(find.textContaining('Location is switched off'), findsOneWidget);
    expect(find.text('Using your current location'), findsNothing);
  });

  testWidgets('never claims an ambulance is on the way', (tester) async {
    await tester.pumpWidget(_app(_Gateway(fix: _at(31.5, 74.3))));
    await _open(tester);

    expect(find.textContaining('on the way'), findsNothing);
    expect(find.textContaining('dispatched'), findsNothing);
  });

  testWidgets('fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_Gateway(fix: _at(31.5, 74.3))));
    await _open(tester);

    expect(tester.takeException(), isNull);
  });
}
