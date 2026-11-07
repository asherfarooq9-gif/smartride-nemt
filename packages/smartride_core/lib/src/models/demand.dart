/// How busy an hour is expected to be, relative to the busiest hour of the day.
enum DemandLevel { low, medium, high }

/// One hour of GET /drivers/demand-forecast.
class DemandHour {
  const DemandHour({
    required this.hour,
    required this.predictedRides,
    required this.level,
  });

  /// Start of the hour, in UTC.
  final DateTime hour;
  final double predictedRides;
  final DemandLevel level;

  factory DemandHour.fromJson(Map<String, dynamic> json) {
    return DemandHour(
      hour: DateTime.parse(json['hour'] as String),
      predictedRides: (json['predicted_rides'] as num).toDouble(),
      level: DemandLevel.values.firstWhere(
        (level) => level.name == json['level'],
        orElse: () => DemandLevel.low,
      ),
    );
  }
}

/// Mirrors GET /drivers/demand-forecast: busy hours ahead for a driver.
class DemandForecast {
  const DemandForecast({required this.hasData, required this.hours});

  /// False while there are no past rides to learn from.
  final bool hasData;
  final List<DemandHour> hours;

  /// The hour with the most predicted rides, or null when none is predicted.
  DemandHour? get busiest {
    DemandHour? best;
    for (final hour in hours) {
      if (hour.predictedRides > 0 &&
          (best == null || hour.predictedRides > best.predictedRides)) {
        best = hour;
      }
    }
    return best;
  }

  factory DemandForecast.fromJson(Map<String, dynamic> json) {
    final rawHours = json['forecast'];
    return DemandForecast(
      hasData: json['has_data'] as bool? ?? false,
      hours: rawHours is List
          ? rawHours
              .map((e) => DemandHour.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }
}
