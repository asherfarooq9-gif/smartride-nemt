import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/glass_surface.dart';

Widget _app({
  bool highContrast = false,
  bool blur = true,
  Brightness brightness = Brightness.light,
}) {
  return MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Stack(
          children: [
            Container(color: Colors.green),
            Center(
              child: GlassSurface(
                blur: blur,
                child: const Text('controls'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Color _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey('glass-fill')),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('blurs what is behind it and keeps the fill see-through',
      (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(_fill(tester).a, lessThan(1));
    expect(find.text('controls'), findsOneWidget);
  });

  testWidgets('goes solid in high-contrast mode so text stays readable',
      (tester) async {
    await tester.pumpWidget(_app(highContrast: true));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(_fill(tester).a, 1);
  });

  testWidgets('can be switched off for a cheaper solid surface',
      (tester) async {
    await tester.pumpWidget(_app(blur: false));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(_fill(tester).a, 1);
  });

  testWidgets('uses a dark fill in dark mode', (tester) async {
    await tester.pumpWidget(_app(brightness: Brightness.dark));

    expect(_fill(tester).computeLuminance(), lessThan(0.2));
  });
}
