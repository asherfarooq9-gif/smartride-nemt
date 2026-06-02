import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers.dart';
// Auth
import '../features/auth/welcome_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/add_role_screen.dart';
// Patient portal
import '../features/rides/home_screen.dart';
import '../features/rides/symptom_screen.dart';
import '../features/rides/ride_detail_screen.dart';
import '../features/rides/live_tracking_screen.dart';
import '../features/rides/scheduled_rides_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
// Driver portal
import '../driver/dashboard_screen.dart';
import '../driver/active_ride_screen.dart';
import '../driver/profile_screen.dart';
import '../driver/settings_screen.dart';

const _authPages = {'/welcome', '/login', '/signup'};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isLoggedIn = auth.whenOrNull(data: (t) => t != null) ?? false;
      final isLoading = auth is AsyncLoading;
      final loc = state.matchedLocation;

      if (isLoading) return null;

      if (!isLoggedIn) {
        return _authPages.contains(loc) ? null : '/welcome';
      }
      // Logged in but sitting on an auth page → drop into the active portal.
      if (_authPages.contains(loc)) {
        return ref.read(activeRoleProvider) == 'driver' ? '/driver' : '/';
      }
      return null;
    },
    refreshListenable: _AuthListenable(ref),
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/become-driver',
        builder: (_, __) => const AddRoleScreen(role: 'driver'),
      ),
      GoRoute(
        path: '/become-patient',
        builder: (_, __) => const AddRoleScreen(role: 'patient'),
      ),

      // ── Patient portal ────────────────────────────────────────────────
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/symptoms', builder: (_, __) => const SymptomScreen()),
      GoRoute(path: '/rides', builder: (_, __) => const ScheduledRidesScreen()),
      GoRoute(
        path: '/ride/:id',
        builder: (_, s) => RideDetailScreen(rideId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tracking/:id',
        builder: (_, s) => LiveTrackingScreen(rideId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),

      // ── Driver portal ─────────────────────────────────────────────────
      GoRoute(path: '/driver', builder: (_, __) => const DashboardScreen()),
      GoRoute(
        path: '/driver/ride/:id',
        builder: (_, s) => ActiveRideScreen(rideId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/driver/profile',
        builder: (_, __) => const DriverProfileScreen(),
      ),
      GoRoute(
        path: '/driver/settings',
        builder: (_, __) => const DriverSettingsScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(activeRoleProvider, (_, __) => notifyListeners());
  }
}
