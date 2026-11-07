import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/rides/home_screen.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final _blankTile = MemoryImage(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
));

class _BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _blankTile;
}

class _FakeRides extends RidesNotifier {
  @override
  Future<core.RideListResponse> build() async => const core.RideListResponse(
        items: [],
        total: 0,
        page: 1,
        pageSize: 10,
      );
}

class _Gateway implements LocationGateway {
  _Gateway({this.permissionState = LocationPermission.whileInUse, this.fix});
  LocationPermission permissionState;
  Position? fix;
  int requests = 0;

  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermission> permission() async => permissionState;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permissionState;
  }

  @override
  Future<Position?> position() async => fix;
  @override
  Future<void> openSettings() async {}
}

Position _at(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 10, 27),
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

Widget _app(_Gateway gateway, {ThemeData? theme}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => HomeScreen(
        tileLayer: TileLayer(
          urlTemplate: 'blank/{z}/{x}/{y}.png',
          tileProvider: _BlankTiles(),
        ),
      ),
    ),
    for (final path in ['/rides', '/profile', '/notifications', '/book-ride'])
      GoRoute(
        path: path,
        builder: (_, __) => Scaffold(body: Text('opened $path')),
      ),
  ]);
  return ProviderScope(
    overrides: [
      locationGatewayProvider.overrideWithValue(gateway),
      ridesProvider.overrideWith(_FakeRides.new),
      rolesProvider.overrideWith((ref) => const ['patient']),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('has a map, round controls, the sheet and a floating tab bar',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_Gateway(fix: _at(31.5, 74.3))));
    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byTooltip('Open menu'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Centre on my location'), findsOneWidget);
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Book a Ride'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My Rides'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the real position on the map', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_Gateway(fix: _at(31.5204, 74.3587))));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('you-are-here')), findsOneWidget);
  });

  testWidgets('without permission there is no dot and a hint offers a fix',
      (tester) async {
    _phone(tester);
    final gateway = _Gateway(permissionState: LocationPermission.denied);
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('you-are-here')), findsNothing);
    expect(find.text('Turn on location'), findsOneWidget);
    expect(gateway.requests, 0, reason: 'opening home must not prompt');
  });

  testWidgets('the recenter button rides just above the sheet', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_Gateway(fix: _at(31.5, 74.3))));
    await tester.pumpAndSettle();

    final button = tester.getRect(find.byTooltip('Centre on my location'));
    final sheetTop = tester.getTopLeft(find.byKey(const ValueKey('sheet-top')));
    expect(button.bottom, lessThanOrEqualTo(sheetTop.dy));
    expect(sheetTop.dy - button.bottom, lessThan(40));

    // Drag the sheet up: the button follows it.
    await tester.drag(
      find.byKey(const ValueKey('sheet-grabber')),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byTooltip('Centre on my location'));
    expect(after.top, lessThan(button.top));
  });

  testWidgets('a drag in the exposed map area reaches the map, not the sheet',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_Gateway(fix: _at(31.5, 74.3))));
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(
      InteractiveFlag.hasDrag(map.options.interactionOptions.flags),
      isTrue,
    );

    final before = tester.getTopLeft(find.byKey(const ValueKey('sheet-top')));
    await tester.dragFrom(const Offset(200, 200), const Offset(0, 100));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byKey(const ValueKey('sheet-top')));

    expect(after, before);
  });

  testWidgets('tabs navigate', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_Gateway(fix: _at(31.5, 74.3))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Rides'));
    await tester.pumpAndSettle();

    expect(find.text('opened /rides'), findsOneWidget);
  });

  testWidgets('renders in dark mode without errors', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        _Gateway(fix: _at(31.5, 74.3)),
        theme: core.AppTheme.patient(dark: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
