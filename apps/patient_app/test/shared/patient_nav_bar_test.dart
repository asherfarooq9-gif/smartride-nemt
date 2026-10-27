import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/shared/patient_nav_bar.dart';

Widget _app({bool glass = false, int index = 0}) {
  final router = GoRouter(routes: [
    for (final path in ['/', '/rides', '/profile'])
      GoRoute(
        path: path,
        builder: (_, __) => Scaffold(
          body: Text('screen $path'),
          bottomNavigationBar: PatientNavBar(currentIndex: index, glass: glass),
        ),
      ),
  ]);
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('has Home, My Rides and Profile', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My Rides'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('tabs navigate to their screens', (tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('My Rides'));
    await tester.pumpAndSettle();
    expect(find.text('screen /rides'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('screen /profile'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('screen /'), findsOneWidget);
  });

  testWidgets('marks the current tab as selected', (tester) async {
    await tester.pumpWidget(_app(index: 1));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
  });

  testWidgets('the glass variant blurs and lets the bar be see-through',
      (tester) async {
    await tester.pumpWidget(_app(glass: true));

    expect(find.byType(BackdropFilter), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.backgroundColor, Colors.transparent);
  });

  testWidgets('the plain variant has no blur', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byType(BackdropFilter), findsNothing);
  });
}
