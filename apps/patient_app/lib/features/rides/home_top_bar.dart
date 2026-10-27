import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/shared/glass_circle_button.dart';
import 'package:patient_app/shared/glass_surface.dart';
import 'package:patient_app/shared/role_switcher.dart';

/// The controls floating over the home map: a round menu button, a round
/// notifications button with an unread dot and, for accounts that hold both
/// roles, a compact Patient | Driver switch between them.
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final hasBothPortals =
        roles.contains('patient') && roles.contains('driver');
    final hasUnread =
        ref.watch(notificationsProvider('patient')).any((n) => !n.isRead);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kSpaceLG, kSpaceSM, kSpaceLG, 0),
        // A fixed height: the Row otherwise inherits the loose, screen-high
        // constraints of the Stack and grows to fill them.
        child: SizedBox(
          height: kMinTapTarget,
          child: Row(
            children: [
              GlassCircleButton(
                tooltip: 'Open menu',
                icon: Icons.menu_rounded,
                onPressed: onMenu,
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: hasBothPortals
                        ? const _PortalSwitch(key: ValueKey('portal-switch'))
                        : const SizedBox.shrink(key: ValueKey('no-switch')),
                  ),
                ),
              ),
              GlassCircleButton(
                tooltip: hasUnread
                    ? 'Notifications, you have unread'
                    : 'Notifications',
                icon: Icons.notifications_none_rounded,
                hasBadge: hasUnread,
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalSwitch extends ConsumerWidget {
  const _PortalSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(kRadiusPill),
      padding: const EdgeInsets.all(2),
      child: SegmentedButton<String>(
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
      ),
    );
  }
}
