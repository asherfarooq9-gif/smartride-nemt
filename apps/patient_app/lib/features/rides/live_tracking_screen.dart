import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartride_core/smartride_core.dart' as core;

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  core.WsClient? _ws;
  final MapController _mapController = MapController();
  LatLng? _driverPos;
  LatLng? _pickupPos;
  core.RideDetailResponse? _ride;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ride = await core.getRideDetail(widget.rideId);
      if (ride.pickupLat != null && ride.pickupLng != null) {
        _pickupPos = LatLng(ride.pickupLat!, ride.pickupLng!);
      }
      if (mounted) setState(() => _ride = ride);
      await _connectWs();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _connectWs() async {
    final token = await core.SecureStorage.instance.readToken();
    if (token == null || !mounted) return;
    final baseWs = core.ApiClient.instance.wsBaseUrl;
    final uri = Uri.parse('$baseWs/ws/ride/${widget.rideId}');
    _ws = core.WsClient(
      onMessage: _handleWsMessage,
      onDone: () { if (mounted && !_loaded) setState(() => _loaded = true); },
    );
    await _ws!.connect(uri, token);
    if (mounted) setState(() => _loaded = true);
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    if (msg.containsKey('lat') && msg.containsKey('lng')) {
      final lat = (msg['lat'] as num).toDouble();
      final lng = (msg['lng'] as num).toDouble();
      setState(() => _driverPos = LatLng(lat, lng));
      try { _mapController.move(LatLng(lat, lng), 15); } catch (_) {}
      return;
    }
    if (msg['event'] == 'ride_ended') {
      _ws?.disconnect();
      if (mounted) _showCompletionDialog(msg['status'] as String? ?? 'completed');
    }
  }

  void _showCompletionDialog(String status) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(status == 'completed' ? 'Ride Completed' : 'Ride Ended'),
        content: Text(status == 'completed'
            ? 'You have arrived at your destination.'
            : 'Your ride has ended.'),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); context.go('/'); },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ws?.disconnect();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Tracking')),
        body: core.ErrorState(message: _error!, onRetry: () {
          setState(() => _error = null);
          _init();
        }),
      );
    }
    if (!_loaded) {
      return const Scaffold(body: core.LoadingState(message: 'Connecting...'));
    }

    final center = _driverPos ?? _pickupPos ?? const LatLng(33.6844, 73.0479);
    final ride = _ride;
    final driver = ride?.driver;
    final statusLabel = ride?.status.displayLabel ?? 'En Route';

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartride.patient',
              ),
              MarkerLayer(markers: [
                if (_pickupPos != null)
                  Marker(
                    point: _pickupPos!,
                    width: 40, height: 40,
                    child: Semantics(
                      label: 'Pickup location',
                      child: const Icon(Icons.location_on, color: core.kEmergencyRed, size: 40),
                    ),
                  ),
                if (_driverPos != null)
                  Marker(
                    point: _driverPos!,
                    width: 40, height: 40,
                    child: Semantics(
                      label: 'Driver location',
                      child: const Icon(Icons.local_taxi, color: core.kDriverPrimary, size: 40),
                    ),
                  ),
              ]),
            ],
          ),

          // Top status bar
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(core.kSpaceLG),
              padding: const EdgeInsets.symmetric(
                  horizontal: core.kSpaceLG, vertical: core.kSpaceMD),
              decoration: BoxDecoration(
                color: core.kDriverPrimary,
                borderRadius: BorderRadius.circular(core.kRadiusLG),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white70, fontSize: core.kFontXS,
                      fontWeight: FontWeight.w600, letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Help is on the way',
                    style: TextStyle(
                      color: Colors.white, fontSize: core.kFontLG,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: core.kSpaceSM),
                  Row(children: [
                    _StatusChip(label: 'ETA: ~8 min', icon: Icons.access_time),
                    const SizedBox(width: core.kSpaceSM),
                    if (ride?.hospitalId != null)
                      const _StatusChip(label: 'PIMS Hospital', icon: Icons.local_hospital_outlined),
                  ]),
                ],
              ),
            ),
          ),

          // Bottom driver card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(core.kSpaceLG),
              padding: const EdgeInsets.all(core.kSpaceLG),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(core.kRadiusXL),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: core.kDriverPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: core.kDriverPrimary),
                      ),
                      const SizedBox(width: core.kSpaceLG),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver != null
                                  ? (driver['full_name'] as String? ?? 'Your Driver')
                                  : 'Your Driver',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: core.kFontMD),
                            ),
                            Text(
                              driver != null
                                  ? '${driver['vehicle_type'] ?? ''} · ${driver['vehicle_plate'] ?? ''}'
                                  : 'En route to you',
                              style: const TextStyle(
                                  color: core.kTextSecondary, fontSize: core.kFontSM),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: core.kDriverPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: core.kSpaceMD),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_location_outlined, size: 18),
                    label: const Text('Share live location with family'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, core.kMinTapTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(core.kRadiusLG),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: core.kSpaceSM, vertical: core.kSpaceXS),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(core.kRadiusXXL),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: core.kFontXS,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
