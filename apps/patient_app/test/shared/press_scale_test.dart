import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/press_scale.dart';

Widget _app({bool disableAnimations = false, VoidCallback? onTap}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: PressScale(
            onTap: onTap ?? () {},
            child: const SizedBox(width: 120, height: 60, child: Text('go')),
          ),
        ),
      ),
    ),
  );
}

double _scale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  testWidgets('shrinks a little while pressed and returns on release',
      (tester) async {
    await tester.pumpWidget(_app());
    expect(_scale(tester), 1);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('go')));
    await tester.pump();
    expect(_scale(tester), lessThan(1));
    expect(_scale(tester), greaterThan(0.9));

    await gesture.up();
    await tester.pump();
    expect(_scale(tester), 1);
  });

  testWidgets('still taps through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(onTap: () => taps++));

    await tester.tap(find.text('go'));

    expect(taps, 1);
  });

  testWidgets('does not animate when reduced motion is on', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('go')));
    await tester.pump();

    expect(_scale(tester), 1);
    await gesture.up();
  });

  testWidgets('a cancelled press returns to full size', (tester) async {
    await tester.pumpWidget(_app());

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('go')));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();

    expect(_scale(tester), 1);
  });
}
