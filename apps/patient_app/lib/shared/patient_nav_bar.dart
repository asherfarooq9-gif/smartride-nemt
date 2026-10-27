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
      // A compact bar: the glass variant would otherwise be a tall Material one.
      height: glass ? 60 : null,
      elevation: 0,
      labelTextStyle: glass
          ? WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 12,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            )
          : null,
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
    // Full width with rounded top corners, sitting on the bottom edge; the
    // frosted panel runs down under the system gesture area.
    return GlassSurface(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(kRadiusSheet),
      ),
      sigma: 24,
      opacity: 0.82,
      borderColor: scheme.brightness == Brightness.dark
          ? null
          : Colors.white.withValues(alpha: 0.85),
      borderWidth: 1,
      shadows: kSheetShadow,
      child: SafeArea(top: false, child: bar),
    );
  }
}
