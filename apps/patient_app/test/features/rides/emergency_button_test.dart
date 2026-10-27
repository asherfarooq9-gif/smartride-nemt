import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/features/rides/emergency_button.dart';

class _Gateway implements LocationGateway {
  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermission> permission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position?> position() async => Position(
        latitude: 31.5204,
        longitude: 74.3587,
        timestamp: DateTime(2026, 10, 27),
        accuracy: 15,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
  @override
  Future<void> openSettings() async {}
}

Widget _app({bool disableAnimations = false}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) =>
          const Scaffold(body: Center(child: EmergencyButton())),
    ),
    GoRoute(
      path: '/symptoms',
      builder: (_, __) => const Scaffold(body: Text('symptoms screen')),
    ),
  ]);
  return ProviderScope(
    overrides: [locationGatewayProvider.overrideWithValue(_Gateway())],
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  testWidgets(
      'tapping buzzes the phone and opens the confirmation, '
      'not the form directly', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_app(disableAnimations: true));

    await tester.tap(find.bySemanticsLabel('Request emergency ride'));
    await tester.pumpAndSettle();

    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
    expect(find.text('Request emergency help?'), findsOneWidget);
    expect(find.text('symptoms screen'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('symptoms screen'), findsOneWidget);
  });

  testWidgets('shows a warning icon, the word EMERGENCY and a hint',
      (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));

    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    expect(find.text('EMERGENCY'), findsOneWidget);
    expect(find.text('Tap for immediate help'), findsOneWidget);
  });

  testWidgets(
      'the glow is a circle outside the ink, so it is never clipped '
      'to a square', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));

    final glow = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('emergency-glow')),
    );
    final glowDecoration = glow.decoration as BoxDecoration;
    expect(glowDecoration.shape, BoxShape.circle);
    expect(glowDecoration.boxShadow, isNotEmpty);

    final ink = tester.widget<Ink>(find.byType(Ink));
    final inkDecoration = ink.decoration as BoxDecoration;
    expect(inkDecoration.boxShadow, isNull);
  });

  testWidgets('two soft rings pulse only when animations are allowed',
      (tester) async {
    final rings = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          (w.key! as ValueKey).value.toString().startsWith('emergency-pulse'),
    );
    await tester.pumpWidget(_app());
    expect(rings, findsNWidgets(2));

    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.pump();
    expect(rings, findsNothing);
  });

  testWidgets('presses in like a native control', (tester) async {
    await tester.pumpWidget(_app());

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('EMERGENCY')));
    await tester.pump(const Duration(milliseconds: 200));

    final scale = tester
        .widgetList<AnimatedScale>(find.byType(AnimatedScale))
        .map((w) => w.scale)
        .reduce((a, b) => a < b ? a : b);
    expect(scale, lessThan(1));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
