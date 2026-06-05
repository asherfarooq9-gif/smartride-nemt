import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/features/support/support_screen.dart';

void main() {
  group('HelpScreen', () {
    testWidgets('shows the emergency banner and FAQ questions', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));

      expect(find.textContaining('call 1122'), findsOneWidget);
      expect(find.text('How do I request an emergency ride?'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsWidgets);
    });

    testWidgets('expands an FAQ to reveal its answer', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));

      await tester.tap(find.text('Can I track my driver?'));
      await tester.pumpAndSettle();

      expect(find.textContaining('live location on the map'), findsOneWidget);
    });
  });

  group('ContactScreen', () {
    testWidgets('lists the emergency and support contacts', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContactScreen()));

      expect(find.text('1122'), findsOneWidget);
      expect(find.text('support@smartride.pk'), findsOneWidget);
    });

    testWidgets('copying a contact shows a confirmation snackbar',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContactScreen()));

      await tester.tap(find.text('support@smartride.pk'));
      await tester.pump(); // let the SnackBar appear

      expect(find.textContaining('copied'), findsOneWidget);
    });
  });
}
