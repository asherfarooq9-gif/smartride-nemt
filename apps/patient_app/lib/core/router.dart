import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/providers.dart';
// Auth
import 'package:patient_app/features/auth/welcome_screen.dart';
import 'package:patient_app/features/auth/login_screen.dart';
import 'package:patient_app/features/auth/signup_screen.dart';
import 'package:patient_app/features/auth/add_role_screen.dart';
// Patient portal
import 'package:patient_app/features/rides/home_screen.dart';
import 'package:patient_app/features/rides/symptom_screen.dart';
import 'package:patient_app/features/rides/dispatching_screen.dart';
import 'package:patient_app/features/rides/ride_detail_screen.dart';
import 'package:patient_app/features/rides/live_tracking_screen.dart';
import 'package:patient_app/features/rides/scheduled_rides_screen.dart';
import 'package:patient_app/features/rides/schedule_trip_screen.dart';
import 'package:patient_app/features/rides/map_picker_screen.dart';
import 'package:patient_app/features/rides/booking_confirmed_screen.dart';
import 'package:patient_app/features/profile/profile_screen.dart';
import 'package:patient_app/features/settings/settings_screen.dart';
import 'package:patient_app/features/support/support_screen.dart';
// Driver portal
import 'package:patient_app/driver/dashboard_screen.dart';
import 'package:patient_app/driver/active_ride_screen.dart';
import 'package:patient_app/driver/earnings_screen.dart';
import 'package:patient_app/driver/profile_screen.dart';
import 'package:patient_app/driver/settings_screen.dart';
import 'package:patient_app/driver/wallet_screen.dart';
import 'package:patient_app/driver/top_up_screen.dart';
import 'package:patient_app/driver/history_screen.dart';
import 'package:patient_app/features/rides/notifications_screen.dart';
import 'package:patient_app/features/profile/saved_places_screen.dart';
import 'package:patient_app/features/rides/system_states_screen.dart';
import 'package:patient_app/features/rides/rate_driver_screen.dart';

const _authPages = {'/welcome', '/login', '/signup'};

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthListenable(ref);
  // Close the auth subscriptions if this provider is ever invalidated,
  // otherwise they would outlive the router and leak.
  ref.onDispose(authListenable.dispose);
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
      if (_authPages.contains(loc)) {
        return ref.read(activeRoleProvider) == 'driver' ? '/driver' : '/';
      }
      // Role guard: driver routes require the driver role. Without this, any
      // logged-in patient could deep-link straight into the driver portal.
      if (loc.startsWith('/driver') &&
          !ref.read(rolesProvider).contains('driver')) {
        return '/';
      }
      return null;
    },
    refreshListenable: authListenable,
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login',   builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup',  builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/become-driver',
        builder: (_, __) => const AddRoleScreen(role: 'driver'),
      ),
      GoRoute(
        path: '/become-patient',
        builder: (_, __) => const AddRoleScreen(role: 'patient'),
      ),

      // ── Patient portal ────────────────────────────────────────────────────
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/symptoms', builder: (_, __) => const SymptomScreen()),
      GoRoute(
        path: '/dispatching/:id',
        builder: (_, s) => DispatchingScreen(rideId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/rides', builder: (_, __) => const ScheduledRidesScreen()),
      GoRoute(
        path: '/ride/:id',
        builder: (_, s) => RideDetailScreen(rideId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tracking/:id',
        builder: (_, s) => LiveTrackingScreen(rideId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/book-ride', builder: (_, __) => const ScheduleTripScreen()),
      GoRoute(path: '/map-picker', builder: (_, __) => const MapPickerScreen()),
      GoRoute(
        path: '/booking-confirmed/:id',
        builder: (_, s) =>
            BookingConfirmedScreen(rideId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/profile',  builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/help',     builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/contact',  builder: (_, __) => const ContactScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen(portal: 'patient')),
      GoRoute(path: '/saved-places', builder: (_, __) => const SavedPlacesScreen()),
      GoRoute(path: '/permissions', builder: (_, __) => const PermissionsScreen()),
      GoRoute(path: '/no-drivers', builder: (_, __) => const NoDriversScreen()),
      GoRoute(path: '/no-internet', builder: (_, __) => const NoInternetScreen()),
      GoRoute(
        path: '/rate-driver/:id',
        builder: (_, s) => RateDriverScreen(rideId: s.pathParameters['id']!),
      ),

      // ── Driver portal ─────────────────────────────────────────────────────
      GoRoute(path: '/driver', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/driver/earnings', builder: (_, __) => const EarningsScreen()),
      GoRoute(path: '/driver/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/driver/top-up', builder: (_, __) => const TopUpScreen()),
      GoRoute(path: '/driver/notifications', builder: (_, __) => const NotificationsScreen(portal: 'driver')),
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
      GoRoute(
        path: '/driver/history',
        builder: (_, __) => const DriverHistoryScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    _subs = [
      ref.listen(authProvider, (_, __) => notifyListeners()),
      ref.listen(activeRoleProvider, (_, __) => notifyListeners()),
    ];
  }

  late final List<ProviderSubscription<dynamic>> _subs;

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.close();
    }
    super.dispose();
  }
}
