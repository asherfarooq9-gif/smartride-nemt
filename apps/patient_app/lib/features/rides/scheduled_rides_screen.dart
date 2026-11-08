import 'package:patient_app/core/ride_status_label.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:patient_app/shared/apple_list.dart';
import 'package:patient_app/shared/patient_nav_bar.dart';

class ScheduledRidesScreen extends ConsumerWidget {
  const ScheduledRidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navMyRides)),
      bottomNavigationBar: const PatientNavBar(currentIndex: 1),
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
            return ListView(
              // Always scrollable so pull-to-refresh works on a short list.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: core.kSpaceXXL),
              children: [
                AppleSection(
                  dividerIndent: appleIconDividerIndent,
                  children: [
                    for (final ride in data.items)
                      AppleRow(
                        icon: ride.rideType == core.RideType.emergency
                            ? Icons.emergency
                            : Icons.calendar_today,
                        iconColor: ride.rideType == core.RideType.emergency
                            ? core.kEmergencyRed
                            : null,
                        title: ride.pickupAddress,
                        subtitle: rideStatusLabel(context.l10n, ride.status),
                        onTap: () => context.push('/ride/${ride.id}'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
