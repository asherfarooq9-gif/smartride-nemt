import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/features/rides/home_sheet.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

class _FakeRides extends RidesNotifier {
  _FakeRides(this._build);
  final Future<core.RideListResponse> Function() _build;

  @override
  Future<core.RideListResponse> build() => _build();
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

core.RideResponse _ride(
  String id, {
  String status = 'completed',
  String address = 'F-7 Markaz, Islamabad',
}) =>
    core.RideResponse.fromJson({
      'id': id,
      'patient_id': 'p1',
      'ride_type': 'emergency',
      'status': status,
      'pickup_address': address,
      'pickup_lat': 33.7,
      'pickup_lng': 73.0,
      'requested_at': '2026-10-27T10:00:00Z',
    });

core.RideListResponse _list(List<core.RideResponse> items) =>
    core.RideListResponse(
      items: items,
      total: items.length,
      page: 1,
      pageSize: 10,
    );

Widget _app({
  Future<core.RideListResponse> Function()? rides,
  double textScale = 1,
  ThemeData? theme,
}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(
        body: Stack(
          children: [
            ColoredBox(color: Colors.blueGrey, child: SizedBox.expand()),
            HomeSheet(),
          ],
        ),
      ),
    ),
    for (final path in [
      '/book-ride',
      '/saved-places',
      '/rides',
      '/help',
      '/symptoms',
      '/ride/r1',
      '/ride/ride-active',
    ])
      GoRoute(
        path: path,
        builder: (_, __) => Scaffold(body: Text('opened $path')),
      ),
  ]);
  return ProviderScope(
    overrides: [
      locationGatewayProvider.overrideWithValue(_NoLocation()),
      ridesProvider.overrideWith(
        () => _FakeRides(rides ?? () async => _list(const [])),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: theme,
      // Keep the real screen size; only change motion and text scale.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          // No repeating SOS pulse, or pumpAndSettle would never finish.
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
}

/// A phone tall enough to show the whole sheet, since a ListView only builds
/// the rows that are on screen.
void _phone(WidgetTester tester, {Size size = const Size(412, 860)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder get _grabber => find.byKey(const ValueKey('sheet-grabber'));
Finder get _roundSos => find.byKey(const ValueKey('emergency-glow'));
Finder get _compactSos => find.byKey(const ValueKey('compact-emergency'));

Future<void> _dragSheet(WidgetTester tester, double dy) async {
  await tester.drag(_grabber, Offset(0, dy));
  await tester.pumpAndSettle();
}

void main() {
  group('layout in the reference design', () {
    testWidgets('greets with a wave and a reassuring line', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.textContaining('Good '), findsOneWidget);
      expect(find.text('👋'), findsOneWidget);
      expect(find.text("Stay safe. We're here for you."), findsOneWidget);
    });

    testWidgets('shows the round SOS, Book a Ride and three quick cards',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(_roundSos, findsOneWidget);
      expect(find.text('Book a Ride'), findsOneWidget);
      expect(find.text('Recent Rides'), findsOneWidget);
      expect(find.text('Saved places'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
    });

    testWidgets('Book a Ride opens the booking flow', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book a Ride'));
      await tester.pumpAndSettle();

      expect(find.text('opened /book-ride'), findsOneWidget);
    });

    for (final (card, route) in const [
      ('Recent Rides', '/rides'),
      ('Saved places', '/saved-places'),
      ('Help', '/help'),
    ]) {
      testWidgets('the $card card opens $route', (tester) async {
        _phone(tester);
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();

        await tester.tap(find.text(card));
        await tester.pumpAndSettle();

        expect(find.text('opened $route'), findsOneWidget);
      });
    }

    testWidgets('the SOS button opens the emergency confirmation',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(_roundSos);
      await tester.pumpAndSettle();

      expect(find.text('Request emergency help?'), findsOneWidget);
    });

    testWidgets('does not show a name it never loaded', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('there'), findsNothing);
    });
  });

  group('the three sheet positions', () {
    testWidgets('half open: full layout, round SOS', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(_roundSos, findsOneWidget);
      expect(_compactSos, findsNothing);
    });

    testWidgets('collapsed: only the essentials, with a compact SOS',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _dragSheet(tester, 700); // drag down

      expect(_compactSos, findsOneWidget);
      expect(_roundSos, findsNothing);
      expect(find.textContaining('Good '), findsOneWidget);
      expect(find.text('Book a Ride'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the compact SOS opens the same confirmation', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _dragSheet(tester, 700);

      await tester.tap(_compactSos);
      await tester.pumpAndSettle();

      expect(find.text('Request emergency help?'), findsOneWidget);
    });

    testWidgets('expanded: shows recent rides from the real list',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(rides: () async => _list([_ride('r1', address: 'G-9 Markaz')])),
      );
      await tester.pumpAndSettle();

      await _dragSheet(tester, -700); // drag up
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Your recent rides'), findsOneWidget);
      expect(find.text('G-9 Markaz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expanded with no rides says so instead of inventing any',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _dragSheet(tester, -700);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('No rides yet'), findsOneWidget);
    });

    testWidgets('expanded when rides fail to load offers a retry',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(rides: () async => throw StateError('offline')),
      );
      await tester.pumpAndSettle();

      await _dragSheet(tester, -700);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your rides"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('an active ride shows a banner that opens it', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          rides: () async =>
              _list([_ride('ride-active', status: 'driver_en_route')]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Ride'), findsOneWidget);
      await tester.tap(find.text('Active Ride'));
      await tester.pumpAndSettle();
      expect(find.text('opened /ride/ride-active'), findsOneWidget);
    });
  });

  group('responsive', () {
    for (final size in const [
      Size(320, 640),
      Size(412, 860),
      Size(768, 1024)
    ]) {
      for (final position in const ['collapsed', 'half', 'expanded']) {
        testWidgets(
            'no overflow at ${size.width.toInt()}x${size.height.toInt()}, '
            '$position, 1.3x text', (tester) async {
          _phone(tester, size: size);
          await tester.pumpWidget(
            _app(
              textScale: 1.3,
              rides: () async => _list([_ride('r1'), _ride('r2')]),
            ),
          );
          await tester.pumpAndSettle();

          if (position == 'collapsed') await _dragSheet(tester, 900);
          if (position == 'expanded') await _dragSheet(tester, -900);

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('dark mode', () {
    testWidgets('the sheet follows the dark theme', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(theme: core.AppTheme.patient(dark: true)));
      await tester.pumpAndSettle();

      final surface = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey('sheet-top')),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(surface.color, core.kDarkSurface);
    });

    testWidgets('the light theme keeps a white sheet', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(theme: core.AppTheme.patient()));
      await tester.pumpAndSettle();

      final surface = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey('sheet-top')),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(surface.color, core.kSurface);
    });
  });
}
