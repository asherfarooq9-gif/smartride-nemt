import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:patient_app/features/rides/home_glass_card.dart';

const Color _kNavy = Color(0xFF101F3D);
const Color _kOnline = Color(0xFF22A55A);

/// Why the Online controls are locked, or null when they are free to use.
///
/// The server decides who may go online (`isVerified`) and who is online
/// (`driver.status`); nothing here is a guess. A driver who is already online
/// can always go offline.
String? onlineLockReason(DashboardState dash) {
  if (dash.driver == null) {
    return dash.isLoading
        ? 'Loading your account'
        : 'Your account could not be loaded';
  }
  if (!dash.driver!.isVerified && !dash.isOnline) {
    return 'Available once your account is verified';
  }
  return null;
}

/// What a tap on either Online control does. One function for both, so they can
/// never disagree.
void requestOnlineChange(BuildContext context, WidgetRef ref) {
  final dash = ref.read(dashboardProvider);
  if (dash.isUpdatingStatus) return;
  final reason = onlineLockReason(dash);
  if (reason != null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(reason)));
    return;
  }
  ref.read(dashboardProvider.notifier).toggleOnline();
}

/// "You're Online" / "You're Offline" with a switch. The state shown is always
/// the one the server last confirmed, never the one just tapped.
class AvailabilityCard extends ConsumerWidget {
  const AvailabilityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final palette = HomePalette.of(context);
    final isOnline = dash.isOnline;
    final lock = onlineLockReason(dash);
    // Until the account is known the card claims neither Online nor Offline.
    final isUnknown = dash.driver == null;
    final title = isUnknown
        ? (dash.isLoading ? 'Checking your status' : 'Status unavailable')
        : isOnline
            ? "You're Online"
            : "You're Offline";
    final subtitle = lock != null && !isOnline
        ? lock
        : isOnline
            ? 'Ready to receive ride requests'
            : 'Go online to receive ride requests';

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: HomeGlassCard(
        radius: 16,
        isSeeThrough: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: core.kSpaceSM + 2,
              vertical: 4,
            ),
            child: Row(
              children: [
                _StatusDot(isOnline: isOnline),
                const SizedBox(width: core.kSpaceSM + 2),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: core.kFontSmall + 2,
                          fontWeight: FontWeight.w700,
                          color: palette.heading,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: core.kSpaceSM),
                _AvailabilitySwitch(
                  isOnline: isOnline,
                  // Genuinely waiting: a status change, or the first load.
                  isBusy:
                      dash.isUpdatingStatus || (isUnknown && dash.isLoading),
                  isLocked: lock != null,
                  onTap: () => requestOnlineChange(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final muted = HomePalette.of(context).muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOnline ? _kOnline : muted.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: const SizedBox(width: 12, height: 12),
    );
  }
}

class _AvailabilitySwitch extends StatelessWidget {
  const _AvailabilitySwitch({
    required this.isOnline,
    required this.isBusy,
    required this.isLocked,
    required this.onTap,
  });

  final bool isOnline;
  final bool isBusy;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Wide enough that the spinner does not shift the layout.
    return SizedBox(
      width: core.kMinTapTarget + 12,
      height: core.kMinTapTarget,
      child: Center(
        child: isBusy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Semantics(
                toggled: isOnline,
                label: 'Online',
                excludeSemantics: true,
                child: GestureDetector(
                  // A locked switch still answers a tap, with the reason.
                  onTap: isLocked ? onTap : null,
                  child: CupertinoSwitch(
                    value: isOnline,
                    activeTrackColor: _kOnline,
                    onChanged: isLocked ? null : (_) => onTap(),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The large Go Online / Go Offline pill. Same state and same handler as the
/// switch above.
class GoOnlineButton extends ConsumerWidget {
  const GoOnlineButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final scheme = Theme.of(context).colorScheme;
    final isOnline = dash.isOnline;
    final isLocked = onlineLockReason(dash) != null;
    final isBusy = dash.isUpdatingStatus;
    final background =
        scheme.brightness == Brightness.dark ? scheme.primary : _kNavy;
    final label = isOnline ? 'Go Offline' : 'Go Online';

    return Semantics(
      button: true,
      enabled: !isLocked && !isBusy,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isLocked ? background.withValues(alpha: 0.4) : background,
        shape: const StadiumBorder(),
        elevation: isLocked ? 0 : 3,
        shadowColor: _kNavy.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const StadiumBorder(),
          // Locked still answers, to say why; busy ignores the tap.
          onTap: isBusy ? null : () => requestOnlineChange(context, ref),
          child: SizedBox(
            height: 48,
            child: Center(
              child: isBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_car_rounded,
                            color: Colors.white),
                        const SizedBox(width: core.kSpaceSM),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: core.kFontBody,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small card in the 2 × 2 grid of shortcuts.
class DriverActionCard extends StatelessWidget {
  const DriverActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Left out on a narrow card: the words matter more than the arrow.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: _card(context, palette),
    );
  }

  Widget _card(BuildContext context, HomePalette palette) {
    return HomeGlassCard(
      onTap: onTap,
      radius: 16,
      isSeeThrough: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: core.kSpaceSM,
            vertical: 6,
          ),
          child: Row(
            children: [
              HomeIconDisc(icon: icon, size: 30),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.heading,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: palette.muted),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ride Requests, Navigation, Earnings and Settings in two columns.
class DriverActionsGrid extends ConsumerWidget {
  const DriverActionsGrid({super.key, required this.onShowRequests});

  /// Brings the list of requests into view (the sheet opens up).
  final VoidCallback onShowRequests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final cardWidth = (box.maxWidth - 6) / 2;
        return _grid(context, ref, showChevron: cardWidth >= _chevronMinWidth);
      },
    );
  }

  /// Below this card width the chevron is left out.
  static const _chevronMinWidth = 190.0;

  Widget _grid(
    BuildContext context,
    WidgetRef ref, {
    required bool showChevron,
  }) {
    final cards = [
      DriverActionCard(
        showChevron: showChevron,
        icon: Icons.place_outlined,
        title: 'Ride Requests',
        subtitle: 'View nearby requests',
        onTap: () {
          final dash = ref.read(dashboardProvider);
          final lock = onlineLockReason(dash);
          if (lock != null || !dash.isOnline) {
            _say(context, lock ?? 'Go online to receive ride requests');
            return;
          }
          onShowRequests();
        },
      ),
      DriverActionCard(
        showChevron: showChevron,
        icon: Icons.navigation_rounded,
        title: 'Navigation',
        subtitle: 'Start your trip',
        onTap: () {
          final ride = ref.read(dashboardProvider).activeRide;
          if (ride == null) {
            _say(context, 'Accept a ride to start navigation');
            return;
          }
          context.push('/driver/ride/${ride.id}');
        },
      ),
      DriverActionCard(
        showChevron: showChevron,
        icon: Icons.account_balance_wallet_outlined,
        title: 'Earnings',
        subtitle: 'View your earnings',
        onTap: () => context.push('/driver/earnings'),
      ),
      DriverActionCard(
        showChevron: showChevron,
        icon: Icons.settings_rounded,
        title: 'Settings',
        subtitle: 'App preferences',
        onTap: () => context.push('/driver/settings'),
      ),
    ];
    return Column(
      children: [
        for (var row = 0; row < cards.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[row]),
                const SizedBox(width: core.kSpaceSM),
                Expanded(child: cards[row + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// A ride is in progress: the only way back into it after the app was closed.
class ResumeRideBanner extends StatelessWidget {
  const ResumeRideBanner({
    super.key,
    required this.statusLabel,
    required this.onResume,
  });

  final String statusLabel;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'You have a ride in progress, $statusLabel. Resume',
      excludeSemantics: true,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onResume,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: core.kMinTapTarget),
            child: Padding(
              padding: const EdgeInsets.all(core.kSpaceMD),
              child: Row(
                children: [
                  Icon(Icons.local_taxi_rounded,
                      color: scheme.onPrimaryContainer),
                  const SizedBox(width: core.kSpaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You have a ride in progress',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          statusLabel,
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Resume',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: scheme.onPrimaryContainer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
