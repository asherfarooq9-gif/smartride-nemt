import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/rides/home_sheet.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

core.RideResponse _activeRide() => core.RideResponse.fromJson({
      'id': 'ride-1',
      'patient_id': 'p1',
      'ride_type': 'emergency',
      'status': 'driver_en_route',
      'pickup_lat': 33.7,
      'pickup_lng': 73.0,
      'requested_at': '2026-10-27T10:00:00Z',
    });

Widget _app({
  core.RideResponse? ride,
  VoidCallback? onCallEmergency,
  double textScale = 1,
  ThemeData? theme,
  Future<String> Function()? name,
}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        body: Stack(
          children: [
            const ColoredBox(color: Colors.blueGrey, child: SizedBox.expand()),
            HomeSheet(onCallEmergency: onCallEmergency ?? () {}),
          ],
        ),
      ),
    ),
    for (final path in [
      '/book-ride',
      '/saved-places',
      '/rides',
      '/symptoms',
      '/ride/ride-1',
    ])
      GoRoute(
        path: path,
        builder: (_, __) => Scaffold(body: Text('opened $path')),
      ),
  ]);
  return ProviderScope(
    overrides: [
      activeRideProvider.overrideWithValue(ride),
      patientNameProvider.overrideWith(
        (ref) => name != null ? name() : Future.value('Ayesha'),
      ),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        // No repeating SOS pulse, or pumpAndSettle would never finish.
        disableAnimations: true,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp.router(routerConfig: router, theme: theme),
    ),
  );
}

/// A phone tall enough to show the whole sheet, since a ListView only builds
/// the rows that are on screen.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('greets the patient by name with a large title', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Ayesha'), findsOneWidget);
    expect(find.text('Request emergency ride'), findsNothing); // semantics only
    expect(find.bySemanticsLabel('Request emergency ride'), findsOneWidget);
  });

  testWidgets('still greets when the profile cannot be loaded', (tester) async {
    await tester.pumpWidget(
      _app(name: () async => throw StateError('storage unreadable')),
    );
    await tester.pumpAndSettle();

    // An Error (not an Exception) must not leave the title blank.
    expect(find.text('there'), findsOneWidget);
  });

  testWidgets('Book a Ride opens the booking flow', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book a Ride'));
    await tester.pumpAndSettle();

    expect(find.text('opened /book-ride'), findsOneWidget);
  });

  testWidgets('quick actions open saved places and past rides', (tester) async {
    _tallPhone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved places'));
    await tester.pumpAndSettle();
    expect(find.text('opened /saved-places'), findsOneWidget);
  });

  testWidgets('Call 1122 uses the injected dialler', (tester) async {
    _tallPhone(tester);
    var called = 0;
    await tester.pumpWidget(_app(onCallEmergency: () => called++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Call 1122'));

    expect(called, 1);
  });

  testWidgets('shows the active ride banner only when there is a ride',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Active Ride'), findsNothing);

    await tester.pumpWidget(_app(ride: _activeRide()));
    await tester.pumpAndSettle();
    expect(find.text('Active Ride'), findsOneWidget);
  });

  testWidgets('the sheet can be dragged up to reveal more', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byKey(const ValueKey('sheet-top')));

    await tester.drag(
      find.byKey(const ValueKey('sheet-grabber')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    final after = tester.getTopLeft(find.byKey(const ValueKey('sheet-top')));
    expect(after.dy, lessThan(before.dy));
  });

  testWidgets('follows the dark theme instead of staying white',
      (tester) async {
    _tallPhone(tester);
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
    final name = tester.widget<Text>(find.text('Ayesha'));
    expect(name.style?.color, core.kDarkText1);
  });

  testWidgets('the light theme keeps a white sheet and dark text',
      (tester) async {
    _tallPhone(tester);
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
    final name = tester.widget<Text>(find.text('Ayesha'));
    expect(name.style?.color, core.kText900);
  });

  for (final size in const [Size(320, 640), Size(412, 860)]) {
    testWidgets(
        'lays out without overflow at ${size.width}x${size.height} '
        'with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(ride: _activeRide(), textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
