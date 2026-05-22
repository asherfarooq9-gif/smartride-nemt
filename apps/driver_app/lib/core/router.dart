import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/active_ride_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/ride_history_screen.dart';
import '../screens/earnings_screen.dart';
import '../screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = auth.isLoggedIn;
      final isOnLogin = state.matchedLocation == '/login';
      if (!isAuth && !isOnLogin) return '/login';
      if (isAuth && isOnLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/ride/:rideId',
        builder: (_, state) => ActiveRideScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/history', builder: (_, __) => const RideHistoryScreen()),
      GoRoute(path: '/earnings', builder: (_, __) => const EarningsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
