import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/location.dart';
import 'package:patient_app/features/rides/symptom_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

Position _position() => Position(
      latitude: 33.7,
      longitude: 73.0,
      timestamp: DateTime(2026, 10, 23),
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
      'ride_type': 'emergency',
      'status': 'pending',
      'pickup_lat': 33.7,
      'pickup_lng': 73.0,
      'requested_at': '2026-10-23T10:00:00Z',
    });

class _Harness {
  final requests = <core.EmergencyRideRequest>[];
  final keys = <String?>[];
  final location = Completer<Position?>();

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/symptoms',
      routes: [
        GoRoute(path: '/symptoms', builder: (_, __) => const SymptomScreen()),
        GoRoute(
          path: '/dispatching/:id',
          builder: (_, s) =>
              Scaffold(body: Text('dispatching ${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        locationReaderProvider.overrideWithValue(() => location.future),
        emergencyRideCreatorProvider.overrideWithValue((request,
            {String? idempotencyKey}) async {
          requests.add(request);
          keys.add(idempotencyKey);
          return _ride();
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
  }
}

void main() {
  testWidgets('double tapping Send for Help submits exactly once',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);

    await tester.tap(find.text('Chest Pain'));
    await tester.pump();
    await tester.ensureVisible(find.text('Send for Help'));

    // First tap starts waiting for the location fix; the second arrives
    // before it completes and must be ignored.
    await tester.tap(find.text('Send for Help'));
    await tester.pump();
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'button must be disabled while busy');
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();

    h.location.complete(_position());
    await tester.pumpAndSettle();

    expect(h.requests, hasLength(1));
    expect(h.requests.single.symptomText, 'Chest Pain');
    expect(h.keys.single, isNotNull);
    expect(h.keys.single, isNotEmpty);
    expect(find.text('dispatching ride-1'), findsOneWidget);
  });

  testWidgets('nothing selected and no details: shows a message, sends nothing',
      (tester) async {
    final h = _Harness();
    await h.pump(tester);

    await tester.ensureVisible(find.text('Send for Help'));
    await tester.tap(find.text('Send for Help'));
    await tester.pump();

    expect(find.textContaining('Tell us what is happening'), findsOneWidget);
    expect(h.requests, isEmpty);
  });

  testWidgets('free-text details alone are enough to submit', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    h.location.complete(_position());

    await tester.enterText(find.byType(TextFormField).first, 'fell, bleeding');
    await tester.ensureVisible(find.text('Send for Help'));
    await tester.tap(find.text('Send for Help'));
    await tester.pumpAndSettle();

    expect(h.requests.single.symptomText, 'fell, bleeding');
  });
}
