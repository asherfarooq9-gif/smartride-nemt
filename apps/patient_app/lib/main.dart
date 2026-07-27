import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, FlutterError;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/core/connectivity.dart';
import 'package:patient_app/core/pending_ride_queue.dart';
import 'package:patient_app/core/router.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/core/notifications.dart';
import 'package:patient_app/shared/offline_banner.dart';
import 'package:smartride_core/smartride_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crashlytics needs Firebase before any error can be recorded. Init can
  // fail (web, missing config) — the app must still boot, falling back to
  // local-only logging.
  var crashlyticsReady = false;
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      crashlyticsReady = true;
    } catch (_) {}
  }

  // Global error capture: without these, a release-mode crash is a silent
  // blank screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'Unhandled Flutter error',
      name: 'smartride.crash',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (crashlyticsReady) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    developer.log(
      'Unhandled platform error',
      name: 'smartride.crash',
      error: error,
      stackTrace: stack,
    );
    if (crashlyticsReady) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

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
  bool? _wasOnline;

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

    // Drain any queued scheduled-ride booking the moment connectivity comes
    // back — not on every rebuild while online, so this only fires on the
    // offline -> online transition.
    ref.listen(connectivityProvider, (previous, next) {
      final isOnline = next.valueOrNull ?? true;
      if (isOnline && _wasOnline == false) {
        PendingRideQueue.instance.drain();
      }
      _wasOnline = isOnline;
    });

    return MaterialApp.router(
      title: 'SmartRide',
      theme: isDriver ? AppTheme.driver() : AppTheme.patient(),
      darkTheme: isDriver ? AppTheme.driver(dark: true) : AppTheme.patient(dark: true),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
