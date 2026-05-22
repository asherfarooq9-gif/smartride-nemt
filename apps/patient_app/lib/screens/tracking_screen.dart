import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String rideId;
  const TrackingScreen({super.key, required this.rideId});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  GoogleMapController? _mapController;
  LatLng? _driverPosition;
  Map<String, dynamic>? _ride;
  Timer? _pollTimer;
  bool _completed = false;


  @override
  void initState() {
    super.initState();
    _pollRideStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollRideStatus());
  }

  Future<void> _pollRideStatus() async {
    final ride = await ref.read(ridesProvider.notifier).pollRide(widget.rideId);
    if (!mounted) return;
    setState(() => _ride = ride);
    final status = ride?['status'] as String?;
    if (status == 'completed' || status == 'cancelled') {
      _pollTimer?.cancel();
      setState(() => _completed = true);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  String _statusLabel(String? status) {
    return switch (status) {
      'pending' => 'Finding a driver…',
      'driver_assigned' => 'Driver assigned — on the way',
      'driver_en_route' => 'Driver is en route to you',
      'patient_picked_up' => 'You have been picked up',
      'arrived_at_hospital' => 'Arrived at hospital',
      'completed' => 'Ride completed',
      'cancelled' => 'Ride cancelled',
      _ => 'Loading…',
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      'pending' => Colors.orange,
      _ => const Color(0xFF1976D2),
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = _ride?['status'] as String?;
    final driverAssigned = _ride?['driver_id'] != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        leading: _completed
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/'))
          : null,
        automaticallyImplyLeading: _completed,
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            color: _statusColor(status).withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                if (!_completed && status != 'completed')
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statusColor(status),
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(33.6844, 73.0479),
                zoom: 14,
              ),
              onMapCreated: (c) => _mapController = c,
              markers: {
                if (_driverPosition != null)
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: _driverPosition!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    infoWindow: const InfoWindow(title: 'Driver'),
                  ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),

          // Ride info panel
          if (_ride != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ride ID: ${widget.rideId.substring(0, 8)}…',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (driverAssigned)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car, color: Color(0xFF1976D2)),
                          SizedBox(width: 8),
                          Text('Driver assigned', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Searching for available driver…',
                        style: TextStyle(color: Colors.grey)),
                    ),
                  if (_completed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => context.go('/'),
                          child: const Text('Back to Home'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
