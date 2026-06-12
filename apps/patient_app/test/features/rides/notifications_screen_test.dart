import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/rides/notifications_screen.dart';

AppNotification _notif(String id, {bool isRead = false}) => AppNotification(
      id: id,
      title: 'Driver assigned',
      body: 'Your driver is 5 minutes away',
      time: 'Just now',
      icon: Icons.directions_car_outlined,
      isRead: isRead,
    );

Widget _harness({
  required StreamController<AppNotification> controller,
  String portal = 'patient',
}) {
  return ProviderScope(
    overrides: [
      notificationsProvider.overrideWith(
        (ref, p) => NotificationsNotifier(p, incoming: controller.stream),
      ),
    ],
    child: MaterialApp(home: NotificationsScreen(portal: portal)),
  );
}

void main() {
  group('NotificationsScreen', () {
    testWidgets('shows empty state when there are no notifications',
        (tester) async {
      final controller = StreamController<AppNotification>();
      addTearDown(controller.close);

      await tester.pumpWidget(_harness(controller: controller));
      await tester.pumpAndSettle();

      expect(find.textContaining('No notifications'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders notifications pushed onto the stream', (tester) async {
      final controller = StreamController<AppNotification>();
      addTearDown(controller.close);

      await tester.pumpWidget(_harness(controller: controller));
      controller.add(_notif('a'));
      await tester.pumpAndSettle();

      expect(find.text('Driver assigned'), findsOneWidget);
      expect(find.text('Your driver is 5 minutes away'), findsOneWidget);
    });

    testWidgets('Mark all read clears the unread affordance', (tester) async {
      final controller = StreamController<AppNotification>();
      addTearDown(controller.close);

      await tester.pumpWidget(_harness(controller: controller));
      controller.add(_notif('a'));
      await tester.pumpAndSettle();

      expect(find.text('Mark all read'), findsOneWidget);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      // Once everything is read the action disappears.
      expect(find.text('Mark all read'), findsNothing);
    });
  });
}
