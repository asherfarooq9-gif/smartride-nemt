import 'package:patient_app/core/ride_status_label.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/features/rides/rides_notifier.dart';

class ScheduledRidesScreen extends ConsumerWidget {
  const ScheduledRidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navMyRides)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/');
          if (i == 2) context.go('/profile');
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: context.l10n.navHome),
          NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: context.l10n.navMyRides),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: context.l10n.navProfile),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ridesProvider.notifier).refresh(),
        child: ridesAsync.when(
          loading: () => core.LoadingState(message: context.l10n.loadingRides),
          error: (e, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: core.ErrorState(
                message:
                    e is core.AppError ? e.message : context.l10n.failedToLoad,
                onRetry: () => ref.read(ridesProvider.notifier).refresh(),
              ),
            ),
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.6,
                  child: core.EmptyState(
                    message: context.l10n.noRidesYetDot,
                    icon: Icons.directions_car_outlined,
                  ),
                ),
              );
            }
            return ListView.builder(
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
                    subtitle: Text(rideStatusLabel(context.l10n, ride.status)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.push('/ride/${ride.id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
