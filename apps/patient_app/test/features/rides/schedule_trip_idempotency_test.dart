import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/location.dart';
import 'package:patient_app/features/rides/schedule_trip_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

Position _position(double lat) => Position(
      latitude: lat,
      longitude: 73.0,
      timestamp: DateTime(2026, 11, 5),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

core.RideResponse _ride() => core.RideResponse.fromJson({
      'id': 'ride-1',
      'patient_id': 'p',
      'ride_type': 'scheduled',
      'status': 'pending',
      'pickup_lat': 33.7,
      'pickup_lng': 73.0,
      'requested_at': '2026-11-05T10:00:00Z',
    });

class _Harness {
  _Harness({this.failuresBeforeSuccess = 0});

  final int failuresBeforeSuccess;
  final requests = <core.ScheduledRideRequest>[];
  final keys = <String?>[];
  var _lat = 33.70;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/schedule',
      routes: [
        GoRoute(
          path: '/schedule',
          builder: (_, __) => const ScheduleTripScreen(),
        ),
        GoRoute(
          path: '/booking-confirmed/:id',
          builder: (_, s) =>
              Scaffold(body: Text('confirmed ${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scheduleHospitalsProvider
            .overrideWith((_) async => <core.HospitalResponse>[]),
        // Each read moves the phone a little, like a real GPS between taps.
        locationReaderProvider.overrideWithValue(() async {
          _lat += 0.001;
          return _position(_lat);
        }),
        scheduledRideCreatorProvider
            .overrideWithValue((request, {String? idempotencyKey}) async {
          requests.add(request);
          keys.add(idempotencyKey);
          if (requests.length <= failuresBeforeSuccess) {
            throw const core.AppError('Connection lost');
          }
          return _ride();
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pickDateTime(WidgetTester tester) async {
    await tester.tap(find.text('Select date & time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.tap(find.text('Confirm Booking'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('a booking sends an Idempotency-Key', (tester) async {
    final h = _Harness();
    await h.pump(tester);

    await h.pickDateTime(tester);
    await h.confirm(tester);

    expect(h.keys, hasLength(1));
    expect(h.keys.single, isNotEmpty);
    expect(find.text('confirmed ride-1'), findsOneWidget);
  });

  testWidgets('a retry after a failure reuses the key and the pickup point',
      (tester) async {
    final h = _Harness(failuresBeforeSuccess: 1);
    await h.pump(tester);

    await h.pickDateTime(tester);
    await h.confirm(tester); // fails: the response was lost
    expect(find.text('Connection lost'), findsOneWidget);
    await h.confirm(tester); // the patient taps again

    expect(h.keys, hasLength(2));
    expect(h.keys[0], h.keys[1]);
    expect(h.requests[1].pickupLat, h.requests[0].pickupLat);
    expect(find.text('confirmed ride-1'), findsOneWidget);
  });

  testWidgets('changing the form starts a new booking with a new key',
      (tester) async {
    final h = _Harness(failuresBeforeSuccess: 1);
    await h.pump(tester);

    await h.pickDateTime(tester);
    await h.confirm(tester); // fails
    await tester.enterText(find.byType(TextFormField), 'F-8 Markaz');
    await h.confirm(tester);

    expect(h.keys, hasLength(2));
    expect(h.keys[0], isNot(h.keys[1]));
  });
}
