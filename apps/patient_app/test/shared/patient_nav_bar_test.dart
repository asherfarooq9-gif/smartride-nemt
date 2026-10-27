import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/shared/glass_surface.dart';
import 'package:patient_app/shared/patient_nav_bar.dart';

/// Each screen passes its own tab index, like the real screens do. [index]
/// forces one for tests that look at a single screen.
Widget _app({bool glass = false, int? index}) {
  const paths = ['/', '/rides', '/profile'];
  final router = GoRouter(routes: [
    for (var i = 0; i < paths.length; i++)
      GoRoute(
        path: paths[i],
        builder: (_, __) => Scaffold(
          body: Text('screen ${paths[i]}'),
          bottomNavigationBar:
              PatientNavBar(currentIndex: index ?? i, glass: glass),
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

  testWidgets('the glass variant floats with a margin and rounded corners',
      (tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(glass: true));

    final bar = tester.getRect(find.byType(GlassSurface));
    expect(bar.left, greaterThanOrEqualTo(12));
    expect(412 - bar.right, greaterThanOrEqualTo(12));
    expect(860 - bar.bottom, greaterThanOrEqualTo(4));

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('glass-fill')),
    );
    final radius =
        (surface.decoration as BoxDecoration).borderRadius! as BorderRadius;
    expect(radius.topLeft.x, greaterThanOrEqualTo(24));
    expect(radius.bottomLeft.x, greaterThanOrEqualTo(24));
  });

  testWidgets('changing tab gives a light haptic tick', (tester) async {
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

    await tester.tap(find.text('My Rides'));
    await tester.pumpAndSettle();

    expect(haptics, contains('HapticFeedbackType.selectionClick'));
  });

  testWidgets('the plain variant has no blur', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byType(BackdropFilter), findsNothing);
  });
}
