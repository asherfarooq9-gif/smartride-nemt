import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, FlutterError;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/core/router.dart';
import 'package:patient_app/core/error_reporting.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/core/notifications.dart';
import 'package:smartride_core/smartride_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isCrashlyticsReady = await _initCrashReporting();
  _installGlobalErrorHandlers(isCrashlyticsReady: isCrashlyticsReady);
  installFriendlyErrorWidget();

  await _loadEnv();
  if (!_isConfigurationValid()) {
    runApp(const _ConfigErrorApp());
    return;
  }
  runApp(const ProviderScope(
    observers: [ErrorReportingObserver()],
    child: SmartRideApp(),
  ));
}

/// Crashlytics needs Firebase before any error can be recorded. Init can
/// fail (web, missing config) — the app must still boot, falling back to
/// local-only logging.
Future<bool> _initCrashReporting() async {
  if (kIsWeb) return false;
  try {
    await Firebase.initializeApp();
    ErrorReporter.sink = (context, error, stack) => unawaited(
          FirebaseCrashlytics.instance
              .recordError(error, stack, reason: context),
        );
    return true;
  } on Object catch (e, st) {
    developer.log('Firebase unavailable; crash reporting is local only',
        name: 'smartride.crash', error: e, stackTrace: st);
    return false;
  }
}

/// Without these, a release-mode crash is a silent blank screen.
void _installGlobalErrorHandlers({required bool isCrashlyticsReady}) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'Unhandled Flutter error',
      name: 'smartride.crash',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (isCrashlyticsReady) {
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
    if (isCrashlyticsReady) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };
}

/// Never let env loading block the first frame. A missing .env is fine in
/// debug (ApiClient falls back to a local URL) and fatal in release, which
/// [_isConfigurationValid] catches.
Future<void> _loadEnv() async {
  try {
    await dotenv.load();
  } on Exception catch (e, st) {
    ErrorReporter.report('.env could not be loaded', e, st);
  }
}

/// A release build without an https API_BASE_URL must stop here rather than
/// quietly target the emulator host.
bool _isConfigurationValid() {
  try {
    ApiClient.instance;
    return true;
  } on StateError catch (e, st) {
    ErrorReporter.report('Invalid app configuration', e, st);
    return false;
  }
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'SmartRide is not set up correctly on this device. '
                'Please update or reinstall the app.'
                '\n\nIf this is an emergency, call 1122.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, height: 1.4),
              ),
            ),
          ),
        ),
      );
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
      initNotifications(router: router).catchError(
        (Object e, StackTrace st) =>
            ErrorReporter.report('Push notifications failed to start', e, st),
      );
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
      themeMode: ref.watch(effectiveThemeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
