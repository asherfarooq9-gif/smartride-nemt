import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/features/rides/home_glass_card.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:patient_app/shared/press_scale.dart';

/// The small bar at the top of the sheet that shows it can be dragged.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

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

/// "Good afternoon" with a wave and a calm supporting line.
class SheetGreeting extends StatelessWidget {
  const SheetGreeting({super.key});

  static String greetingFor(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  greetingFor(DateTime.now()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: palette.heading,
                  ),
                ),
              ),
            ),
            const SizedBox(width: kSpaceSM),
            const ExcludeSemantics(
              child: Text('👋', style: TextStyle(fontSize: 21)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "Stay safe. We're here for you.",
          style: TextStyle(fontSize: kFontBody, color: palette.muted),
        ),
      ],
    );
  }
}

/// A tinted, tappable banner for the ride in progress.
class ActiveRideBanner extends StatelessWidget {
  const ActiveRideBanner({super.key, required this.ride, required this.onTap});

  final RideResponse ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Active ride, ${ride.status.displayLabel}. View details',
      excludeSemantics: true,
      child: PressScale(
        child: Material(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(kRadiusXL),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusXL),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinTapTarget),
              child: Padding(
                padding: const EdgeInsets.all(kSpaceMD),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: kSpaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Ride',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            ride.status.displayLabel,
                            style: TextStyle(
                              fontSize: kFontSmall,
                              color: scheme.onPrimaryContainer,
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
      ),
    );
  }
}

/// The "Book a Ride" card: a car in an accent circle, a title, a subtitle and
/// a chevron.
class BookRideCard extends StatelessWidget {
  const BookRideCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return Semantics(
      button: true,
      label: 'Book a ride. Schedule a non-emergency trip',
      excludeSemantics: true,
      child: HomeGlassCard(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kSpaceMD,
              vertical: kSpaceSM,
            ),
            child: Row(
              children: [
                const HomeIconDisc(icon: Icons.directions_car_rounded),
                const SizedBox(width: kSpaceMD),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book a Ride',
                        style: TextStyle(
                          fontSize: kFontBody,
                          fontWeight: FontWeight.w700,
                          color: palette.heading,
                        ),
                      ),
                      Text(
                        'Schedule a non-emergency trip',
                        style: TextStyle(
                            fontSize: kFontSmall, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.heading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recent Rides, Favorites and Safety Tips as three compact cards in a row;
/// stacked as a list with large text or on very narrow screens.
///
/// Favorites opens the saved places, and Safety Tips opens Help (the emergency
/// guidance and the FAQ).
class QuickCardsRow extends StatelessWidget {
  const QuickCardsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final isStacked = MediaQuery.sizeOf(context).width < 340 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final cards = [
      QuickCard(
        icon: Icons.history_rounded,
        title: 'Recent Rides',
        subtitle: 'View your trips',
        isCompact: !isStacked,
        onTap: () => context.go('/rides'),
      ),
      QuickCard(
        icon: Icons.star_rounded,
        title: 'Favorites',
        subtitle: 'Saved locations',
        isCompact: !isStacked,
        onTap: () => context.push('/saved-places'),
      ),
      QuickCard(
        icon: Icons.shield_outlined,
        title: 'Safety Tips',
        subtitle: 'Stay informed',
        isCompact: !isStacked,
        onTap: () => context.push('/help'),
      ),
    ];

    if (isStacked) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: kSpaceSM),
            cards[i],
          ],
        ],
      );
    }
    // Three narrow cards: icon over text so the text can wrap at its real
    // size instead of being shrunk to fit. They share the tallest card's height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: kSpaceSM),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class QuickCard extends StatelessWidget {
  const QuickCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isCompact = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Text only, for the three-across row: each card is too narrow for an icon
  /// beside readable text, and too short for one above it. When false, a
  /// full-width row with icon and chevron.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: HomeGlassCard(
        onTap: onTap,
        radius: 18,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(kSpaceSM),
            child: isCompact
                ? _CompactQuickCardBody(title, subtitle)
                : _WideQuickCardBody(icon, title, subtitle),
          ),
        ),
      ),
    );
  }
}

class _CompactQuickCardBody extends StatelessWidget {
  const _CompactQuickCardBody(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.heading,
          ),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
      ],
    );
  }
}

class _WideQuickCardBody extends StatelessWidget {
  const _WideQuickCardBody(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return Row(
      children: [
        HomeIconDisc(icon: icon, size: 36),
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
                  color: palette.heading,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: kFontSmall, color: palette.muted),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: palette.muted),
      ],
    );
  }
}

/// The patient's last few rides, from the real list. Shows loading, empty and
/// error states; nothing is ever invented.
class RecentRidesSection extends ConsumerWidget {
  const RecentRidesSection({super.key});

  static const _maxShown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rides = ref.watch(ridesProvider);

    final Widget body = rides.when(
      loading: () => const _RidesSkeleton(),
      error: (_, __) => _RidesMessage(
        title: "Couldn't load your rides",
        actionLabel: 'Try again',
        onAction: () => ref.read(ridesProvider.notifier).refresh(),
      ),
      data: (list) {
        if (list.items.isEmpty) {
          return const _RidesMessage(title: 'No rides yet');
        }
        return Column(
          children: [
            for (final ride in list.items.take(_maxShown)) _RideRow(ride: ride),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Your recent rides',
            style: TextStyle(
              fontSize: kFontSubhead,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: kSpaceSM),
        body,
      ],
    );
  }
}

class _RideRow extends StatelessWidget {
  const _RideRow({required this.ride});

  final RideResponse ride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEmergency = ride.rideType == RideType.emergency;
    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusLG),
      onTap: () => context.push('/ride/${ride.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTapTarget + kSpaceSM),
        child: Row(
          children: [
            Icon(
              isEmergency ? Icons.warning_rounded : Icons.event_rounded,
              color: isEmergency ? kEmergencyRed : scheme.primary,
            ),
            const SizedBox(width: kSpaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.pickupAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    ride.status.displayLabel,
                    style: TextStyle(
                      fontSize: kFontSmall,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _RidesMessage extends StatelessWidget {
  const _RidesMessage({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpaceMD),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _RidesSkeleton extends StatelessWidget {
  const _RidesSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Loading your rides',
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: kSpaceSM),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(kRadiusLG),
                ),
                child: const SizedBox(height: 48, width: double.infinity),
              ),
            ),
        ],
      ),
    );
  }
}
