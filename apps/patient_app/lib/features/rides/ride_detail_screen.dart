import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final _rideDetailProvider = FutureProvider.autoDispose
    .family<core.RideDetailResponse, String>(
  (ref, id) => core.getRideDetail(id),
);

class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(_rideDetailProvider(rideId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: rideAsync.when(
        loading: () => const core.LoadingState(),
        error: (e, _) => core.ErrorState(
          message: e is core.AppError ? e.message : 'Failed to load ride',
          onRetry: () => ref.refresh(_rideDetailProvider(rideId)),
        ),
        data: (ride) => SingleChildScrollView(
          padding: const EdgeInsets.all(core.kSpaceLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusBadge(ride.status),
              const SizedBox(height: core.kSpaceLG),
              _InfoCard(
                title: 'Pickup',
                value: ride.pickupAddress,
                icon: Icons.location_on,
              ),
              if (ride.symptomText != null)
                _InfoCard(
                  title: 'Symptoms',
                  value: ride.symptomText!,
                  icon: Icons.medical_information,
                ),
              if (ride.createdAt != null)
                _InfoCard(
                  title: 'Requested',
                  value: ride.createdAt!,
                  icon: Icons.access_time,
                ),
              if (ride.driver != null) ...[
                const SizedBox(height: core.kSpaceSM),
                Text(
                  'Driver',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      (ride.driver!['full_name'] as String?) ?? 'Driver',
                    ),
                    subtitle: Text(
                      (ride.driver!['vehicle_plate'] as String?) ?? '',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: core.kSpaceXL),
              if (ride.isTrackable)
                core.PrimaryButton(
                  label: 'Track Live',
                  onPressed: () => context.push('/tracking/$rideId'),
                  color: core.kPatientPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final core.RideStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: core.kSpaceLG,
        vertical: core.kSpaceSM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(core.kRadiusXL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: core.kSpaceSM),
          Text(
            status.displayLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: core.kSpaceSM),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontSize: core.kFontSM)),
        subtitle: Text(value),
      ),
    );
  }
}
