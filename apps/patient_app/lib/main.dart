import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/notifications.dart';
import 'package:smartride_core/smartride_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const ProviderScope(child: PatientApp()));
}

class PatientApp extends ConsumerStatefulWidget {
  const PatientApp({super.key});

  @override
  ConsumerState<PatientApp> createState() => _PatientAppState();
}

class _PatientAppState extends ConsumerState<PatientApp> {
  @override
  void initState() {
    super.initState();
    final router = ref.read(routerProvider);
    initNotifications(router: router);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SmartRide',
      theme: AppTheme.patient(),
      darkTheme: AppTheme.patient(dark: true),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
