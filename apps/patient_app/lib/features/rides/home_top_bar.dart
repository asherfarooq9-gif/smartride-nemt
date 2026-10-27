import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/shared/glass_surface.dart';
import 'package:patient_app/shared/role_switcher.dart';

/// The frosted bar floating over the home map: menu, title (or the portal
/// switch for accounts that hold both roles) and notifications.
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final hasBothPortals =
        roles.contains('patient') && roles.contains('driver');

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kSpaceLG,
          kSpaceSM,
          kSpaceLG,
          0,
        ),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(kRadiusPill),
          padding: const EdgeInsets.symmetric(horizontal: kSpaceXS),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Open menu',
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded),
                constraints: const BoxConstraints(
                  minWidth: kMinTapTarget,
                  minHeight: kMinTapTarget,
                ),
              ),
              Expanded(
                child: Center(
                  child: hasBothPortals
                      ? const _PortalSwitch()
                      : Semantics(
                          header: true,
                          child: const Text(
                            'SmartRide',
                            style: TextStyle(
                              fontSize: kFontSubhead,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                ),
              ),
              const _NotificationBell(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalSwitch extends ConsumerWidget {
  const _PortalSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      segments: const [
        ButtonSegment(value: 'patient', label: Text('Patient')),
        ButtonSegment(value: 'driver', label: Text('Driver')),
      ],
      selected: const {'patient'},
      onSelectionChanged: (choice) {
        if (choice.first == 'driver') {
          switchPortal(context, ref, 'driver', '/driver');
        }
      },
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread =
        ref.watch(notificationsProvider('patient')).any((n) => !n.isRead);
    final accent = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        IconButton(
          tooltip:
              hasUnread ? 'Notifications, you have unread' : 'Notifications',
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
          constraints: const BoxConstraints(
            minWidth: kMinTapTarget,
            minHeight: kMinTapTarget,
          ),
        ),
        if (hasUnread)
          Positioned(
            top: 11,
            right: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: kSurface, width: 1.5),
              ),
              child: const SizedBox(width: 10, height: 10),
            ),
          ),
      ],
    );
  }
}
