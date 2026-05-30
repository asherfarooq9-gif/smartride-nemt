import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers.dart';
import '../features/auth/login_screen.dart';
import '../features/rides/home_screen.dart';
import '../features/rides/symptom_screen.dart';
import '../features/rides/ride_detail_screen.dart';
import '../features/rides/live_tracking_screen.dart';
import '../features/rides/scheduled_rides_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final auth = ref.read(authProvider);
      final isLoggedIn = auth.whenOrNull(data: (t) => t != null) ?? false;
      final isLoading = auth is AsyncLoading;

      if (isLoading) return null;
      if (!isLoggedIn && state.matchedLocation != '/login') return '/login';
      if (isLoggedIn && state.matchedLocation == '/login') return '/';
      return null;
    },
    refreshListenable: _AuthListenable(ref),
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/symptoms',
        builder: (_, __) => const SymptomScreen(),
      ),
      GoRoute(
        path: '/rides',
        builder: (_, __) => const ScheduledRidesScreen(),
      ),
      GoRoute(
        path: '/ride/:id',
        builder: (_, state) => RideDetailScreen(rideId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tracking/:id',
        builder: (_, state) =>
            LiveTrackingScreen(rideId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
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
  }
}
