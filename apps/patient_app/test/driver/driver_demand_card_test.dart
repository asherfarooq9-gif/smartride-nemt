import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/driver_demand_card.dart';
import 'package:smartride_core/smartride_core.dart' as core;

// Local times, so the labels read the same in any time zone.
core.DemandHour _hour(int localHour, double rides, core.DemandLevel level) =>
    core.DemandHour(
      hour: DateTime(2026, 10, 30, localHour).toUtc(),
      predictedRides: rides,
      level: level,
    );

Widget _card(core.DemandForecast forecast) => MaterialApp(
      home: Scaffold(body: DemandForecastCard(forecast: forecast)),
    );

Widget _section(Future<core.DemandForecast> Function() load) => ProviderScope(
      overrides: [demandForecastProvider.overrideWith((ref) => load())],
      child: const MaterialApp(home: Scaffold(body: DriverDemandSection())),
    );

void main() {
  group('demandHourLabel', () {
    test('reads on a 12 hour clock', () {
      expect(demandHourLabel(DateTime(2026, 10, 30, 0).toUtc()), '12 AM');
      expect(demandHourLabel(DateTime(2026, 10, 30, 9).toUtc()), '9 AM');
      expect(demandHourLabel(DateTime(2026, 10, 30, 12).toUtc()), '12 PM');
      expect(demandHourLabel(DateTime(2026, 10, 30, 15).toUtc()), '3 PM');
      expect(demandHourLabel(DateTime(2026, 10, 30, 23).toUtc()), '11 PM');
    });
  });

  group('DemandForecastCard', () {
    testWidgets('names the busiest hour and draws one bar per hour',
        (tester) async {
      await tester.pumpWidget(_card(core.DemandForecast(
        hasData: true,
        hours: [
          _hour(16, 1.0, core.DemandLevel.high),
          _hour(17, 0.7, core.DemandLevel.medium),
          _hour(18, 0.0, core.DemandLevel.low),
        ],
      )));

      expect(find.text('Busiest around 4 PM'), findsOneWidget);
      expect(find.text('4 PM'), findsOneWidget);
      expect(find.text('5 PM'), findsOneWidget);
      expect(find.text('6 PM'), findsOneWidget);
      expect(find.text('Based on ride requests over the last 4 weeks'),
          findsOneWidget);
    });

    testWidgets('says there is not enough history when there is no data',
        (tester) async {
      await tester.pumpWidget(_card(core.DemandForecast(
        hasData: false,
        hours: [_hour(16, 0, core.DemandLevel.low)],
      )));

      expect(find.text('Not enough history yet'), findsOneWidget);
      expect(find.textContaining('Busiest'), findsNothing);
    });

    testWidgets('says it is quiet when no ride is expected soon',
        (tester) async {
      await tester.pumpWidget(_card(core.DemandForecast(
        hasData: true,
        hours: [_hour(16, 0, core.DemandLevel.low)],
      )));

      expect(find.text('Quiet for the next few hours'), findsOneWidget);
    });

    testWidgets('the busiest bar is taller than a quiet one', (tester) async {
      await tester.pumpWidget(_card(core.DemandForecast(
        hasData: true,
        hours: [
          _hour(16, 2.0, core.DemandLevel.high),
          _hour(17, 0.5, core.DemandLevel.low),
        ],
      )));

      final bars = tester
          .widgetList<Container>(find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxWidth == 14,
          ))
          .toList();
      expect(bars, hasLength(2));
      expect(bars.first.constraints!.maxHeight,
          greaterThan(bars.last.constraints!.maxHeight));
    });

    testWidgets('describes itself for screen readers', (tester) async {
      await tester.pumpWidget(_card(core.DemandForecast(
        hasData: true,
        hours: [_hour(16, 1.0, core.DemandLevel.high)],
      )));

      expect(
        find.bySemanticsLabel(RegExp('Demand ahead. Busiest around 4 PM')),
        findsOneWidget,
      );
    });
  });

  group('DriverDemandSection', () {
    testWidgets('shows the card once the forecast arrives', (tester) async {
      await tester.pumpWidget(_section(() async => core.DemandForecast(
            hasData: true,
            hours: [_hour(16, 1.0, core.DemandLevel.high)],
          )));
      await tester.pumpAndSettle();

      expect(find.byType(DemandForecastCard), findsOneWidget);
    });

    testWidgets('shows nothing while it loads', (tester) async {
      final never = Completer<core.DemandForecast>();
      await tester.pumpWidget(_section(() => never.future));
      await tester.pump();

      expect(find.byType(DemandForecastCard), findsNothing);
    });

    testWidgets('shows nothing, and does not break, when it fails',
        (tester) async {
      await tester.pumpWidget(
        _section(() async => throw const core.AppError('offline')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DemandForecastCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
