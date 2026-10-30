import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/settings/settings_screen.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth(super.ref, this.calls);

  final List<String> calls;

  @override
  Future<void> signOut() async => calls.add('signOut');
}

class _FakeGps extends GpsStreamNotifier {
  _FakeGps(this.calls);

  final List<String> calls;

  @override
  Future<void> stopStreaming() async => calls.add('stopStreaming');
}

Widget _page(String path) => Scaffold(body: Text('page:$path'));

/// Pumps the settings screen for [isDriver] and returns the router so tests
/// can read the location after a tap.
Future<GoRouter> _pump(
  WidgetTester tester,
  List<String> calls, {
  required bool isDriver,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final start = isDriver ? '/driver/settings' : '/settings';
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: start,
        builder: (_, __) => SettingsScreen(isDriver: isDriver),
      ),
      for (final p in ['/profile', '/driver/profile', '/welcome', '/login'])
        GoRoute(path: p, builder: (_, __) => _page(p)),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FakeAuth(ref, calls)),
        gpsStreamProvider.overrideWith((ref) => _FakeGps(calls)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

// A pushed route is not reflected in routeInformationProvider, so read the
// top of the match stack.
String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

Future<void> _openSignOutDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ListTile, 'Sign Out'));
  await tester.pumpAndSettle();
}

void main() {
  group('patient', () {
    testWidgets('Profile opens /profile', (tester) async {
      final router = await _pump(tester, [], isDriver: false);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(_location(router), '/profile');
    });

    testWidgets('sign out signs out and goes to /login without touching GPS',
        (tester) async {
      final calls = <String>[];
      final router = await _pump(tester, calls, isDriver: false);

      await _openSignOutDialog(tester);
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(calls, ['signOut']);
      expect(_location(router), '/login');
    });
  });

  group('driver', () {
    testWidgets('Profile opens /driver/profile', (tester) async {
      final router = await _pump(tester, [], isDriver: true);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(_location(router), '/driver/profile');
    });

    testWidgets('sign out stops GPS first, then signs out, then /welcome',
        (tester) async {
      final calls = <String>[];
      final router = await _pump(tester, calls, isDriver: true);

      await _openSignOutDialog(tester);
      expect(
        find.text('This will stop GPS streaming and sign you out.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(calls, ['stopStreaming', 'signOut']);
      expect(_location(router), '/welcome');
    });
  });

  for (final isDriver in [false, true]) {
    testWidgets('cancelling sign out changes nothing (isDriver=$isDriver)',
        (tester) async {
      final calls = <String>[];
      final router = await _pump(tester, calls, isDriver: isDriver);
      final start = _location(router);

      await _openSignOutDialog(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(_location(router), start);
    });
  }
}
