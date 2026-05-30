import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import '../../core/providers.dart';

final _rideDetailProvider =
    FutureProvider.autoDispose.family<core.RideDetailResponse, String>(
  (ref, id) => core.getRideDetail(id),
);

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  final MapController _mapController = MapController();
  LatLng? _myPos;
  bool _cancelling = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _advance(core.RideStatus next) async {
    try {
      await core.updateRideStatus(widget.rideId, next);
      ref.invalidate(_rideDetailProvider(widget.rideId));
      if (next == core.RideStatus.completed ||
          next == core.RideStatus.cancelled) {
        await ref.read(gpsStreamProvider.notifier).stopStreaming();
        if (mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is core.AppError ? e.message : 'Update failed'),
            backgroundColor: core.kError,
          ),
        );
      }
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: core.kError),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _cancelling = true);
      await _advance(core.RideStatus.cancelled);
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(_rideDetailProvider(widget.rideId));
    final isStreaming = ref.watch(gpsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: rideAsync.whenOrNull(
              data: (r) => Text(r.status.displayLabel),
            ) ??
            const Text('Active Ride'),
        actions: [
          if (isStreaming)
            const Padding(
              padding: EdgeInsets.only(right: core.kSpaceLG),
              child: Tooltip(
                message: 'GPS streaming',
                child: Icon(Icons.gps_fixed, color: core.kOnlineGreen),
              ),
            ),
        ],
      ),
      body: rideAsync.when(
        loading: () => const core.LoadingState(),
        error: (e, _) => core.ErrorState(
          message: e is core.AppError ? e.message : 'Failed to load ride',
          onRetry: () => ref.invalidate(_rideDetailProvider(widget.rideId)),
        ),
        data: (ride) {
          final pickupPos = (ride.pickupLat != null && ride.pickupLng != null)
              ? LatLng(ride.pickupLat!, ride.pickupLng!)
              : null;

          return Column(
            children: [
              _StatusBanner(ride.status),
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        pickupPos ?? _myPos ?? const LatLng(0, 0),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.smartride.driver',
                    ),
                    MarkerLayer(
                      markers: [
                        if (pickupPos != null)
                          Marker(
                            point: pickupPos,
                            width: 40,
                            height: 40,
                            child: const Tooltip(
                              message: 'Patient pickup',
                              child: Icon(
                                Icons.location_on,
                                color: core.kEmergencyRed,
                                size: 40,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _ActionPanel(
                ride: ride,
                cancelling: _cancelling,
                onAdvance: _advance,
                onCancel: _cancel,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner(this.status);

  final core.RideStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: core.kSpaceLG,
        vertical: core.kSpaceSM,
      ),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        status.displayLabel,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.ride,
    required this.cancelling,
    required this.onAdvance,
    required this.onCancel,
  });

  final core.RideDetailResponse ride;
  final bool cancelling;
  final Future<void> Function(core.RideStatus) onAdvance;
  final Future<void> Function() onCancel;

  core.RideStatus? get _nextStatus {
    switch (ride.status) {
      case core.RideStatus.driverAssigned:
        return core.RideStatus.driverEnRoute;
      case core.RideStatus.driverEnRoute:
        return core.RideStatus.patientPickedUp;
      case core.RideStatus.patientPickedUp:
        return core.RideStatus.arrivedAtHospital;
      case core.RideStatus.arrivedAtHospital:
        return core.RideStatus.completed;
      default:
        return null;
    }
  }

  String get _nextLabel {
    switch (ride.status) {
      case core.RideStatus.driverAssigned:
        return 'Start Driving';
      case core.RideStatus.driverEnRoute:
        return 'Patient Picked Up';
      case core.RideStatus.patientPickedUp:
        return 'Arrived at Hospital';
      case core.RideStatus.arrivedAtHospital:
        return 'Complete Ride';
      default:
        return 'Next';
    }
  }

  bool get _canCancel =>
      ride.status == core.RideStatus.driverAssigned ||
      ride.status == core.RideStatus.driverEnRoute;

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus;
    return Container(
      padding: const EdgeInsets.all(core.kSpaceLG),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (next != null)
            core.PrimaryButton(
              label: _nextLabel,
              onPressed: () => onAdvance(next),
              height: core.kMinTapTarget,
            ),
          if (_canCancel) ...[
            const SizedBox(height: core.kSpaceSM),
            SizedBox(
              width: double.infinity,
              height: core.kMinTapTarget,
              child: OutlinedButton(
                onPressed: cancelling ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: core.kError,
                  side: const BorderSide(color: core.kError),
                ),
                child: cancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: core.kError,
                        ),
                      )
                    : const Text('Cancel Ride'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
