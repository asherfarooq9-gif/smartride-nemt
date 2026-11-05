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
  Future<void> deleteAccount(String password) async {
    calls.add('delete:$password');
    final failure = error;
    if (failure != null) throw failure;
  }
}

class _FakeGps extends GpsStreamNotifier {
  _FakeGps(this.calls);

  final List<String> calls;

  @override
  Future<void> stopStreaming() async => calls.add('stopStreaming');
}

Future<GoRouter> _pump(
  WidgetTester tester,
  List<String> calls, {
  bool isDriver = false,
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
        builder: (_, __) => SettingsScreen(isDriver: isDriver),
      ),
      for (final p in ['/welcome', '/login'])
        GoRoute(path: p, builder: (_, __) => Scaffold(body: Text('page:$p'))),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FakeAuth(ref, calls, error: error)),
        gpsStreamProvider.overrideWith((ref) => _FakeGps(calls)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ListTile, 'Delete Account'));
  await tester.pumpAndSettle();
}

Future<void> _typePasswordAndDelete(
    WidgetTester tester, String password) async {
  await tester.enterText(find.byType(TextField), password);
  await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('patient: the right password deletes and goes to /login',
      (tester) async {
    final calls = <String>[];
    final router = await _pump(tester, calls);

    await _openDialog(tester);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);
    await _typePasswordAndDelete(tester, 'pass1234');

    expect(calls, ['delete:pass1234']);
    expect(_location(router), '/login');
  });

  testWidgets('a wrong password is shown and nothing changes', (tester) async {
    final calls = <String>[];
    final router = await _pump(
      tester,
      calls,
      error: const core.AppError('Incorrect password', statusCode: 403),
    );

    await _openDialog(tester);
    await _typePasswordAndDelete(tester, 'nope');

    expect(find.text('Incorrect password'), findsOneWidget);
    expect(find.text('Delete account'), findsWidgets); // dialog still open
    expect(_location(router), '/settings');
  });

  testWidgets('an active ride message is shown inside the dialog',
      (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      calls,
      error: const core.AppError(
        'Finish or cancel your active ride before deleting your account.',
        statusCode: 409,
      ),
    );

    await _openDialog(tester);
    await _typePasswordAndDelete(tester, 'pass1234');

    expect(find.textContaining('active ride'), findsOneWidget);
  });

  testWidgets('an empty password asks for one and sends nothing',
      (tester) async {
    final calls = <String>[];
    await _pump(tester, calls);

    await _openDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your password to continue.'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('cancelling deletes nothing', (tester) async {
    final calls = <String>[];
    final router = await _pump(tester, calls);

    await _openDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(_location(router), '/settings');
  });

  testWidgets('driver: stops GPS after deleting, then goes to /welcome',
      (tester) async {
    final calls = <String>[];
    final router = await _pump(tester, calls, isDriver: true);

    await _openDialog(tester);
    await _typePasswordAndDelete(tester, 'pass1234');

    expect(calls, ['delete:pass1234', 'stopStreaming']);
    expect(_location(router), '/welcome');
  });
}
