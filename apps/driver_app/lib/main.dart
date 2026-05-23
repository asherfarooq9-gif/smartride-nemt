import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/auth/auth_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  ApiClient.setUnauthorizedHandler(() {
    container.read(authNotifierProvider.notifier).logout();
  });
  runApp(UncontrolledProviderScope(
    container: container,
    child: const SmartRideDriverApp(),
  ));
}

class SmartRideDriverApp extends ConsumerWidget {
  const SmartRideDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SmartRide Driver',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
