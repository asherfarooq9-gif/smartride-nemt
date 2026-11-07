import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/top_up_screen.dart';

Future<void> _openInstructions(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: TopUpScreen()));
  await tester.tap(find.text('Standard'));
  await tester.pump();
  await tester.tap(find.textContaining('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the screen never claims a payment was made', (tester) async {
    await _openInstructions(tester);

    expect(find.text('How to top up'), findsOneWidget);
    expect(find.text('Almost done'), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.textContaining('Nothing has been charged'), findsOneWidget);
  });

  testWidgets('it says where to send the receipt', (tester) async {
    await _openInstructions(tester);

    expect(find.textContaining('support@smartride.pk'), findsOneWidget);
    expect(find.textContaining('confirms the payment'), findsOneWidget);
  });
}
