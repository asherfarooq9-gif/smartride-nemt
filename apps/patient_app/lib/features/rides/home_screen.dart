import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:patient_app/features/rides/home_top_bar.dart';
import 'package:patient_app/features/rides/home_sheet.dart';
import 'package:patient_app/shared/pale_map_tiles.dart';
import 'package:patient_app/shared/role_switcher.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            children: [paleTileLayer()],
          ),
          Builder(
            builder: (ctx) => HomeTopBar(
              onMenu: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const HomeSheet(),
        ],
      ),
      bottomNavigationBar: const _PatientBottomNav(currentIndex: 0),
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
