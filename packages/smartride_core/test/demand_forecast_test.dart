import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

Map<String, dynamic> _json({
  bool hasData = true,
  List<Map<String, dynamic>>? forecast,
}) =>
    {
      'generated_at': '2026-10-30T10:00:00Z',
      'method': 'hourly_average_28d',
      'has_data': hasData,
      'forecast': forecast ??
          [
            {'hour': '2026-10-30T11:00:00Z', 'predicted_rides': 1.0, 'level': 'high'},
            {'hour': '2026-10-30T12:00:00Z', 'predicted_rides': 0.7, 'level': 'medium'},
            {'hour': '2026-10-30T13:00:00Z', 'predicted_rides': 0, 'level': 'low'},
          ],
    };

void main() {
  group('DemandForecast.fromJson', () {
    test('reads the hours, their predicted rides and levels', () {
      final forecast = DemandForecast.fromJson(_json());

      expect(forecast.hasData, isTrue);
      expect(forecast.hours, hasLength(3));
      expect(forecast.hours.first.hour, DateTime.utc(2026, 10, 30, 11));
      expect(forecast.hours.first.predictedRides, 1.0);
      expect(forecast.hours.first.level, DemandLevel.high);
      expect(forecast.hours[1].level, DemandLevel.medium);
    });

    test('a whole number of rides is still read as a decimal', () {
      final forecast = DemandForecast.fromJson(_json());

      expect(forecast.hours.last.predictedRides, 0.0);
    });

    test('an unknown level is treated as low, not a crash', () {
      final forecast = DemandForecast.fromJson(_json(forecast: [
        {'hour': '2026-10-30T11:00:00Z', 'predicted_rides': 2.0, 'level': 'wild'},
      ]));

      expect(forecast.hours.single.level, DemandLevel.low);
    });
  });

  group('DemandForecast.busiest', () {
    test('is the hour with the most predicted rides', () {
      final forecast = DemandForecast.fromJson(_json());

      expect(forecast.busiest?.hour, DateTime.utc(2026, 10, 30, 11));
    });

    test('is null when no ride is predicted in any hour', () {
      final forecast = DemandForecast.fromJson(_json(
        hasData: false,
        forecast: [
          {'hour': '2026-10-30T11:00:00Z', 'predicted_rides': 0, 'level': 'low'},
        ],
      ));

      expect(forecast.busiest, isNull);
    });

    test('is null for an empty forecast', () {
      expect(DemandForecast.fromJson(_json(forecast: [])).busiest, isNull);
    });
  });
}
