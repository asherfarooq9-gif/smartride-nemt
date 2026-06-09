import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:patient_app/features/rides/scheduled_rides_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

// ---------------------------------------------------------------------------
// Fake notifier — controls what ridesProvider returns in each test
// ---------------------------------------------------------------------------

class _FakeRidesNotifier extends RidesNotifier {
  _FakeRidesNotifier(this._build);
  final Future<core.RideListResponse> Function() _build;

  @override
  Future<core.RideListResponse> build() => _build();

  @override
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_build);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

core.RideListResponse _emptyList() => const core.RideListResponse(
      items: [],
      total: 0,
      page: 1,
      pageSize: 10,
    );

core.RideListResponse _listWithRides() => const core.RideListResponse(
      items: [
        core.RideResponse(
          id: '1',
          status: core.RideStatus.pending,
          rideType: core.RideType.scheduled,
          pickupAddress: '123 Test Street, Islamabad',
        ),
        core.RideResponse(
          id: '2',
          status: core.RideStatus.completed,
          rideType: core.RideType.emergency,
          pickupAddress: '456 Emergency Ave',
        ),
      ],
      total: 2,
      page: 1,
      pageSize: 10,
    );

Widget _buildUnderTest({
  required Future<core.RideListResponse> Function() rides,
}) {
  final router = GoRouter(
    initialLocation: '/rides',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(
        path: '/rides',
        builder: (_, __) => const ScheduledRidesScreen(),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/ride/:id', builder: (_, __) => const SizedBox()),
    ],
  );

  return ProviderScope(
    overrides: [
      ridesProvider.overrideWith(() => _FakeRidesNotifier(rides)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ScheduledRidesScreen', () {
    testWidgets('shows loading state while fetching', (tester) async {
      // Completer keeps the future pending so loading state stays visible
      final completer = Completer<core.RideListResponse>();

      await tester.pumpWidget(
        _buildUnderTest(rides: () => completer.future),
      );
      await tester.pump(); // first frame — provider triggers build()

      expect(find.textContaining('Loading'), findsOneWidget);
    });

    testWidgets('shows ride list when data loads', (tester) async {
      await tester.pumpWidget(
        _buildUnderTest(rides: () async => _listWithRides()),
      );
      await tester.pumpAndSettle();

      expect(find.text('123 Test Street, Islamabad'), findsOneWidget);
      expect(find.text('456 Emergency Ave'), findsOneWidget);
      expect(find.text('Finding Driver'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('shows empty state when ride list is empty', (tester) async {
      await tester.pumpWidget(
        _buildUnderTest(rides: () async => _emptyList()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No rides yet.'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('shows error state when fetch fails', (tester) async {
      await tester.pumpWidget(
        _buildUnderTest(rides: () async => throw Exception('Network error')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('error state is scrollable for pull-to-refresh', (tester) async {
      await tester.pumpWidget(
        _buildUnderTest(rides: () async => throw Exception('oops')),
      );
      await tester.pumpAndSettle();

      // SingleChildScrollView must be present so RefreshIndicator can gesture
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('empty state is scrollable for pull-to-refresh', (tester) async {
      await tester.pumpWidget(
        _buildUnderTest(rides: () async => _emptyList()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('tapping a ride navigates to detail screen', (tester) async {
      await tester.pumpWidget(
        _buildUnderTest(rides: () async => _listWithRides()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('123 Test Street, Islamabad'));
      await tester.pumpAndSettle();

      // GoRouter navigated away from /rides to /ride/1
      expect(find.byType(ScheduledRidesScreen), findsNothing);
    });

    testWidgets('bottom nav tapping home navigates to /', (tester) async {
      await tester.pumpWidget(
        _buildUnderTest(rides: () async => _emptyList()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.byType(ScheduledRidesScreen), findsNothing);
    });

    testWidgets('emergency ride shows red emergency icon', (tester) async {
      await tester.pumpWidget(
        _buildUnderTest(rides: () async => _listWithRides()),
      );
      await tester.pumpAndSettle();

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(
        icons.any((i) => i.icon == Icons.emergency),
        isTrue,
      );
    });
  });
}
