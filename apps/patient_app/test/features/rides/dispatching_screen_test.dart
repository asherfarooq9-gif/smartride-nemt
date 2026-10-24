import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/rides/dispatching_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

core.RideDetailResponse _ride(String status) => core.RideDetailResponse.fromJson({
      'id': 'r1',
      'ride_type': 'emergency',
      'status': status,
      'pickup_address': 'Here',
      'pickup_lat': 33.7,
      'pickup_lng': 73.0,
    });

const _interval = Duration(milliseconds: 20);

class _Navigation {
  final visited = <String>[];

  Future<void> pump(WidgetTester tester, RideLoader loader) async {
    Widget stub(String name) {
      visited.add(name);
      return Scaffold(body: Text(name));
    }

    final router = GoRouter(
      initialLocation: '/dispatching/r1',
      routes: [
        GoRoute(
          path: '/dispatching/:id',
          builder: (_, s) => DispatchingScreen(
            rideId: s.pathParameters['id']!,
            loadRide: loader,
            pollInterval: _interval,
          ),
        ),
        GoRoute(path: '/', builder: (_, __) => stub('home')),
        GoRoute(path: '/tracking/:id', builder: (_, __) => stub('tracking')),
        GoRoute(path: '/no-drivers', builder: (_, __) => stub('no-drivers')),
        GoRoute(path: '/ride/:id', builder: (_, __) => stub('detail')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }
}

void main() {
  testWidgets('a slow poll never overlaps the next one, so we navigate once',
      (tester) async {
    final nav = _Navigation();
    var calls = 0;
    final pending = Completer<core.RideDetailResponse>();
    await nav.pump(tester, (_) {
      calls++;
      return pending.future;
    });

    // Many intervals pass while the first request is still in flight.
    for (var i = 0; i < 10; i++) {
      await tester.pump(_interval);
    }
    expect(calls, 1);

    pending.complete(_ride('driver_assigned'));
    await tester.pump();
    await tester.pump(_interval * 5);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(nav.visited.where((v) => v == 'tracking'), hasLength(1));
  });

  for (final status in ['driver_en_route', 'patient_picked_up']) {
    testWidgets('$status leaves for live tracking', (tester) async {
      final nav = _Navigation();
      await nav.pump(tester, (_) async => _ride(status));
      await tester.pump(_interval);
      await tester.pumpAndSettle();
      expect(nav.visited, ['tracking']);
    });
  }

  testWidgets('a completed ride opens its detail instead of spinning forever',
      (tester) async {
    final nav = _Navigation();
    await nav.pump(tester, (_) async => _ride('completed'));
    await tester.pump(_interval);
    await tester.pumpAndSettle();
    expect(nav.visited, containsAll(['home', 'detail']));
    expect(nav.visited, isNot(contains('tracking')));
  });

  testWidgets('a cancelled ride shows the no-drivers screen', (tester) async {
    final nav = _Navigation();
    await nav.pump(tester, (_) async => _ride('cancelled'));
    await tester.pump(_interval);
    await tester.pumpAndSettle();
    expect(nav.visited, containsAll(['home', 'no-drivers']));
  });

  testWidgets('a pending ride keeps polling', (tester) async {
    final nav = _Navigation();
    var calls = 0;
    await nav.pump(tester, (_) async {
      calls++;
      return _ride('pending');
    });
    for (var i = 0; i < 6; i++) {
      await tester.pump(_interval);
    }
    expect(calls, greaterThan(2));
    expect(nav.visited, isEmpty);
    await tester.pumpWidget(const SizedBox()); // dispose, stop polling
  });

  testWidgets('a 403 stops polling and tells the patient to call 1122',
      (tester) async {
    final nav = _Navigation();
    var calls = 0;
    await nav.pump(tester, (_) async {
      calls++;
      throw const core.AppError('Forbidden', statusCode: 403);
    });
    await tester.pump(_interval);
    await tester.pump();
    final callsAfterFailure = calls;
    for (var i = 0; i < 6; i++) {
      await tester.pump(_interval);
    }

    expect(calls, callsAfterFailure);
    expect(find.textContaining('call 1122'), findsOneWidget);
  });

  testWidgets('transient network errors keep polling and eventually warn',
      (tester) async {
    final nav = _Navigation();
    var calls = 0;
    await nav.pump(tester, (_) async {
      calls++;
      throw const core.AppError('offline');
    });
    for (var i = 0; i < 12; i++) {
      await tester.pump(_interval);
    }

    expect(calls, greaterThanOrEqualTo(6));
    expect(find.textContaining('Connection lost'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
