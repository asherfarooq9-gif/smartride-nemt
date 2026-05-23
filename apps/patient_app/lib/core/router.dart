import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_notifier.dart';
import '../features/auth/login_screen.dart';
import '../features/rides/home_screen.dart';
import '../features/rides/ride_detail_screen.dart';
import '../features/rides/scheduled_rides_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'ride/:id',
            builder: (_, state) =>
                RideDetailScreen(rideId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'rides',
            builder: (_, __) => const ScheduledRidesScreen(),
          ),
          GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
