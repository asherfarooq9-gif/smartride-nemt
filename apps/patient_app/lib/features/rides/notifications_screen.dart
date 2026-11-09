import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/shared/apple_list.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, required this.portal});

  final String portal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider(portal));
    final hasUnread = notifications.any((n) => !n.isRead);
    final isPatient = portal == 'patient';
    final primary = isPatient ? kPatient600 : kBlue600;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationsTitle),
        leading: const BackButton(),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => ref
                  .read(notificationsProvider(portal).notifier)
                  .markAllRead(),
              child: Text(
                context.l10n.markAllRead,
                style: TextStyle(color: primary, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: kSpaceXS),
        ],
      ),
      body: notifications.isEmpty
          ? EmptyState(message: context.l10n.noNotificationsYet)
          : ListView(
              padding: const EdgeInsets.only(bottom: kSpaceXXL),
              children: [
                AppleSection(
                  dividerIndent: kSpaceLG + 8 + kSpaceSM,
                  children: [
                    for (final item in notifications)
                      _NotificationTile(
                        item: item,
                        primary: primary,
                        onTap: () => ref
                            .read(notificationsProvider(portal).notifier)
                            .markRead(item.id),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.primary,
    required this.onTap,
  });

  final AppNotification item;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final hint = isDark ? kDarkText3 : kText400;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceMD,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The unread dot sits in its own slot so read and unread rows
            // line up.
            SizedBox(
              width: 8 + kSpaceSM,
              child: item.isRead
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 11),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(item.icon, size: 18, color: Colors.white),
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
                          style: TextStyle(
                            fontSize: kFontBody,
                            fontWeight:
                                item.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: kSpaceSM),
                      Text(
                        item.time,
                        style: TextStyle(fontSize: 13, color: hint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: kFontSmall,
                      color: scheme.onSurfaceVariant,
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
