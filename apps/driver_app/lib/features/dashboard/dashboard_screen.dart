import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48,
                            color: driverPrimary.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          state.isOnline
                              ? 'Waiting for ride requests…'
                              : 'Go online to receive rides',
                          style: const TextStyle(color: statusOffline, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  ...state.pendingRides.map((r) => _RideCard(ride: r)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RideCard extends StatefulWidget {
  final PendingRide ride;
  const _RideCard({required this.ride});

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const _duration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _duration)..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final secondsLeft = ((_duration.inSeconds) * (1 - _ctrl.value)).ceil();
        final isUrgent = secondsLeft <= 10;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.ride.pickupAddress,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: 1 - _ctrl.value,
                            strokeWidth: 3,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                              isUrgent ? statusError : driverPrimary,
                            ),
                          ),
                          Text(
                            '$secondsLeft',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUrgent ? statusError : driverPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.ride.rideType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.ride.rideType == 'emergency'
                        ? statusError
                        : statusOffline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (secondsLeft > 0)
                  Semantics(
                    label: 'Accept ride request',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push('/ride/${widget.ride.id}'),
                        child: const Text('Accept Ride'),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Text(
                      'Request expired',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
