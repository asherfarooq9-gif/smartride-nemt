import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/symptom_input_screen.dart';
import '../screens/tracking_screen.dart';
import '../screens/history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/scheduled_ride_screen.dart';
import '../screens/ride_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = auth.isLoggedIn;
      final isOnAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final isOnSplash = state.matchedLocation == '/splash';
      if (isOnSplash) return null;
      if (!isAuth && !isOnAuth) return '/login';
      if (isAuth && isOnAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/symptom', builder: (_, __) => const SymptomInputScreen()),
      GoRoute(path: '/tracking/:rideId', builder: (_, state) => TrackingScreen(rideId: state.pathParameters['rideId']!)),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/scheduled-ride', builder: (_, __) => const ScheduledRideScreen()),
      GoRoute(path: '/rides/:rideId', builder: (_, state) => RideDetailScreen(rideId: state.pathParameters['rideId']!)),
    ],
  );
});
