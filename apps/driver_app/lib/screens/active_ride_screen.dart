import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/providers.dart';

const _statusFlow = [
  ('driver_en_route', 'En Route to Patient', Icons.directions_car),
  ('patient_picked_up', 'Patient Picked Up', Icons.person),
  ('arrived_at_hospital', 'Arrived at Hospital', Icons.local_hospital),
  ('completed', 'Complete Ride', Icons.check_circle),
];

class ActiveRideScreen extends ConsumerStatefulWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    final token = ref.read(authProvider).token;
    if (token != null) {
      ref.read(gpsStreamProvider.notifier).startStreaming(widget.rideId, token);
    }
  }

  @override
  void dispose() {
    ref.read(gpsStreamProvider.notifier).stopStreaming();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _advanceStatus(String newStatus) async {
    await ref.read(activeRideProvider.notifier).updateStatus(widget.rideId, newStatus);
    if (newStatus == 'completed' && mounted) {
      context.go('/');
    }
  }

  String? _nextStatus(String? currentStatus) {
    for (int i = 0; i < _statusFlow.length - 1; i++) {
      if (_statusFlow[i].$1 == currentStatus) return _statusFlow[i + 1].$1;
    }
    if (currentStatus == 'driver_assigned') return 'driver_en_route';
    return null;
  }

  String _nextLabel(String? currentStatus) {
    final next = _nextStatus(currentStatus);
    for (final (status, label, _) in _statusFlow) {
      if (status == next) return label;
    }
    return 'Update Status';
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(activeRideProvider);
    final isStreaming = ref.watch(gpsStreamProvider);
    final currentStatus = ride?['status'] as String?;
    final nextStatus = _nextStatus(currentStatus);
    final pickupLat = ride?['pickup_lat'] as double?;
    final pickupLng = ride?['pickup_lng'] as double?;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ride ${widget.rideId.substring(0, 8)}…'),
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Column(
        children: [
          // GPS streaming indicator
          Container(
            color: isStreaming ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(isStreaming ? Icons.gps_fixed : Icons.gps_off,
                  color: isStreaming ? Colors.green : Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text(
                  isStreaming ? 'GPS streaming active' : 'GPS not streaming',
                  style: TextStyle(
                    color: isStreaming ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: pickupLat != null && pickupLng != null
                  ? LatLng(pickupLat, pickupLng)
                  : const LatLng(33.6844, 73.0479),
                zoom: 15,
              ),
              onMapCreated: (c) => _mapController = c,
              markers: {
                if (pickupLat != null && pickupLng != null)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(pickupLat, pickupLng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'Patient pickup'),
                  ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),

          // Status panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Current: ${currentStatus ?? 'loading…'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),

                // Status progression chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFlow.map((entry) {
                      final (status, label, icon) = entry;
                      final isDone = _isStatusBefore(currentStatus, status);
                      final isCurrent = currentStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          avatar: Icon(icon, size: 16,
                            color: isCurrent ? Colors.white : (isDone ? Colors.green : Colors.grey)),
                          label: Text(label, style: TextStyle(
                            fontSize: 11,
                            color: isCurrent ? Colors.white : (isDone ? Colors.green : Colors.grey),
                          )),
                          backgroundColor: isCurrent
                            ? const Color(0xFF388E3C)
                            : (isDone ? const Color(0xFFE8F5E9) : Colors.grey.shade100),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),
                if (nextStatus != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(_nextLabel(currentStatus)),
                    onPressed: () => _advanceStatus(nextStatus),
                  ),
                if (nextStatus == null && currentStatus == 'completed')
                  const Center(child: Text('Ride completed!',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isStatusBefore(String? current, String check) {
    final order = ['driver_assigned', 'driver_en_route', 'patient_picked_up', 'arrived_at_hospital', 'completed'];
    final ci = order.indexOf(current ?? '');
    final ti = order.indexOf(check);
    return ti < ci;
  }
}
