import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/rides/emergency_button.dart';

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
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('tapping opens the symptom check and buzzes the phone',
      (tester) async {
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
    await tester.pumpWidget(_app());

    await tester.tap(find.bySemanticsLabel('Request emergency ride'));
    await tester.pumpAndSettle();

    expect(find.text('symptoms screen'), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
  });

  testWidgets(
      'the glow is a circle outside the ink, so it is never clipped '
      'to a square', (tester) async {
    await tester.pumpWidget(_app());

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

  testWidgets('the pulse ring only runs when animations are allowed',
      (tester) async {
    await tester.pumpWidget(_app());
    expect(find.byKey(const ValueKey('emergency-pulse')), findsOneWidget);

    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.pump();
    expect(find.byKey(const ValueKey('emergency-pulse')), findsNothing);
  });
}
