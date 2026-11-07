import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/rides/ride_detail_screen.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:smartride_core/smartride_core.dart' as core;

core.RideDetailResponse _ride({double? rating, Object? finalFare = 281.05}) =>
    core.RideDetailResponse.fromJson({
      'id': 'r1',
      'patient_id': 'p1',
      'ride_type': 'emergency',
      'status': 'completed',
      'pickup_address': 'F-8 Markaz, Islamabad',
      'pickup_lat': 33.69,
      'pickup_lng': 73.05,
      'requested_at': '2026-11-06T10:00:00Z',
      'final_fare_pkr': finalFare,
      'patient_rating': rating,
      'driver': {
        'full_name': 'Ali Raza',
        'phone': '+923001234567',
        'vehicle_plate': 'ABC-123',
        'vehicle_type': 'sedan',
        'payment_methods': ['cash', 'easypaisa'],
      },
    });

Future<void> _pump(WidgetTester tester, core.RideDetailResponse ride) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [rideDetailProvider('r1').overrideWith((_) async => ride)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const RideDetailScreen(rideId: 'r1'),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a completed ride shows what it cost and how to pay',
      (tester) async {
    await _pump(tester, _ride());

    expect(find.textContaining('281'), findsOneWidget);
    expect(find.textContaining('Pay your driver directly'), findsOneWidget);
    expect(find.textContaining('Pays by: Cash · Easypaisa'), findsOneWidget);
  });

  testWidgets('a completed, unrated ride offers to rate the driver',
      (tester) async {
    await _pump(tester, _ride());

    expect(find.text('Rate your driver'), findsOneWidget);
  });

  testWidgets('a ride that is already rated does not ask again',
      (tester) async {
    await _pump(tester, _ride(rating: 5));

    expect(find.text('Rate your driver'), findsNothing);
  });
}
