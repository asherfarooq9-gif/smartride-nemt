import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/apple_alert.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Shows the dialog and returns the future that completes when it closes.
Future<Future<bool?>> _open(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.light,
}) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    themeMode: mode,
    theme: ThemeData(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    home: Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: SizedBox());
    }),
  ));
  return showDialog<bool>(
    context: ctx,
    builder: (dialogContext) => AppleAlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You can sign in again any time.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: core.kError),
          child: const Text('Sign Out'),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('shows a centred title and message with the actions under them',
      (tester) async {
    await _open(tester);
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    expect(find.text('You can sign in again any time.'), findsOneWidget);
    final style = DefaultTextStyle.of(tester.element(find.text('Sign out?')));
    expect(style.textAlign, TextAlign.center);
    // Two actions sit side by side, like an iOS alert.
    final cancel = tester.getCenter(find.text('Cancel'));
    final signOut = tester.getCenter(find.text('Sign Out'));
    expect(cancel.dy, signOut.dy);
    expect(cancel.dx, isNot(signOut.dx));
  });

  testWidgets('an action closes the dialog with its value', (tester) async {
    final result = await _open(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect(find.text('Sign out?'), findsNothing);
  });

  testWidgets('three or more actions stack instead of squeezing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: c,
              builder: (_) => AppleAlertDialog(
                title: const Text('Choose'),
                actions: [
                  for (final n in ['One', 'Two', 'Three'])
                    TextButton(onPressed: () {}, child: Text(n)),
                ],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.getCenter(find.text('One')).dy,
        lessThan(tester.getCenter(find.text('Two')).dy));
    expect(tester.getCenter(find.text('Two')).dy,
        lessThan(tester.getCenter(find.text('Three')).dy));
  });

  testWidgets('renders in dark mode without errors', (tester) async {
    await _open(tester, mode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
