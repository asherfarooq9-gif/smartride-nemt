import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/secure_storage.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String rideId;
  final double pickupLat;
  final double pickupLng;

  const LiveTrackingScreen({
    super.key,
    required this.rideId,
    required this.pickupLat,
    required this.pickupLng,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapCtrl;
  WebSocketChannel? _channel;
  LatLng? _driverPos;
  bool _rideEnded = false;
  String _endedStatus = '';

  // Derive WS base from same env var as ApiClient
  static const _envUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static final String _wsBase = _envUrl.isNotEmpty
      ? _envUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://')
      : 'ws://10.0.2.2:8000';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = await SecureStorage.readToken();
    if (token == null || !mounted) return;

    final uri = Uri.parse('$_wsBase/api/v1/ws/ride/${widget.rideId}');
    _channel = WebSocketChannel.connect(uri);

    // Backend requires token as first message (not query param)
    _channel!.sink.add(jsonEncode({'token': token}));

    _channel!.stream.listen(
      (raw) {
        if (!mounted) return;
        final data = jsonDecode(raw as String) as Map<String, dynamic>;

        if (data['event'] == 'ride_ended') {
          setState(() {
            _rideEnded = true;
            _endedStatus = data['status'] as String? ?? 'completed';
          });
        } else if (data.containsKey('lat') && data.containsKey('lng')) {
          final pos = LatLng(
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          );
          setState(() => _driverPos = pos);
          _mapCtrl?.animateCamera(CameraUpdate.newLatLng(pos));
        }
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickupLat, widget.pickupLng),
        infoWindow: const InfoWindow(title: 'Your Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      if (_driverPos != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          infoWindow: const InfoWindow(title: 'Driver'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.pickupLat, widget.pickupLng),
              zoom: 15,
            ),
            markers: _buildMarkers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (ctrl) => _mapCtrl = ctrl,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StatusCard(
              driverPos: _driverPos,
              rideEnded: _rideEnded,
              endedStatus: _endedStatus,
              onDone: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final LatLng? driverPos;
  final bool rideEnded;
  final String endedStatus;
  final VoidCallback onDone;

  const _StatusCard({
    required this.driverPos,
    required this.rideEnded,
    required this.endedStatus,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    if (rideEnded) {
      final completed = endedStatus == 'completed';
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: completed ? Colors.green[700] : Colors.grey[700],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              completed ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    completed ? 'Ride Completed' : 'Ride Cancelled',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Thank you for using SmartRide',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onDone,
              child: const Text(
                'Done',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Driver en route',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  driverPos == null
                      ? 'Waiting for driver location…'
                      : 'Driver nearby — updating live',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Icon(Icons.directions_car,
              color: Color(0xFF1565C0), size: 28),
        ],
      ),
    );
  }
}
