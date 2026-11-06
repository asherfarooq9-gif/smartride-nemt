import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/driver/profile_screen.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:smartride_core/smartride_core.dart' as core;

Future<void> _pump(WidgetTester tester, List<String> methods) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final driver = core.DriverResponse.fromJson({
    'id': 'd1',
    'phone': '+923001234567',
    'status': 'offline',
    'full_name': 'Ali Raza',
    'license_no': 'LHR-1234',
    'vehicle_type': 'Toyota Hiace',
    'vehicle_plate': 'ABC-123',
    'payment_methods': methods,
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [driverProfileProvider.overrideWith((_) async => driver)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const DriverProfileScreen()),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reading the profile shows the saved details', (tester) async {
    await _pump(tester, ['cash']);

    expect(find.text('Ali Raza'), findsOneWidget);
    expect(find.text('LHR-1234'), findsOneWidget);
    expect(find.text('Toyota Hiace'), findsOneWidget);
    expect(find.text('ABC-123'), findsOneWidget);
  });

  testWidgets('reading shows only the payment methods the driver accepts',
      (tester) async {
    await _pump(tester, ['cash', 'jazzcash']);

    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('JazzCash'), findsOneWidget);
    expect(find.text('Easypaisa'), findsNothing);
  });

  testWidgets('a driver with no methods set sees a plain note', (tester) async {
    await _pump(tester, []);

    expect(find.text('Not set yet'), findsOneWidget);
  });

  testWidgets('editing offers every method to choose from', (tester) async {
    await _pump(tester, ['cash']);

    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.byType(FilterChip), findsNWidgets(4));
    expect(find.text('Ali Raza'), findsOneWidget);
  });
}
