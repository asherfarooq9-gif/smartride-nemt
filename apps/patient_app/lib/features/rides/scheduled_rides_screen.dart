import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'rides_notifier.dart';

class ScheduledRidesScreen extends ConsumerWidget {
  const ScheduledRidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: ridesAsync.when(
        loading: () => const core.LoadingState(message: 'Loading rides...'),
        error: (e, _) => core.ErrorState(
          message: e is core.AppError ? e.message : 'Failed to load',
          onRetry: () => ref.read(ridesProvider.notifier).refresh(),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const core.EmptyState(
              message: 'No rides yet.',
              icon: Icons.directions_car_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(ridesProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(core.kSpaceLG),
              itemCount: data.items.length,
              itemBuilder: (context, i) {
                final ride = data.items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: core.kSpaceSM),
                  child: ListTile(
                    leading: Icon(
                      ride.rideType == core.RideType.emergency
                          ? Icons.emergency
                          : Icons.calendar_today,
                      color: ride.rideType == core.RideType.emergency
                          ? core.kEmergencyRed
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      ride.pickupAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(ride.status.displayLabel),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/ride/${ride.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
