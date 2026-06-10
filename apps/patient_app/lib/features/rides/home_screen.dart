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
                        builder: (ctx) => GestureDetector(
                          onTap: () => Scaffold.of(ctx).openDrawer(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kSurface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.menu, size: 20),
                          ),
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
                              fontSize: 14,
                              color: kText400,
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
                      error: (_, __) => const SizedBox(height: 40),
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

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref
        .watch(notificationsProvider('patient'))
        .any((n) => !n.isRead);
    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: kSurface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(Icons.notifications_outlined, size: 20),
            ),
            if (hasUnread)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: kRed600,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PortalChip extends StatelessWidget {
  const _PortalChip({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Scaffold.of(context).openDrawer(),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpaceMD, vertical: kSpaceXS),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadiusPill),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
          ],
        ),
        child: const Row(
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
            Icon(Icons.keyboard_arrow_down, size: 16, color: kTeal600),
          ],
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

    if (!WidgetsBinding.instance.accessibilityFeatures.disableAnimations) {
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
    final disableAnimations =
        MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: 'Request emergency ride',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/symptoms'),
        child: SizedBox(
          width: kEmergencyButtonSize + 40,
          height: kEmergencyButtonSize + 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!disableAnimations)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = _pulse.value;
                    return Transform.scale(
                      scale: 1.0 + 0.22 * t,
                      child: Opacity(
                        opacity: 0.25 * (1 - t),
                        child: Container(
                          width: kEmergencyButtonSize,
                          height: kEmergencyButtonSize,
                          decoration: const BoxDecoration(
                            color: kRed600,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: kEmergencyButtonSize,
                height: kEmergencyButtonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFE03535), Color(0xFFC62828)],
                  ),
                  boxShadow: kEmergencyButtonShadow,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 40),
                    SizedBox(height: 4),
                    Text(
                      'EMERGENCY',
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: () => context.push('/ride/${ride.id}'),
      child: Container(
        padding: const EdgeInsets.all(kSpaceMD),
        decoration: BoxDecoration(
          color: kTeal100,
          borderRadius: BorderRadius.circular(kRadiusLG),
        ),
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
            const Icon(Icons.arrow_forward_ios, size: 16, color: kText600),
          ],
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
