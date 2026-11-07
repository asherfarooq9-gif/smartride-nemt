import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/apple_list.dart';
import 'package:smartride_core/smartride_core.dart' as core;

Widget _app(Widget child, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
      themeMode: mode,
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: ListView(children: [child])),
    );

void main() {
  testWidgets('a section shows its header and a hairline between rows only',
      (tester) async {
    await tester.pumpWidget(_app(const AppleSection(
      header: 'Account',
      children: [
        AppleRow(title: 'One'),
        AppleRow(title: 'Two'),
        AppleRow(title: 'Three'),
      ],
    )));

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('a tappable row shows a chevron and reports taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(AppleSection(children: [
      AppleRow(title: 'Profile', onTap: () => taps++),
      const AppleRow(title: 'Version', value: '1.0.0'),
    ])));

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    expect(taps, 1);

    // Secondary text is the quiet iOS gray and the chevron is lighter still.
    final value = tester.widget<Text>(find.text('1.0.0'));
    expect(value.style?.color, core.kText400);
    expect(value.style?.fontWeight, FontWeight.w400);
    final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
    expect(chevron.color!.a, lessThan(0.7));
  });

  testWidgets('a destructive row is red and has a red icon tile',
      (tester) async {
    await tester.pumpWidget(_app(AppleSection(children: [
      AppleRow(
        title: 'Sign Out',
        icon: Icons.logout,
        destructive: true,
        onTap: () {},
      ),
    ])));

    final text = tester.widget<Text>(find.text('Sign Out'));
    expect(text.style?.color, core.kError);
    final tile = tester.widget<Container>(
      find.byKey(const ValueKey('apple-row-icon-tile')),
    );
    expect((tile.decoration as BoxDecoration).color, core.kError);
  });

  testWidgets('a destructive row uses the lighter red on dark surfaces',
      (tester) async {
    await tester.pumpWidget(_app(
      AppleSection(children: [
        AppleRow(title: 'Delete', destructive: true, onTap: () {}),
      ]),
      mode: ThemeMode.dark,
    ));

    final text = tester.widget<Text>(find.text('Delete'));
    expect(text.style?.color, core.kDarkRed);
  });

  testWidgets('a switch row toggles from the switch and from the row',
      (tester) async {
    final values = <bool>[];
    await tester.pumpWidget(_app(AppleSection(children: [
      AppleSwitchRow(
        title: 'Dark mode',
        icon: Icons.dark_mode_outlined,
        value: false,
        onChanged: values.add,
      ),
    ])));

    expect(find.byType(CupertinoSwitch), findsOneWidget);
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.tap(find.text('Dark mode'));
    expect(values, [true, true]);
  });

  testWidgets('the switch is the iOS green when on', (tester) async {
    await tester.pumpWidget(_app(AppleSection(children: [
      AppleSwitchRow(title: 'On', value: true, onChanged: (_) {}),
    ])));

    final sw = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
    expect(sw.activeTrackColor, core.kIosGreen);
  });

  testWidgets('renders in dark mode without errors', (tester) async {
    await tester.pumpWidget(_app(
      const AppleSection(header: 'Dark', children: [AppleRow(title: 'Row')]),
      mode: ThemeMode.dark,
    ));

    expect(find.text('Row'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
