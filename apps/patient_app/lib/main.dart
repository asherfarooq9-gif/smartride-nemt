import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/auth/auth_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // Wire 401 responses → logout so the router redirects to /login
  ApiClient.setUnauthorizedHandler(() {
    container.read(authNotifierProvider.notifier).logout();
  });
  runApp(UncontrolledProviderScope(
    container: container,
    child: const SmartRidePatientApp(),
  ));
}

class SmartRidePatientApp extends ConsumerWidget {
  const SmartRidePatientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SmartRide Patient',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
