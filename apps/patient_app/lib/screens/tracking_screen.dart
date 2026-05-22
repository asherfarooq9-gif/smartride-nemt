import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers.dart';
import '../core/theme.dart';

const _kStatuses = [
  'pending', 'driver_assigned', 'driver_en_route',
  'patient_picked_up', 'arrived_at_hospital', 'completed',
];

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
  Map<String, dynamic>? _rideDetail;
  Timer? _pollTimer;
  bool _completed = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _pollRideStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollRideStatus());
    _loadDetail();
  }

  Future<void> _pollRideStatus() async {
    final ride = await ref.read(ridesProvider.notifier).pollRide(widget.rideId);
    if (!mounted) return;
    setState(() => _ride = ride);
    final status = ride?['status'] as String?;
    if (status == 'completed' || status == 'cancelled') {
      _pollTimer?.cancel();
      if (mounted) setState(() => _completed = true);
    }
    // Update driver marker if coordinates available
    final driverLat = ride?['driver_lat'] as double?;
    final driverLng = ride?['driver_lng'] as double?;
    if (driverLat != null && driverLng != null && mounted) {
      final pos = LatLng(driverLat, driverLng);
      setState(() => _driverPosition = pos);
      _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  Future<void> _loadDetail() async {
    final detail = await ref.read(ridesProvider.notifier).getRideDetail(widget.rideId);
    if (mounted) setState(() => _rideDetail = detail);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  String _statusLabel(String? status) => switch (status) {
    'pending' => 'Finding a driver…',
    'driver_assigned' => 'Driver assigned — preparing',
    'driver_en_route' => 'Driver is on the way to you',
    'patient_picked_up' => 'You have been picked up',
    'arrived_at_hospital' => 'Arrived at hospital',
    'completed' => 'Ride completed ✓',
    'cancelled' => 'Ride cancelled',
    _ => 'Loading…',
  };

  Color _statusColor(String? status) => switch (status) {
    'completed' => kGreen,
    'cancelled' => kRed,
    'pending' => kAmber,
    _ => kBlue,
  };

  bool get _canCancel {
    final s = _ride?['status'] as String? ?? '';
    return s == 'pending' || s == 'driver_assigned';
  }

  Future<void> _cancelRide() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Ride?'),
        content: const Text('The ride will be cancelled and no driver will be sent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Ride')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Ride', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    final success = await ref.read(ridesProvider.notifier).cancelRide(widget.rideId);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (success) context.go('/');
  }

  void _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final status = _ride?['status'] as String?;
    final driver = _rideDetail?['driver'] as Map<String, dynamic>?;
    final hospital = _rideDetail?['hospital'] as Map<String, dynamic>?;

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
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            color: _statusColor(status).withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                if (!_completed && status != 'cancelled')
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _statusColor(status)),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(status == 'completed' ? Icons.check_circle_rounded : Icons.cancel_rounded, color: _statusColor(status), size: 18),
                  ),
                Expanded(
                  child: Text(_statusLabel(status), style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor(status), fontSize: 14)),
                ),
              ],
            ),
          ),

          // Status timeline
          if (_ride != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _kStatuses.where((s) => s != 'cancelled').map((s) {
                  final idx = _kStatuses.indexOf(status ?? '');
                  final sIdx = _kStatuses.indexOf(s);
                  final done = idx >= sIdx && status != 'cancelled';
                  final current = s == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: done ? kBlue : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: current ? kBlue : Colors.transparent, width: 2),
                      ),
                      child: Text(
                        s.replaceAll('_', ' '),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: done ? Colors.white : Colors.grey),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Map
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: LatLng(33.6844, 73.0479), zoom: 14),
              onMapCreated: (c) => _mapController = c,
              markers: {
                if (_driverPosition != null)
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: _driverPosition!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    infoWindow: const InfoWindow(title: 'Your Driver'),
                  ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),

          // Bottom panel
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Driver card
                if (driver != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: kBlue.withValues(alpha: 0.12),
                          child: Text(
                            (driver['full_name'] as String? ?? 'D')[0].toUpperCase(),
                            style: const TextStyle(color: kBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driver['full_name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${driver['vehicle_plate']} · ${driver['vehicle_type']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (driver['phone'] != null)
                          IconButton(
                            onPressed: () => _callDriver(driver['phone'] as String),
                            icon: const Icon(Icons.phone_rounded, color: kGreen),
                            tooltip: 'Call Driver',
                          ),
                      ],
                    ),
                  ),
                  if (hospital != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.local_hospital_rounded, color: kRed, size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text('${hospital['name']} — ${hospital['city']}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                        ],
                      ),
                    ),
                ],

                // Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_canCancel)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancelling ? null : _cancelRide,
                            style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed)),
                            child: _cancelling
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kRed))
                                : const Text('Cancel Ride'),
                          ),
                        ),
                      if (_canCancel) const SizedBox(width: 12),
                      if (_completed)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.go('/'),
                            child: const Text('Back to Home'),
                          ),
                        ),
                    ],
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
