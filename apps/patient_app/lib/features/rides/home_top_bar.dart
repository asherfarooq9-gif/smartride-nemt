import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/shared/glass_circle_button.dart';
import 'package:patient_app/shared/glass_segmented_control.dart';
import 'package:patient_app/shared/role_switcher.dart';

/// The controls floating over the home map: a round menu button, a round
/// notifications button with an unread dot and, for accounts that hold both
/// roles, a compact switch between the two portals.
///
/// [portal] is the portal this bar belongs to, `patient` or `driver`: it picks
/// which notifications to watch, where the bell leads and which segment is lit.
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({super.key, required this.onMenu, this.portal = 'patient'});

  final VoidCallback onMenu;
  final String portal;

  bool get _isDriver => portal == 'driver';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final hasBothPortals =
        roles.contains('patient') && roles.contains('driver');
    final hasUnread =
        ref.watch(notificationsProvider(portal)).any((n) => !n.isRead);

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
                        ? _PortalSwitch(
                            key: const ValueKey('portal-switch'),
                            portal: portal,
                          )
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
                onPressed: () => context.push(
                  _isDriver ? '/driver/notifications' : '/notifications',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalSwitch extends ConsumerWidget {
  const _PortalSwitch({super.key, required this.portal});

  final String portal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const patient = GlassSegment(value: 'patient', label: 'Patient');
    const driver = GlassSegment(value: 'driver', label: 'Driver');
    return GlassSegmentedControl<String>(
      // Your own portal comes first.
      segments: portal == 'driver' ? [driver, patient] : [patient, driver],
      selected: portal,
      onChanged: (choice) {
        if (choice == portal) return;
        switchPortal(
            context, ref, choice, choice == 'driver' ? '/driver' : '/');
      },
    );
  }
}
