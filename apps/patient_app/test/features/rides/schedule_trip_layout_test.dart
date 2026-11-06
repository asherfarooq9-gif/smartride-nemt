import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/rides/schedule_trip_screen.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:smartride_core/smartride_core.dart' as core;

void main() {
  testWidgets('the booking form fits a narrow phone with a long hospital name',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hospital = core.HospitalResponse.fromJson({
      'id': 'h1',
      'name': 'Pakistan Institute of Medical Sciences Children Hospital',
      'address': 'G-8, Islamabad',
      'lat': 33.7,
      'lng': 73.0,
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        scheduleHospitalsProvider.overrideWith((_) async => [hospital]),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const ScheduleTripScreen(),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // An overflow is reported as a framework exception.
    expect(tester.takeException(), isNull);
  });
}
