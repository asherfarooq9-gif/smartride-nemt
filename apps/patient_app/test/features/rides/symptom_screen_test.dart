import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/rides/symptom_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

class _FakeSymptomSubmitNotifier extends SymptomSubmitNotifier {
  String? addressReceived;
  String? symptomsReceived;
  String? resultRideId;
  Object? failWith;

  @override
  Future<String?> submit({
    required String address,
    required String symptoms,
    double? lat,
    double? lng,
  }) async {
    addressReceived = address;
    symptomsReceived = symptoms;
    state = const AsyncValue.loading();
    if (failWith != null) {
      state = AsyncValue.error(failWith!, StackTrace.current);
      return null;
    }
    state = const AsyncValue.data(null);
    return resultRideId ?? 'ride-123';
  }
}

String? _routedRideId;

Widget _buildUnderTest(_FakeSymptomSubmitNotifier notifier) {
  _routedRideId = null;
  final router = GoRouter(
    initialLocation: '/symptoms',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/symptoms', builder: (_, __) => const SymptomScreen()),
      GoRoute(
        path: '/dispatching/:id',
        builder: (_, state) {
          _routedRideId = state.pathParameters['id'];
          return const SizedBox();
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [symptomSubmitProvider.overrideWith((ref) => notifier)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('submitting with no address falls back to "Current location"',
      (tester) async {
    final notifier = _FakeSymptomSubmitNotifier();
    await tester.pumpWidget(_buildUnderTest(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send for Help'));
    await tester.pumpAndSettle();

    expect(notifier.addressReceived, 'Current location');
  });

  testWidgets('selected symptom chips are joined into the symptom text',
      (tester) async {
    final notifier = _FakeSymptomSubmitNotifier();
    await tester.pumpWidget(_buildUnderTest(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chest Pain'));
    await tester.tap(find.text('Breathing Trouble'));
    await tester.tap(find.text('Send for Help'));
    await tester.pumpAndSettle();

    expect(notifier.symptomsReceived, 'Chest Pain, Breathing Trouble');
  });

  testWidgets('free-text details are appended to selected symptoms',
      (tester) async {
    final notifier = _FakeSymptomSubmitNotifier();
    await tester.pumpWidget(_buildUnderTest(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chest Pain'));
    await tester.enterText(find.byType(TextFormField).first, 'patient conscious');
    await tester.tap(find.text('Send for Help'));
    await tester.pumpAndSettle();

    expect(notifier.symptomsReceived, 'Chest Pain. patient conscious');
  });

  testWidgets('navigates to the dispatching screen with the new ride id on success',
      (tester) async {
    final notifier = _FakeSymptomSubmitNotifier()..resultRideId = 'ride-abc';
    await tester.pumpWidget(_buildUnderTest(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send for Help'));
    await tester.pumpAndSettle();

    expect(_routedRideId, 'ride-abc');
  });

  testWidgets('shows an error snackbar and does not navigate on failure',
      (tester) async {
    final notifier = _FakeSymptomSubmitNotifier()
      ..failWith = const core.AppError('Service unavailable');
    await tester.pumpWidget(_buildUnderTest(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send for Help'));
    await tester.pumpAndSettle();

    expect(find.text('Service unavailable'), findsOneWidget);
    expect(_routedRideId, isNull);
  });
}
