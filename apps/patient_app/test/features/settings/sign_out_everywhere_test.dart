import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/settings/settings_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

class _FakeAuth extends AuthNotifier {
  _FakeAuth(super.ref, this.calls, {this.error});

  final List<String> calls;
  final core.AppError? error;

  @override
  Future<void> signOutEverywhere() async {
    calls.add('signOutEverywhere');
    final failure = error;
    if (failure != null) throw failure;
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  List<String> calls, {
  core.AppError? error,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(isDriver: false),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('page:/login')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FakeAuth(ref, calls, error: error)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ListTile, 'Sign out of all devices'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signing out of all devices ends the session and leaves',
      (tester) async {
    final calls = <String>[];
    await _pump(tester, calls);

    await _confirm(tester);

    expect(calls, ['signOutEverywhere']);
    expect(find.text('page:/login'), findsOneWidget);
  });

  testWidgets('if the server cannot be reached the user stays signed in',
      (tester) async {
    final calls = <String>[];
    await _pump(tester, calls, error: const core.AppError('offline'));

    await _confirm(tester);

    expect(find.text('page:/login'), findsNothing);
    expect(find.textContaining('Could not sign out of all devices'),
        findsOneWidget);
  });

  testWidgets('cancelling does nothing', (tester) async {
    final calls = <String>[];
    await _pump(tester, calls);

    await tester.tap(find.widgetWithText(ListTile, 'Sign out of all devices'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
  });
}
