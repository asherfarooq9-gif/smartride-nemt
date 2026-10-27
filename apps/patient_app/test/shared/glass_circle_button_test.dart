import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/glass_circle_button.dart';

Widget _app({VoidCallback? onPressed, bool hasBadge = false}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: GlassCircleButton(
            tooltip: 'Open menu',
            icon: Icons.menu_rounded,
            onPressed: onPressed ?? () {},
            hasBadge: hasBadge,
          ),
        ),
      ),
    );

void main() {
  testWidgets('is a 48px round control with a tooltip and screen-reader label',
      (tester) async {
    await tester.pumpWidget(_app());

    expect(tester.getSize(find.byTooltip('Open menu')), const Size(48, 48));
    expect(find.bySemanticsLabel('Open menu'), findsOneWidget);
  });

  testWidgets('taps through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(onPressed: () => taps++));

    await tester.tap(find.byTooltip('Open menu'));

    expect(taps, 1);
  });

  testWidgets('shows a badge dot only when asked', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.byKey(const ValueKey('glass-badge')), findsNothing);

    await tester.pumpWidget(_app(hasBadge: true));
    expect(find.byKey(const ValueKey('glass-badge')), findsOneWidget);
  });
}
