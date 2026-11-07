import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/rides/home_glass_card.dart';

/// Busy hours ahead for the signed-in driver. Re-read when the account changes.
final demandForecastProvider =
    FutureProvider.autoDispose<core.DemandForecast>((ref) async {
  ref.watch(sessionTokenProvider);
  try {
    return await core.getDemandForecast();
  } on core.AppError catch (e, st) {
    core.ErrorReporter.report('Could not load the demand forecast', e, st);
    rethrow;
  }
});

/// The forecast card, or nothing while it loads or if it cannot be loaded: it
/// is a hint for planning, never something the driver has to wait for.
class DriverDemandSection extends ConsumerWidget {
  const DriverDemandSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(demandForecastProvider).valueOrNull;
    if (forecast == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DemandForecastCard(forecast: forecast),
    );
  }
}

const Color _kHigh = Color(0xFF22A55A);
const Color _kMedium = Color(0xFFF59E0B);

/// "4 PM" for an hour, in the phone's own time zone.
String demandHourLabel(DateTime hour) {
  final local = hour.toLocal();
  final twelve = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$twelve ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// Which hours are expected to be busy, as a headline and one bar per hour.
class DemandForecastCard extends StatelessWidget {
  const DemandForecastCard({super.key, required this.forecast});

  final core.DemandForecast forecast;

  static const double _barMaxHeight = 40;
  static const double _barMinHeight = 6;

  String _headline(AppLocalizations l) {
    final busiest = forecast.busiest;
    if (!forecast.hasData) return l.demandNotEnough;
    if (busiest == null) return l.demandQuiet;
    return l.demandBusiest(demandHourLabel(busiest.hour));
  }

  String _detail(AppLocalizations l) =>
      forecast.hasData ? l.demandBasedOn : l.demandWhenRequests;

  Color _barColor(core.DemandLevel level, Color quiet) => switch (level) {
        core.DemandLevel.high => _kHigh,
        core.DemandLevel.medium => _kMedium,
        core.DemandLevel.low => quiet,
      };

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    final peak = forecast.busiest?.predictedRides ?? 0;
    return Semantics(
      label:
          '${context.l10n.demandAhead}. ${_headline(context.l10n)}. ${_detail(context.l10n)}',
      excludeSemantics: true,
      child: HomeGlassCard(
        radius: 16,
        isSeeThrough: true,
        child: Padding(
          padding: const EdgeInsets.all(core.kSpaceSM + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, size: 16, color: palette.muted),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.demandAhead,
                    style: TextStyle(fontSize: 11.5, color: palette.muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _headline(context.l10n),
                key: const ValueKey('demand-headline'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: palette.heading,
                ),
              ),
              Text(
                _detail(context.l10n),
                style: TextStyle(fontSize: 11.5, color: palette.muted),
              ),
              if (forecast.hours.isNotEmpty) ...[
                const SizedBox(height: core.kSpaceSM),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final hour in forecast.hours)
                      Expanded(
                        child: _Bar(
                          label: demandHourLabel(hour.hour),
                          height: peak <= 0
                              ? _barMinHeight
                              : _barMinHeight +
                                  (_barMaxHeight - _barMinHeight) *
                                      (hour.predictedRides / peak),
                          color: _barColor(
                            hour.level,
                            palette.muted.withValues(alpha: 0.45),
                          ),
                          labelColor: palette.muted,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.height,
    required this.color,
    required this.labelColor,
  });

  final String label;
  final double height;
  final Color color;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: height,
          width: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: TextStyle(fontSize: 10, color: labelColor)),
        ),
      ],
    );
  }
}
