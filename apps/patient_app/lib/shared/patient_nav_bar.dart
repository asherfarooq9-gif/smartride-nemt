import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/shared/glass_surface.dart';

/// The patient tab bar: Home, My Rides and Profile.
///
/// With [glass] the bar floats above the content as a frosted, fully rounded
/// pill with a margin around it, for screens (like Home) whose map continues
/// behind it. Pair it with `extendBody: true`. Changing tab gives a light
/// haptic tick.
class PatientNavBar extends StatelessWidget {
  const PatientNavBar({
    super.key,
    required this.currentIndex,
    this.glass = false,
  });

  final int currentIndex;
  final bool glass;

  static const _routes = ['/', '/rides', '/profile'];

  void _select(BuildContext context, int index) {
    if (index == currentIndex) return;
    HapticFeedback.selectionClick();
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bar = NavigationBar(
      selectedIndex: currentIndex,
      backgroundColor: glass ? Colors.transparent : null,
      indicatorColor: scheme.primaryContainer,
      onDestinationSelected: (i) => _select(context, i),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kSpaceLG,
          0,
          kSpaceLG,
          kSpaceSM,
        ),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(kRadiusSheet),
          child: bar,
        ),
      ),
    );
  }
}
