import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/glass_segmented_control.dart';

Widget _app({
  required String selected,
  required ValueChanged<String> onChanged,
  bool reduceMotion = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: GlassSegmentedControl<String>(
            segments: const [
              GlassSegment(value: 'a', label: 'Patient'),
              GlassSegment(value: 'b', label: 'Driver'),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('reports a tap on the other segment', (tester) async {
    String? picked;
    await tester.pumpWidget(_app(selected: 'a', onChanged: (v) => picked = v));

    await tester.tap(find.text('Driver'));

    expect(picked, 'b');
  });

  testWidgets('tapping the segment that is already chosen does nothing',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(selected: 'a', onChanged: (_) => calls++));

    await tester.tap(find.text('Patient'));

    expect(calls, 0);
  });

  testWidgets('the thumb slides to the chosen segment', (tester) async {
    await tester.pumpWidget(_app(selected: 'a', onChanged: (_) {}));
    final thumb = find.byKey(const ValueKey('segment-thumb'));
    final left = tester.getCenter(thumb).dx;

    await tester.pumpWidget(_app(selected: 'b', onChanged: (_) {}));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getCenter(thumb).dx, greaterThan(left)); // on its way
    await tester.pumpAndSettle();

    final track = tester.getRect(find.byType(GlassSegmentedControl<String>));
    expect(tester.getCenter(thumb).dx, greaterThan(track.center.dx));
  });

  testWidgets('moves at once when animations are turned off', (tester) async {
    await tester
        .pumpWidget(_app(selected: 'a', onChanged: (_) {}, reduceMotion: true));
    await tester
        .pumpWidget(_app(selected: 'b', onChanged: (_) {}, reduceMotion: true));
    await tester.pump();

    final track = tester.getRect(find.byType(GlassSegmentedControl<String>));
    expect(tester.getCenter(find.byKey(const ValueKey('segment-thumb'))).dx,
        greaterThan(track.center.dx));
  });

  testWidgets('each segment is at least a 44px tap target and is labelled',
      (tester) async {
    await tester.pumpWidget(_app(selected: 'a', onChanged: (_) {}));

    final size = tester.getSize(find.bySemanticsLabel('Driver'));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
  });
}
