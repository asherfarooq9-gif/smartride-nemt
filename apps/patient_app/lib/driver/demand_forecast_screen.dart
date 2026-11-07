import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/driver/driver_demand_card.dart';

/// Busy hours ahead, from the server's own history. Shows nothing invented:
/// an empty or failed forecast says so.
class DemandForecastScreen extends ConsumerWidget {
  const DemandForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(demandForecastProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.demandForecastTitle)),
      body: forecast.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.couldNotLoadForecast),
              TextButton(
                onPressed: () => ref.invalidate(demandForecastProvider),
                child: Text(context.l10n.tryAgain),
              ),
            ],
          ),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [DemandForecastCard(forecast: data)],
        ),
      ),
    );
  }
}
