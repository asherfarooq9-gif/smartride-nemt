import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/date_format.dart';
import 'package:patient_app/driver/scheduled_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

core.RideResponse _ride(String id, String address, {String? hospital}) =>
    core.RideResponse.fromJson({
      'id': id,
      'patient_id': 'p',
      'ride_type': 'scheduled',
      'status': 'pending',
      'pickup_address': address,
      'pickup_lat': 33.7,
      'pickup_lng': 73.0,
      'scheduled_for':
          DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      'requested_at': '2026-11-05T10:00:00Z',
      if (hospital != null) 'hospital_name': hospital,
    });

class _Harness {
  _Harness({
    this.open = const [],
    this.mine = const [],
    this.claimError,
  });

  final List<core.RideResponse> open;
  final List<core.RideResponse> mine;
  final core.AppError? claimError;
  final claimed = <String>[];
  final released = <String>[];

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        openScheduledProvider.overrideWith((_) async => open),
        claimedScheduledProvider.overrideWith((_) async => mine),
        claimRideProvider.overrideWithValue((id) async {
          claimed.add(id);
          final error = claimError;
          if (error != null) throw error;
          return open.firstWhere((r) => r.id == id);
        }),
        releaseRideProvider.overrideWithValue((id) async {
          released.add(id);
          return mine.firstWhere((r) => r.id == id);
        }),
      ],
      child: const MaterialApp(home: DriverScheduledScreen()),
    ));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('open rides show where and when, with a Reserve button',
      (tester) async {
    final h = _Harness(open: [_ride('r1', 'G-9 Markaz', hospital: 'PIMS')]);
    await h.pump(tester);

    expect(find.text('G-9 Markaz'), findsOneWidget);
    expect(find.text('PIMS'), findsOneWidget);
    expect(find.text('Reserve this ride'), findsOneWidget);
  });

  testWidgets('tapping Reserve claims that ride and says so', (tester) async {
    final h = _Harness(open: [_ride('r1', 'G-9 Markaz')]);
    await h.pump(tester);

    await tester.tap(find.text('Reserve this ride'));
    await tester.pumpAndSettle();

    expect(h.claimed, ['r1']);
    expect(find.textContaining('Reserved.'), findsOneWidget);
  });

  testWidgets('a refused claim shows the server’s reason', (tester) async {
    final h = _Harness(
      open: [_ride('r1', 'G-9 Markaz')],
      claimError: const core.AppError(
        'This ride is no longer open to claim. Another driver may have it.',
        statusCode: 409,
      ),
    );
    await h.pump(tester);

    await tester.tap(find.text('Reserve this ride'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no longer open to claim'), findsOneWidget);
  });

  testWidgets('My rides lists reserved rides and lets the driver give one back',
      (tester) async {
    final h = _Harness(mine: [_ride('r2', 'F-8 Markaz')]);
    await h.pump(tester);

    await tester.tap(find.text('My rides'));
    await tester.pumpAndSettle();
    expect(find.text('F-8 Markaz'), findsOneWidget);
    await tester.tap(find.text('Give back'));
    await tester.pumpAndSettle();

    expect(h.released, ['r2']);
  });

  testWidgets('empty states say what to do', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.text('No open rides nearby'), findsOneWidget);

    await tester.tap(find.text('My rides'));
    await tester.pumpAndSettle();
    expect(find.text('No reserved rides'), findsOneWidget);
  });

  group('formatWhen', () {
    final now = DateTime(2026, 11, 5, 10);

    test('says Today and Tomorrow', () {
      expect(formatWhen(DateTime(2026, 11, 5, 16, 30), now: now),
          'Today · 4:30 PM');
      expect(
          formatWhen(DateTime(2026, 11, 6, 9), now: now), 'Tomorrow · 9:00 AM');
    });

    test('later days show the weekday and date', () {
      expect(formatWhen(DateTime(2026, 11, 9, 0, 5), now: now),
          'Mon 9 Nov · 12:05 AM');
    });
  });
}
