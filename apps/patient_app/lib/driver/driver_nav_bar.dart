import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/shared/glass_surface.dart';

/// The driver tab bar: Home, Earnings and Profile, in the same frosted bar as
/// the patient's. Home is the dashboard itself; the other two open on top of it,
/// as they always have, so Back returns to the dashboard.
class DriverNavBar extends StatelessWidget {
  const DriverNavBar({super.key});

  static const _routes = ['/driver', '/driver/earnings', '/driver/profile'];

  void _select(BuildContext context, int index) {
    if (index == 0) return; // already home
    HapticFeedback.selectionClick();
    context.push(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: 0,
          backgroundColor: Colors.transparent,
          height: 60,
          elevation: 0,
          indicatorColor: scheme.primaryContainer,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
          onDestinationSelected: (i) => _select(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Earnings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
