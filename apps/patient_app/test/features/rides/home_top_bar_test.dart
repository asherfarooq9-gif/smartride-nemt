import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/rides/home_top_bar.dart';

Widget _app({
  List<String> roles = const ['patient'],
  List<AppNotification> notifications = const [],
  VoidCallback? onMenu,
}) {
  final controller = StreamController<AppNotification>();
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        // Placed in a Stack, as on the home screen, where it gets loose
        // constraints as tall as the screen.
        body: Stack(children: [HomeTopBar(onMenu: onMenu ?? () {})]),
      ),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const Scaffold(body: Text('notifications screen')),
    ),
  ]);
  return ProviderScope(
    overrides: [
      rolesProvider.overrideWith((ref) => roles),
      notificationsProvider.overrideWith((ref, portal) {
        addTearDown(controller.close);
        final notifier =
            NotificationsNotifier(portal, incoming: controller.stream);
        for (final n in notifications) {
          controller.add(n);
        }
        return notifier;
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

AppNotification _unread() => const AppNotification(
      id: 'n1',
      title: 'Driver assigned',
      body: 'Five minutes away',
      time: 'Just now',
      icon: Icons.directions_car_outlined,
    );

void main() {
  testWidgets('has a round menu button that opens the menu', (tester) async {
    var opened = false;
    await tester.pumpWidget(_app(onMenu: () => opened = true));
    await tester.pump();

    await tester.tap(find.byTooltip('Open menu'));

    expect(opened, isTrue);
  });

  testWidgets('the corners hold two round 48px buttons and nothing else',
      (tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pump();

    final menu = tester.getSize(find.byTooltip('Open menu'));
    final bell = tester.getSize(find.byTooltip('Notifications'));
    expect(menu, const Size(48, 48));
    expect(bell, const Size(48, 48));
    // A slim row, not a panel across the screen.
    expect(
        tester.getSize(find.byType(HomeTopBar)).height, lessThanOrEqualTo(80));
    expect(find.text('SmartRide'), findsNothing);
  });

  testWidgets('a single-role account has no portal switch', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(SegmentedButton<String>), findsNothing);
  });

  testWidgets('a patient and driver account can switch portals from the bar',
      (tester) async {
    await tester.pumpWidget(_app(roles: const ['patient', 'driver']));
    await tester.pump();

    final control = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(control.selected, {'patient'});
    expect(find.text('Patient'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
  });

  testWidgets('the bell flags unread notifications and opens them',
      (tester) async {
    await tester.pumpWidget(_app(notifications: [_unread()]));
    await tester.pump();
    await tester.pump();

    expect(
      find.byTooltip('Notifications, you have unread'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Notifications, you have unread'));
    await tester.pumpAndSettle();
    expect(find.text('notifications screen'), findsOneWidget);
  });

  testWidgets('has no unread flag when everything is read', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byTooltip('Notifications'), findsOneWidget);
  });
}
