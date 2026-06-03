import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartride_core/smartride_core.dart';
import 'rides_notifier.dart';
import '../../shared/role_switcher.dart';

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
          // Map background
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
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: kSpaceLG, vertical: kSpaceMD),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: const Icon(Icons.menu, size: 20),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _PortalChip(ref: ref),
                ],
              ),
            ),
          ),
          // Bottom panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16)
                ],
              ),
              padding: const EdgeInsets.fromLTRB(
                  kSpaceXL, kSpaceXL, kSpaceXL, 0),
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
                              fontSize: kFontSM,
                              color: kTextSecondary,
                            ),
                          ),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: kFontXL,
                              fontWeight: FontWeight.bold,
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
                    // Emergency button
                    Semantics(
                      label: 'Request emergency ride',
                      button: true,
                      child: GestureDetector(
                        onTap: () => context.push('/symptoms'),
                        child: Container(
                          height: kEmergencyButtonHeight + 16,
                          decoration: BoxDecoration(
                            color: kEmergencyRed,
                            borderRadius:
                                BorderRadius.circular(kRadiusXL),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    kEmergencyRed.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline,
                                  color: Colors.white, size: 28),
                              SizedBox(width: kSpaceMD),
                              Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EMERGENCY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: kFontLG,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    'Tap for immediate help',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: kFontXS,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpaceMD),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: kSpaceSM),
                          child: Text('or',
                              style: TextStyle(color: kTextSecondary)),
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
                            const Size(double.infinity, kMinTapTarget),
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(kRadiusLG),
                        ),
                      ),
                    ),
                    const SizedBox(height: kSpaceXS),
                    const Text(
                      'Schedule a trip to your hospital',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: kFontXS,
                        color: kTextSecondary,
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

// Provider that loads the patient first name
final _meProvider = FutureProvider.autoDispose<String>((ref) async {
  try {
    final p = await getPatientMe();
    return p.fullName ?? 'there';
  } catch (_) {
    return 'there';
  }
});

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadiusXXL),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Patient',
              style: TextStyle(
                fontSize: kFontSM,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down,
                size: 16,
                color: Theme.of(context).colorScheme.primary),
          ],
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
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(kRadiusLG),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_car),
            const SizedBox(width: kSpaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Ride',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(ride.status.displayLabel,
                      style: const TextStyle(
                          fontSize: kFontSM, color: kTextSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
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
