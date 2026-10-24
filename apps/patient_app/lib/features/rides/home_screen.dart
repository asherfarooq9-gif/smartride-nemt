import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:patient_app/shared/role_switcher.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRide = ref.watch(activeRideProvider);
    final me = ref.watch(_meProvider);

    return Scaffold(
      drawer: const PortalDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(33.6844, 73.0479),
              initialZoom: 13,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartride.patient',
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceLG, vertical: kSpaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (ctx) => _MapOverlayButton(
                          tooltip: 'Open menu',
                          icon: Icons.menu,
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      const Spacer(),
                      const _NotificationBell(),
                    ],
                  ),
                  const SizedBox(height: kSpaceSM),
                  _PortalChip(ref: ref),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(kRadiusSheet)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16),
                ],
              ),
              padding:
                  const EdgeInsets.fromLTRB(kSpaceXL, kSpaceXL, kSpaceXL, 0),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    me.when(
                      data: (name) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting(),
                            style: const TextStyle(
                              fontSize: kFontSmall,
                              color: kText600,
                            ),
                          ),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kText900,
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(height: 40),
                      // Profile fetch failing shouldn't blank the header —
                      // fall back to the greeting alone.
                      error: (_, __) => SizedBox(
                        height: 40,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _greeting(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kText900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpaceXL),
                    if (activeRide != null) ...[
                      _ActiveRideBanner(ride: activeRide),
                      const SizedBox(height: kSpaceLG),
                    ],
                    Center(child: _EmergencyButton()),
                    const SizedBox(height: kSpaceMD),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: kSpaceSM),
                          child: Text(
                            'or',
                            style: TextStyle(color: kText400),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: kSpaceMD),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/book-ride'),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('Book a Ride'),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size(double.infinity, kButtonHeight),
                        side: const BorderSide(color: kTeal600),
                        foregroundColor: kTeal600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kRadiusLG),
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpaceLG),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _PatientBottomNav(currentIndex: 0),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

final _meProvider = FutureProvider.autoDispose<String>((ref) async {
  try {
    final p = await getPatientMe();
    // Cache the name once fetched — without keepAlive, every return to the
    // home screen re-fires this network call and flashes a loading state.
    ref.keepAlive();
    return p.fullName ?? 'there';
  } on Exception {
    return 'there';
  }
});

/// 48dp round button floating over the map; the tooltip is also the screen
/// reader label.
class _MapOverlayButton extends StatelessWidget {
  const _MapOverlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.hasBadge = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      shape: const CircleBorder(),
      elevation: 3,
      child: Stack(
        children: [
          IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: kText900),
            constraints: const BoxConstraints(
                minWidth: kMinTapTarget, minHeight: kMinTapTarget),
          ),
          if (hasBadge)
            const Positioned(
              top: 10,
              right: 10,
              child: DecoratedBox(
                decoration:
                    BoxDecoration(color: kRed600, shape: BoxShape.circle),
                child: SizedBox(width: 10, height: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref
        .watch(notificationsProvider('patient'))
        .any((n) => !n.isRead);
    return _MapOverlayButton(
      tooltip: hasUnread ? 'Notifications, you have unread' : 'Notifications',
      icon: Icons.notifications_outlined,
      hasBadge: hasUnread,
      onPressed: () => context.push('/notifications'),
    );
  }
}

class _PortalChip extends StatelessWidget {
  const _PortalChip({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Patient portal. Open portal menu',
      excludeSemantics: true,
      child: Material(
        color: kSurface,
        elevation: 3,
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusPill),
          onTap: () => Scaffold.of(context).openDrawer(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: kSpaceMD),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Patient',
                    style: TextStyle(
                      fontSize: kFontSmall,
                      fontWeight: FontWeight.w600,
                      color: kTeal600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: kTeal600),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatefulWidget {
  @override
  State<_EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<_EmergencyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    // Grow with the system font size so the label always fits the circle.
    final diameter = MediaQuery.textScalerOf(context)
        .scale(kEmergencyButtonSize)
        .clamp(kEmergencyButtonSize, kEmergencyButtonSize * 1.5);

    return Semantics(
      label: 'Request emergency ride',
      hint: 'Double tap to get immediate help',
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: diameter + 40,
        height: diameter + 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!disableAnimations)
              _PulseRing(animation: _pulse, size: diameter),
            Material(
              type: MaterialType.circle,
              color: Colors.transparent,
              child: Ink(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFE03535), Color(0xFFC62828)],
                  ),
                  boxShadow: kEmergencyButtonShadow,
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/symptoms'),
                  child: const _EmergencyLabel(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.animation, required this.size});
  final Animation<double> animation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Transform.scale(
          scale: 1.0 + 0.22 * t,
          child: Opacity(
            opacity: 0.25 * (1 - t),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: kRed600,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmergencyLabel extends StatelessWidget {
  const _EmergencyLabel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(kSpaceLG),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white, size: 40),
                SizedBox(height: 4),
                Text(
                  'EMERGENCY',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap for immediate help',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: kFontSmall, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.ride});
  final RideResponse ride;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Active ride, ${ride.status.displayLabel}. View details',
      excludeSemantics: true,
      child: Material(
        color: kTeal100,
        borderRadius: BorderRadius.circular(kRadiusLG),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusLG),
          onTap: () => context.push('/ride/${ride.id}'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            child: Padding(
              padding: const EdgeInsets.all(kSpaceMD),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: kTeal600),
                  const SizedBox(width: kSpaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Ride',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kText900,
                          ),
                        ),
                        Text(
                          ride.status.displayLabel,
                          style: const TextStyle(
                            fontSize: kFontSmall,
                            color: kText600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: kText600),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientBottomNav extends StatelessWidget {
  const _PatientBottomNav({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/');
          case 1:
            context.go('/rides');
          case 2:
            context.go('/profile');
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'My Rides',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
