import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/providers.dart';
import 'core/notifications.dart';
import 'package:smartride_core/smartride_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never let env loading block the first frame.
  try {
    await dotenv.load();
  } catch (_) {
    // Fall back to compile-time defaults / API_BASE_URL default in ApiClient.
  }
  runApp(const ProviderScope(child: SmartRideApp()));
}

class SmartRideApp extends ConsumerStatefulWidget {
  const SmartRideApp({super.key});

  @override
  ConsumerState<SmartRideApp> createState() => _SmartRideAppState();
}

class _SmartRideAppState extends ConsumerState<SmartRideApp> {
  @override
  void initState() {
    super.initState();
    // Firebase/FCM is mobile-only; skip on web and never let it crash startup.
    if (!kIsWeb) {
      final router = ref.read(routerProvider);
      initNotifications(router: router).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // Theme follows the active portal: blue for patient, teal for driver.
    final isDriver = ref.watch(activeRoleProvider) == 'driver';
    return MaterialApp.router(
      title: 'SmartRide',
      theme: isDriver ? AppTheme.driver() : AppTheme.patient(),
      darkTheme: isDriver ? AppTheme.driver(dark: true) : AppTheme.patient(dark: true),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
