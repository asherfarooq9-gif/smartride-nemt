import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, required this.portal});

  final String portal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider(portal));
    final hasUnread = notifications.any((n) => !n.isRead);
    final isPatient = portal == 'patient';
    final primary = isPatient ? kTeal600 : kBlue600;
    final unreadBg = isPatient ? kTeal50 : kBlue100;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: const BackButton(),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => ref
                  .read(notificationsProvider(portal).notifier)
                  .markAllRead(),
              child: Text(
                'Mark all read',
                style: TextStyle(
                    color: primary, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const EmptyState(message: 'No notifications yet')
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, i) {
                final item = notifications[i];
                return _NotificationTile(
                  item: item,
                  primary: primary,
                  unreadBg: unreadBg,
                  onTap: () => ref
                      .read(notificationsProvider(portal).notifier)
                      .markRead(item.id),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.primary,
    required this.unreadBg,
    required this.onTap,
  });

  final AppNotification item;
  final Color primary;
  final Color unreadBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        color: item.isRead ? kSurface : unreadBg,
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceMD,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!item.isRead)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: kSpaceSM),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              const SizedBox(width: kSpaceLG),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kRadiusMD),
              ),
              child: Icon(item.icon, size: 20, color: primary),
            ),
            const SizedBox(width: kSpaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: kFontSmall,
                            fontWeight: FontWeight.w700,
                            color: kText900,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpaceSM),
                      Text(
                        item.time,
                        style: const TextStyle(
                          fontSize: kFontCaption,
                          color: kText400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kText600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
