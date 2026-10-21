import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/location.dart';
import 'package:patient_app/features/rides/symptom_screen.dart';

/// The backend rejects an emergency ride without coordinates (422), so the
/// screen must obtain them first and explain what is wrong if it cannot.
void main() {
  testWidgets('without a location fix it asks for location instead of sending',
      (tester) async {
    var requestedPermissionScreen = false;
    final router = GoRouter(
      initialLocation: '/symptoms',
      routes: [
        GoRoute(path: '/symptoms', builder: (_, __) => const SymptomScreen()),
        GoRoute(
          path: '/permissions',
          builder: (_, __) {
            requestedPermissionScreen = true;
            return const Scaffold(body: Text('permissions screen'));
          },
        ),
        GoRoute(
          path: '/dispatching/:id',
          builder: (_, __) => const Scaffold(body: Text('dispatching')),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        locationReaderProvider.overrideWithValue(() async => null),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));

    await tester.ensureVisible(find.text('Send for Help'));
    await tester.tap(find.text('Send for Help'));
    await tester.pumpAndSettle();

    expect(find.textContaining('location'), findsWidgets);
    expect(find.text('dispatching'), findsNothing);

    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
    expect(requestedPermissionScreen, isTrue);
  });
}
