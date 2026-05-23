import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import 'dashboard_notifier.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(dashboardNotifierProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardNotifierProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Online/Offline toggle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: state.isOnline ? statusOnline : statusOffline,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.isOnline
                              ? 'Online — accepting rides'
                              : 'Offline',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: state.isOnline
                                ? statusOnline
                                : statusOffline,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: state.isOnline,
                          onChanged: (_) => ref
                              .read(dashboardNotifierProvider.notifier)
                              .toggleOnline(),
                          activeThumbColor: statusOnline,
                          activeTrackColor: statusOnline.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pending Rides (${state.pendingRides.length})',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: driverPrimaryDark),
                ),
                const SizedBox(height: 12),
                if (state.pendingRides.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No pending rides',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...state.pendingRides.map(
                    (r) => _RideRequestCard(
                      ride: r,
                      onAccept: () => context.push('/ride/${r.id}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RideRequestCard extends StatelessWidget {
  final PendingRide ride;
  final VoidCallback onAccept;
  const _RideRequestCard({required this.ride, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(ride.requestedAt)?.toLocal();
    final formatted = dt != null ? DateFormat('h:mm a').format(dt) : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              ride.rideType == 'emergency'
                  ? Icons.emergency
                  : Icons.directions_car,
              color: ride.rideType == 'emergency'
                  ? statusError
                  : driverPrimary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.pickupAddress,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(formatted,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: driverPrimary,
                minimumSize: const Size(70, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child:
                  const Text('Accept', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
