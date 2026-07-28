import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/rides/schedule_submit_notifier.dart';
import 'package:patient_app/features/rides/schedule_trip_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

class _FakeScheduleSubmitNotifier extends ScheduleSubmitNotifier {
  ScheduleSubmitResult? nextResult;

  @override
  Future<ScheduleSubmitResult> submit({
    required String pickupAddress,
    required DateTime scheduledFor,
    String? dropoffAddress,
    double? dropoffLat,
    double? dropoffLng,
  }) async {
    state = const AsyncValue.loading();
    final result = nextResult ??
        const ScheduleSubmitSuccess(core.RideResponse(
          id: 'ride-1',
          status: core.RideStatus.pending,
          rideType: core.RideType.scheduled,
          pickupAddress: 'Test',
        ));
    state = const AsyncValue.data(null);
    return result;
  }
}

String? _routedRideId;
bool _popped = false;

// context.pop() in the screen needs a real back-stack entry, so the router
// starts at '/' and the test pushes '/schedule' on top of it — matching how
// the real app navigates here (pushed from another screen, not launched
// directly at this route).
(Widget, GoRouter) _buildUnderTest(_FakeScheduleSubmitNotifier notifier) {
  _routedRideId = null;
  _popped = false;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) {
          _popped = true;
          return const SizedBox();
        },
      ),
      GoRoute(path: '/schedule', builder: (_, __) => const ScheduleTripScreen()),
      GoRoute(
        path: '/booking-confirmed/:id',
        builder: (_, state) {
          _routedRideId = state.pathParameters['id'];
          return const SizedBox();
        },
      ),
    ],
  );
  final widget = ProviderScope(
    overrides: [scheduleSubmitProvider.overrideWith((ref) => notifier)],
    child: MaterialApp.router(routerConfig: router),
  );
  return (widget, router);
}

void main() {
  testWidgets('navigates to booking-confirmed with the new ride id on success',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifier = _FakeScheduleSubmitNotifier();
    final (widget, router) = _buildUnderTest(notifier);
    await tester.pumpWidget(widget);
    await tester.pump();
    router.push('/schedule');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _popped = false; // reset: the initial '/' render above is not a pop

    await tester.enterText(find.byType(TextFormField).first, '123 Test Street');
    await tester.pump();
    await tester.tap(find.text('Confirm Booking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_routedRideId, 'ride-1');
  });

  testWidgets('shows an offline snackbar and pops when queued offline',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifier = _FakeScheduleSubmitNotifier()
      ..nextResult = const ScheduleSubmitQueuedOffline();
    final (widget, router) = _buildUnderTest(notifier);
    await tester.pumpWidget(widget);
    await tester.pump();
    router.push('/schedule');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _popped = false; // reset: the initial '/' render above is not a pop

    await tester.enterText(find.byType(TextFormField).first, '123 Test Street');
    await tester.pump();
    await tester.tap(find.text('Confirm Booking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('offline'),
      findsOneWidget,
    );
    expect(_popped, isTrue);
    expect(_routedRideId, isNull);
  });

  testWidgets('shows an error snackbar with the AppError message on failure',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifier = _FakeScheduleSubmitNotifier()
      ..nextResult =
          const ScheduleSubmitFailed(core.AppError('Hospital not found'));
    final (widget, router) = _buildUnderTest(notifier);
    await tester.pumpWidget(widget);
    await tester.pump();
    router.push('/schedule');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _popped = false; // reset: the initial '/' render above is not a pop

    await tester.enterText(find.byType(TextFormField).first, '123 Test Street');
    await tester.pump();
    await tester.tap(find.text('Confirm Booking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hospital not found'), findsOneWidget);
    expect(_routedRideId, isNull);
    expect(_popped, isFalse);
  });
}
