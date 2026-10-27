import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/shared/glass_surface.dart';

/// The patient tab bar: Home, My Rides and Profile.
///
/// With [glass] the bar is see-through and frosted, for screens (like Home)
/// whose map or content continues behind it. Pair it with `extendBody: true`.
class PatientNavBar extends StatelessWidget {
  const PatientNavBar({
    super.key,
    required this.currentIndex,
    this.glass = false,
  });

  final int currentIndex;
  final bool glass;

  static const _routes = ['/', '/rides', '/profile'];

  @override
  Widget build(BuildContext context) {
    final bar = NavigationBar(
      selectedIndex: currentIndex,
      backgroundColor: glass ? Colors.transparent : null,
      onDestinationSelected: (i) => context.go(_routes[i]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history_rounded),
          label: 'My Rides',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );

    if (!glass) return bar;
    return GlassSurface(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(kRadiusSheet),
      ),
      child: bar,
    );
  }
}
