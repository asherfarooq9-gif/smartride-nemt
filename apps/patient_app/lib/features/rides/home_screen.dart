import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'rides_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesProvider);
    final activeRide = ref.watch(activeRideProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartRide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ridesProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(kSpaceLG),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (activeRide != null) ...[
                    _ActiveRideBanner(ride: activeRide),
                    const SizedBox(height: kSpaceLG),
                  ],
                  _buildEmergencyButton(context),
                  const SizedBox(height: kSpaceLG),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/rides'),
                    icon: const Icon(Icons.history),
                    label: const Text('Ride History'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, kMinTapTarget),
                    ),
                  ),
                  const SizedBox(height: kSpaceXL),
                  Text(
                    'Recent Rides',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: kSpaceSM),
                ]),
              ),
            ),
            ridesAsync.when(
              loading: () => const SliverFillRemaining(
                child: LoadingState(message: 'Loading rides...'),
              ),
              error: (e, _) => SliverFillRemaining(
                child: ErrorState(
                  message: e is AppError ? e.message : 'Failed to load rides',
                  onRetry: () => ref.read(ridesProvider.notifier).refresh(),
                ),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(
                      message: 'No rides yet.\nTap the emergency button to get started.',
                      icon: Icons.directions_car_outlined,
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _RideCard(ride: data.items[i], isRecent: true),
                      childCount: data.items.length.clamp(0, 5),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton(BuildContext context) {
    return Semantics(
      label: 'Request emergency ride',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: kEmergencyButtonHeight,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/symptoms'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kEmergencyRed,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusXL),
            ),
          ),
          icon: const Icon(Icons.emergency, size: 32),
          label: const Text(
            'EMERGENCY RIDE',
            style: TextStyle(
              fontSize: kFontLG,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.ride});

  final RideResponse ride;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.directions_car, size: 32),
        title: const Text(
          'Active Ride',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(ride.status.displayLabel),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => context.push('/ride/${ride.id}'),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, this.isRecent = false});

  final RideResponse ride;
  final bool isRecent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: kSpaceSM),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceSM,
        ),
        leading: Icon(
          ride.rideType == RideType.emergency
              ? Icons.emergency
              : Icons.calendar_today,
          color: ride.rideType == RideType.emergency
              ? kEmergencyRed
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          ride.pickupAddress,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(ride.status.displayLabel),
        trailing: ride.isTrackable
            ? TextButton(
                onPressed: () => context.push('/tracking/${ride.id}'),
                child: const Text('Track'),
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push('/ride/${ride.id}'),
      ),
    );
  }
}
