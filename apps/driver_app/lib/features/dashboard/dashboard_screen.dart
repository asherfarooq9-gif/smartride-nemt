import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'dashboard_notifier.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => ref.read(dashboardProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(core.kSpaceLG),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StatusCard(dash),
                  const SizedBox(height: core.kSpaceLG),
                  if (dash.error != null)
                    core.ErrorState(
                      message: dash.error!,
                      onRetry: () =>
                          ref.read(dashboardProvider.notifier).refresh(),
                    ),
                  if (dash.isOnline) ...[
                    Text(
                      'Pending Rides',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: core.kSpaceSM),
                  ],
                ]),
              ),
            ),
            if (dash.isLoading)
              const SliverFillRemaining(
                child: core.LoadingState(message: 'Refreshing...'),
              )
            else if (dash.isOnline && dash.pendingRides.isEmpty)
              const SliverFillRemaining(
                child: core.EmptyState(
                  message: 'No pending rides.\nWaiting for new requests...',
                  icon: Icons.wifi_tethering,
                ),
              )
            else if (dash.isOnline)
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: core.kSpaceLG),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _RideRequestCard(
                      ride: dash.pendingRides[i],
                      onAccept: () => _accept(dash.pendingRides[i].id),
                    ),
                    childCount: dash.pendingRides.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(String rideId) async {
    final ok =
        await ref.read(dashboardProvider.notifier).acceptRide(rideId);
    if (ok && mounted) context.push('/ride/$rideId');
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard(this.dash);

  final DashboardState dash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = dash.isOnline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(core.kSpaceLG),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dash.driver?.fullName ?? 'Driver',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: core.kSpaceXS),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isOnline ? core.kOnlineGreen : core.kTextSecondary,
                        ),
                      ),
                      const SizedBox(width: core.kSpaceXS),
                      Text(isOnline ? 'Online' : 'Offline'),
                    ],
                  ),
                ],
              ),
            ),
            Semantics(
              label: isOnline ? 'Go offline' : 'Go online',
              child: Switch.adaptive(
                value: isOnline,
                activeThumbColor: core.kOnlineGreen,
              activeTrackColor: core.kOnlineGreen.withValues(alpha: 0.5),
                onChanged: (_) =>
                    ref.read(dashboardProvider.notifier).toggleOnline(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RideRequestCard extends StatefulWidget {
  const _RideRequestCard({required this.ride, required this.onAccept});

  final core.RideResponse ride;
  final VoidCallback onAccept;

  @override
  State<_RideRequestCard> createState() => _RideRequestCardState();
}

class _RideRequestCardState extends State<_RideRequestCard> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _secondsLeft <= 10;
    return Card(
      margin: const EdgeInsets.only(bottom: core.kSpaceSM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(core.kRadiusLG),
        side: BorderSide(
          color: isUrgent ? core.kEmergencyRed : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(core.kSpaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emergency,
                  color: core.kEmergencyRed,
                  size: 20,
                ),
                const SizedBox(width: core.kSpaceXS),
                Expanded(
                  child: Text(
                    widget.ride.pickupAddress,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: core.kSpaceSM,
                    vertical: core.kSpaceXS,
                  ),
                  decoration: BoxDecoration(
                    color: isUrgent ? core.kEmergencyRed : core.kPatientPrimary,
                    borderRadius: BorderRadius.circular(core.kRadiusMD),
                  ),
                  child: Text(
                    '${_secondsLeft}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.ride.symptomText != null) ...[
              const SizedBox(height: core.kSpaceXS),
              Text(
                widget.ride.symptomText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: core.kTextSecondary),
              ),
            ],
            const SizedBox(height: core.kSpaceLG),
            core.PrimaryButton(
              label: 'Accept Ride',
              onPressed: _secondsLeft > 0 ? widget.onAccept : null,
              height: core.kMinTapTarget,
            ),
          ],
        ),
      ),
    );
  }
}
