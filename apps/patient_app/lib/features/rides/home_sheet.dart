import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/features/rides/emergency_button.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';

/// The patient's first name for the home greeting.
///
/// Falls back to "there" if the profile cannot be loaded, so a failed fetch
/// never blanks the header.
final patientNameProvider = FutureProvider.autoDispose<String>((ref) async {
  try {
    final p = await getPatientMe();
    // Cache the name once fetched: without keepAlive, every return to the
    // home screen re-fires this network call and flashes a loading state.
    ref.keepAlive();
    return p.fullName ?? 'there';
  } on Exception {
    return 'there';
  }
});

const _kPeekSize = 0.42;
const _kRestSize = 0.62;
const _kFullSize = 0.92;

/// The draggable bottom sheet on the home screen: greeting, the SOS button,
/// Book a Ride and quick actions. Drag it up for more room or down to see
/// more of the map.
///
/// All colours come from the theme's colour scheme, so the sheet follows light
/// and dark mode and the portal accent.
class HomeSheet extends ConsumerWidget {
  const HomeSheet({super.key, this.onCallEmergency});

  /// Dials the emergency number. Defaults to the phone dialler; tests inject
  /// their own.
  final VoidCallback? onCallEmergency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRide = ref.watch(activeRideProvider);
    final name = ref.watch(patientNameProvider);
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: _kRestSize,
      minChildSize: _kPeekSize,
      maxChildSize: _kFullSize,
      snap: true,
      snapSizes: const [_kPeekSize, _kRestSize, _kFullSize],
      builder: (context, controller) {
        return DecoratedBox(
          key: const ValueKey('sheet-top'),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(kRadiusSheet),
            ),
            boxShadow: kSheetShadow,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(kRadiusSheet),
            ),
            child: ColoredBox(
              color: scheme.surface,
              child: ListView(
                controller: controller,
                // Leave room for the tab bar and safe area the sheet runs under.
                padding: EdgeInsets.fromLTRB(
                  kSpaceXL,
                  0,
                  kSpaceXL,
                  kSpaceXXL + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  const _Grabber(),
                  _Greeting(name: name.valueOrNull),
                  const SizedBox(height: kSpaceLG),
                  if (activeRide != null) ...[
                    _ActiveRideBanner(ride: activeRide),
                    const SizedBox(height: kSpaceLG),
                  ],
                  const Center(child: EmergencyButton()),
                  const SizedBox(height: kSpaceLG),
                  const _BookRideCard(),
                  const SizedBox(height: kSpaceLG),
                  _QuickActions(onCallEmergency: onCallEmergency),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Drag to resize',
      child: SizedBox(
        key: const ValueKey('sheet-grabber'),
        height: 28,
        child: Center(
          child: Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(kRadiusPill),
            ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(),
          style: TextStyle(
            fontSize: kFontSmall,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// A tinted, tappable card: an accent-coloured icon, a title and a subtitle.
class _TintedCard extends StatelessWidget {
  const _TintedCard({
    required this.semanticsLabel,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.minHeight = kMinTapTarget,
  });

  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(kRadiusXL),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusXL),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kSpaceLG,
                vertical: kSpaceMD,
              ),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: kSpaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: kFontBody,
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: kFontSmall,
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onPrimaryContainer,
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

class _BookRideCard extends StatelessWidget {
  const _BookRideCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _TintedCard(
      semanticsLabel: 'Book a ride. Schedule a non-emergency trip',
      onTap: () => context.push('/book-ride'),
      minHeight: 72,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: scheme.primary,
        child: const Icon(Icons.event_available_rounded, color: Colors.white),
      ),
      title: 'Book a Ride',
      subtitle: 'Schedule a non-emergency trip',
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.ride});
  final RideResponse ride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _TintedCard(
      semanticsLabel: 'Active ride, ${ride.status.displayLabel}. View details',
      onTap: () => context.push('/ride/${ride.id}'),
      leading: Icon(
        Icons.directions_car_rounded,
        color: scheme.onPrimaryContainer,
      ),
      title: 'Active Ride',
      subtitle: ride.status.displayLabel,
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onCallEmergency});
  final VoidCallback? onCallEmergency;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(kRadiusXL),
      ),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.bookmark_border_rounded,
            label: 'Saved places',
            onTap: () => context.push('/saved-places'),
          ),
          const _RowDivider(),
          _ActionRow(
            icon: Icons.history_rounded,
            label: 'Past rides',
            onTap: () => context.go('/rides'),
          ),
          const _RowDivider(),
          _ActionRow(
            icon: Icons.phone_in_talk_outlined,
            iconColor: kEmergencyRed,
            label: 'Call 1122',
            onTap: onCallEmergency ?? _dialEmergency,
          ),
        ],
      ),
    );
  }

  static Future<void> _dialEmergency() async {
    final uri = Uri.parse('tel:1122');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 56,
        color: Theme.of(context).colorScheme.outlineVariant,
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Defaults to the portal accent.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusXL),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? scheme.primary, size: 22),
              const SizedBox(width: kSpaceMD),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: kFontBody,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
