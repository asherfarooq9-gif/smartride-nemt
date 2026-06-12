import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/providers.dart';

// Drives the notifier with a controllable stream instead of real FCM.
AppNotification _notif(String id, {bool isRead = false}) => AppNotification(
      id: id,
      title: 'Ride update',
      body: 'Your driver is on the way',
      time: 'Just now',
      icon: Icons.notifications_active_outlined,
      isRead: isRead,
    );

void main() {
  group('NotificationsNotifier', () {
    test('starts empty — no demo seed data', () {
      final notifier = NotificationsNotifier('patient',
          incoming: const Stream.empty());
      addTearDown(notifier.dispose);

      expect(notifier.state, isEmpty);
    });

    test('prepends notifications arriving from the stream', () async {
      final controller = StreamController<AppNotification>();
      addTearDown(controller.close);
      final notifier =
          NotificationsNotifier('patient', incoming: controller.stream);
      addTearDown(notifier.dispose);

      controller.add(_notif('a'));
      controller.add(_notif('b'));
      await Future<void>.delayed(Duration.zero);

      // Newest first.
      expect(notifier.state.map((n) => n.id).toList(), ['b', 'a']);
    });

    test('markRead flips only the targeted notification', () async {
      final controller = StreamController<AppNotification>();
      addTearDown(controller.close);
      final notifier =
          NotificationsNotifier('patient', incoming: controller.stream);
      addTearDown(notifier.dispose);

      controller.add(_notif('a'));
      controller.add(_notif('b'));
      await Future<void>.delayed(Duration.zero);

      notifier.markRead('a');

      final byId = {for (final n in notifier.state) n.id: n.isRead};
      expect(byId['a'], isTrue);
      expect(byId['b'], isFalse);
    });

    test('markAllRead flips every notification', () async {
      final controller = StreamController<AppNotification>();
      addTearDown(controller.close);
      final notifier =
          NotificationsNotifier('patient', incoming: controller.stream);
      addTearDown(notifier.dispose);

      controller.add(_notif('a'));
      controller.add(_notif('b'));
      await Future<void>.delayed(Duration.zero);

      notifier.markAllRead();

      expect(notifier.state.every((n) => n.isRead), isTrue);
    });

    test('dispose cancels the subscription — late events are ignored',
        () async {
      final controller = StreamController<AppNotification>();
      addTearDown(controller.close);
      final notifier =
          NotificationsNotifier('patient', incoming: controller.stream);

      notifier.dispose();
      // Emitting after dispose must not throw — the listener is detached, so
      // it never tries to set state on a disposed notifier.
      controller.add(_notif('late'));
      await expectLater(
        Future<void>.delayed(Duration.zero),
        completes,
      );
    });
  });
}
