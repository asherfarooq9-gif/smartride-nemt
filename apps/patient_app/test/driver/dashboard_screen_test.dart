import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:patient_app/driver/dashboard_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// A 1x1 transparent PNG, so tests never touch the network.
final _blankTile = MemoryImage(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
));

class _BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _blankTile;
}

class _NoLocation implements LocationGateway {
  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermission> permission() async => LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
  @override
  Future<Position?> position() async => null;
  @override
  Future<void> openSettings() async {}
}

/// A dashboard with a fixed state that records what the screen asks of it.
class _FakeDashboard extends DashboardNotifier {
  _FakeDashboard(super.ref, DashboardState initial) {
    state = initial;
  }

  int toggles = 0;
  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> toggleOnline() async => toggles++;
}

core.DriverResponse _driver({
  core.DriverStatus status = core.DriverStatus.available,
  bool isVerified = true,
  double? rating = 4.8,
  double wallet = 1250,
  String name = 'Asher Khan',
}) =>
    core.DriverResponse(
      id: 'd1',
      phone: '+923001234567',
      status: status,
      fullName: name,
      rating: rating,
      isVerified: isVerified,
      walletBalancePkr: wallet,
    );

core.RideResponse _pendingRide(String id, String address) =>
    core.RideResponse.fromJson({
      'id': id,
      'patient_id': 'p1',
      'ride_type': 'scheduled',
      'status': 'pending',
      'pickup_address': address,
      'pickup_lat': 33.7,
      'pickup_lng': 73.0,
      'requested_at': '2026-10-27T10:00:00Z',
    });

late _FakeDashboard _fake;

Future<void> _show(
  WidgetTester tester,
  DashboardState state, {
  Size size = const Size(393, 852),
  double textScale = 1,
  bool open = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => DashboardScreen(
        tileLayer: TileLayer(
          urlTemplate: 'blank/{z}/{x}/{y}.png',
          tileProvider: _BlankTiles(),
        ),
      ),
    ),
    for (final path in [
      '/driver/earnings',
      '/driver/demand',
      '/driver/history',
      '/driver/wallet',
      '/driver/settings',
      '/driver/profile',
      '/driver/notifications',
    ])
      GoRoute(
        path: path,
        builder: (_, __) => Scaffold(body: Text('opened $path')),
      ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      locationGatewayProvider.overrideWithValue(_NoLocation()),
      rolesProvider.overrideWith((ref) => const ['driver']),
      activeRoleProvider.overrideWith((ref) => 'driver'),
      notificationsProvider.overrideWith(
        (ref, portal) =>
            NotificationsNotifier(portal, incoming: const Stream.empty()),
      ),
      dashboardProvider.overrideWith((ref) {
        _fake = _FakeDashboard(ref, state);
        return _fake;
      }),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          // No repeating animations, or pumpAndSettle would never finish.
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  ));
  // A spinner animates forever, so those states only get a few frames.
  Future<void> wait() => settle
      ? tester.pumpAndSettle()
      : tester.pump(const Duration(milliseconds: 400));
  await wait();
  if (open) {
    // Open the sheet fully: a ListView only builds what is on screen.
    await tester.drag(
      find.byKey(const ValueKey('driver-sheet')),
      const Offset(0, -700),
    );
    await wait();
  }
}

/// Scrolls the sheet until [target] is on screen.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('driver-sheet')),
      matching: find.byType(Scrollable),
    ),
  );
  // Clear of the floating tab bar, which covers the bottom of the sheet.
  await tester.drag(
    find.byKey(const ValueKey('driver-sheet')),
    const Offset(0, -120),
  );
  await tester.pumpAndSettle();
}

/// The account has not loaded: still asking, or the request failed.
DashboardState _noAccount({bool isLoading = false, String? error}) =>
    DashboardState(isLoading: isLoading, error: error);

DashboardState _state({
  core.DriverResponse? driver,
  List<core.RideResponse> rides = const [],
  double earnings = 2340,
  bool isUpdatingStatus = false,
  bool isLoading = false,
  String? error,
}) =>
    DashboardState(
      driver: driver ?? _driver(),
      pendingRides: rides,
      todayEarningsPkr: earnings,
      isUpdatingStatus: isUpdatingStatus,
      isLoading: isLoading,
      error: error,
    );

void main() {
  group('an online, verified driver sees the real figures', () {
    testWidgets('home is minimal: greeting, availability and requests only',
        (tester) async {
      await _show(tester, _state());

      expect(find.textContaining('Asher Khan'), findsOneWidget);
      expect(find.text("Stay safe. You're on the road."), findsOneWidget);
      expect(find.text("You're Online"), findsOneWidget);
      expect(find.text('Go Offline'), findsOneWidget);
      expect(find.text('Verification pending'), findsNothing);
      // Moved to the sidebar: none of these crowd the home screen any more.
      expect(find.text("Today's Earnings"), findsNothing);
      expect(find.text('Wallet Balance'), findsNothing);
      expect(find.text('Busiest around'), findsNothing);
    });

    testWidgets('there is no bottom tab bar', (tester) async {
      await _show(tester, _state());

      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the wallet turns red and says so when the balance is low',
        (tester) async {
      await _show(tester, _state(driver: _driver(wallet: 120)));

      expect(find.text('Low balance'), findsOneWidget);
      expect(find.text('PKR 120'), findsOneWidget);
    });
  });

  group('verification', () {
    testWidgets('an unverified driver is told why they cannot go online',
        (tester) async {
      await _show(
        tester,
        _state(
          driver: _driver(
            status: core.DriverStatus.offline,
            isVerified: false,
          ),
        ),
      );

      expect(find.text('Verification pending'), findsOneWidget);
      expect(find.text("You're Offline"), findsOneWidget);
    });

    testWidgets('neither Online control sends a request for them',
        (tester) async {
      await _show(
        tester,
        _state(
          driver: _driver(
            status: core.DriverStatus.offline,
            isVerified: false,
          ),
        ),
      );

      await _reveal(tester, find.text('Go Online'));
      await tester.tap(find.text('Go Online'));
      await tester.pump();
      expect(find.textContaining('verified'), findsWidgets);
      expect(_fake.toggles, 0);

      final switchWidget =
          tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
      expect(switchWidget.onChanged, isNull, reason: 'the switch is locked');
      expect(switchWidget.value, isFalse);
    });

    testWidgets('a verified driver is never shown the notice', (tester) async {
      await _show(tester, _state());
      expect(find.text('Verification pending'), findsNothing);
    });
  });

  group('going online and offline', () {
    testWidgets('Go Online asks once and the card shows the server state',
        (tester) async {
      await _show(
        tester,
        _state(driver: _driver(status: core.DriverStatus.offline)),
      );

      expect(find.text("You're Offline"), findsOneWidget);
      await tester.tap(find.text('Go Online'));
      await tester.pump();

      expect(_fake.toggles, 1);
      // The state shown is still the confirmed one; only the server changes it.
      expect(find.text("You're Offline"), findsOneWidget);
    });

    testWidgets('the switch and the button do the same thing', (tester) async {
      await _show(
        tester,
        _state(driver: _driver(status: core.DriverStatus.offline)),
      );

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pump();

      expect(_fake.toggles, 1);
    });

    testWidgets('a verified driver can go offline', (tester) async {
      await _show(tester, _state());

      await tester.tap(find.text('Go Offline'));
      await tester.pump();

      expect(_fake.toggles, 1);
    });

    testWidgets(
        'while a request is in flight both controls show progress and '
        'ignore taps', (tester) async {
      await _show(tester, _state(isUpdatingStatus: true), settle: false);
      // The Go Online button is further down the sheet.
      await tester.drag(
        find.byKey(const ValueKey('driver-sheet')),
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      expect(find.byType(CupertinoSwitch), findsNothing);
      await tester.tap(find.byType(CircularProgressIndicator).last);
      await tester.pump();
      expect(_fake.toggles, 0);
    });
  });

  group('ride requests', () {
    testWidgets('shows the empty state while online with none', (tester) async {
      await _show(tester, _state());

      expect(find.text('No ride requests right now'), findsOneWidget);
      expect(find.text('New requests will appear here.'), findsOneWidget);
    });

    testWidgets('lists the requests the server sent', (tester) async {
      await _show(
        tester,
        _state(rides: [_pendingRide('r1', 'F-7 Markaz, Islamabad')]),
        size: const Size(393, 852),
      );

      expect(find.text('F-7 Markaz, Islamabad'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('No ride requests right now'), findsNothing);
    });

    testWidgets('an offline driver is not shown a request list',
        (tester) async {
      await _show(
        tester,
        _state(
          driver: _driver(status: core.DriverStatus.offline),
          rides: [_pendingRide('r1', 'F-7 Markaz, Islamabad')],
        ),
      );

      expect(find.text('F-7 Markaz, Islamabad'), findsNothing);
      expect(find.text('No ride requests right now'), findsNothing);
    });

    testWidgets('a load failure says why and offers Try again', (tester) async {
      await _show(tester, _state(error: 'Failed to load'));

      await _reveal(tester, find.text('Try again'));
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('Failed to load'), findsOneWidget);
      final before = _fake.refreshes;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(_fake.refreshes, before + 1);
    });

    testWidgets('shows a loading card on the very first load', (tester) async {
      await _show(
        tester,
        const DashboardState(isLoading: true),
        settle: false,
      );

      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Verification pending'), findsNothing);
    });
  });

  group('the sidebar', () {
    Future<void> openDrawer(WidgetTester tester) async {
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
    }

    testWidgets('lists the driver sections', (tester) async {
      await _show(tester, _state());
      await openDrawer(tester);

      for (final title in [
        'Earnings',
        'Demand Forecast',
        'Wallet',
        'Ride History',
        'Profile',
        'Settings',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('each entry opens its screen', (tester) async {
      for (final (title, path) in const [
        ('Earnings', '/driver/earnings'),
        ('Demand Forecast', '/driver/demand'),
        ('Wallet', '/driver/wallet'),
        ('Settings', '/driver/settings'),
      ]) {
        await _show(tester, _state());
        await openDrawer(tester);
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.text('opened $path'), findsOneWidget, reason: title);
      }
    });

    testWidgets('Top Up on the low-balance card opens the wallet',
        (tester) async {
      await _show(tester, _state(driver: _driver(wallet: 120)));

      await tester.tap(find.text('Top Up'));
      await tester.pumpAndSettle();

      expect(find.text('opened /driver/wallet'), findsOneWidget);
    });
  });

  group('an account that has not loaded', () {
    testWidgets('while genuinely loading it says so and shows no figures',
        (tester) async {
      await _show(tester, _noAccount(isLoading: true), settle: false);

      expect(find.text('Checking your status'), findsOneWidget);
      expect(find.text('Loading your account'), findsOneWidget);
      expect(find.text("You're Offline"), findsNothing);
      expect(find.text('PKR 0'), findsNothing, reason: 'nothing is made up');
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('after a failure it shows the error, a retry, and no spinner',
        (tester) async {
      await _show(
        tester,
        _noAccount(error: 'No internet connection'),
      );

      expect(find.text('Could not load your account'), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Status unavailable'), findsOneWidget);
      expect(find.text("You're Offline"), findsNothing,
          reason: 'a failed request is not an offline driver');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('PKR 0'), findsNothing);

      final before = _fake.refreshes;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(_fake.refreshes, before + 1);
    });

    testWidgets('Online stays locked, and a tap explains why', (tester) async {
      await _show(tester, _noAccount(error: 'No internet connection'));

      await _reveal(tester, find.text('Go Online'));
      await tester.tap(find.text('Go Online'));
      await tester.pump();

      expect(find.text('Your account could not be loaded'), findsWidgets);
      expect(_fake.toggles, 0);
    });
  });

  group('the sheet', () {
    for (final size in const [
      Size(360, 800),
      Size(393, 852),
      Size(430, 932),
    ]) {
      testWidgets(
          'stays on screen at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await _show(
          tester,
          _state(driver: _driver(status: core.DriverStatus.offline)),
          size: size,
          open: false,
        );

        final sheet =
            tester.getRect(find.byKey(const ValueKey('driver-sheet')));
        expect(sheet.bottom, lessThanOrEqualTo(size.height));
      });
    }

    testWidgets('Go Online is on screen and can be tapped', (tester) async {
      await _show(
        tester,
        _state(driver: _driver(status: core.DriverStatus.offline)),
        size: const Size(393, 852),
        open: false,
      );

      expect(tester.getRect(find.text('Go Online')).bottom, lessThan(852));

      await tester.tap(find.text('Go Online'));
      await tester.pump();
      expect(_fake.toggles, 1);
    });
  });

  group('layout', () {
    for (final (size, scale) in const [
      (Size(360, 800), 1.0),
      (Size(393, 852), 1.0),
      (Size(430, 932), 1.0),
      (Size(360, 800), 1.3),
      (Size(393, 852), 1.5),
    ]) {
      testWidgets(
          'no overflow at ${size.width.toInt()}x${size.height.toInt()}, '
          '${scale}x text, resting and open', (tester) async {
        await _show(
          tester,
          _state(rides: [_pendingRide('r1', 'F-7 Markaz, Islamabad')]),
          size: size,
          textScale: scale,
          open: false,
        );
        expect(tester.takeException(), isNull);

        await tester.drag(
          find.byKey(const ValueKey('driver-sheet')),
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the greeting is on screen', (tester) async {
      await _show(tester, _state(), open: false);

      final greeting = tester.getRect(find.textContaining('Asher Khan'));
      expect(greeting.bottom, lessThanOrEqualTo(852));
    });
  });
}
