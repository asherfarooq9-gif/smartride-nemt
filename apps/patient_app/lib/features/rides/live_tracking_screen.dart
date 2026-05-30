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
      onDone: () {
        if (mounted && !_loaded) setState(() => _loaded = true);
      },
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
      try {
        _mapController.move(LatLng(lat, lng), 15);
      } catch (_) {}
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
        title: Text(
          status == 'completed' ? 'Ride Completed' : 'Ride Ended',
        ),
        content: Text(
          status == 'completed'
              ? 'You have arrived at your destination.'
              : 'Your ride has ended.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/');
            },
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
        body: core.ErrorState(
          message: _error!,
          onRetry: () {
            setState(() => _error = null);
            _init();
          },
        ),
      );
    }

    if (!_loaded) {
      return const Scaffold(
        body: core.LoadingState(message: 'Connecting...'),
      );
    }

    final center = _driverPos ?? _pickupPos ?? const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_ride != null
            ? _ride!.status.displayLabel
            : 'Live Tracking'),
        actions: [
          if (_ride != null)
            Padding(
              padding: const EdgeInsets.only(right: core.kSpaceLG),
              child: Chip(
                label: Text(_ride!.status.displayLabel),
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.smartride.patient',
          ),
          MarkerLayer(
            markers: [
              if (_pickupPos != null)
                Marker(
                  point: _pickupPos!,
                  width: 40,
                  height: 40,
                  child: Semantics(
                    label: 'Pickup location',
                    child: const Icon(
                      Icons.location_on,
                      color: core.kEmergencyRed,
                      size: 40,
                    ),
                  ),
                ),
              if (_driverPos != null)
                Marker(
                  point: _driverPos!,
                  width: 40,
                  height: 40,
                  child: Semantics(
                    label: 'Driver location',
                    child: const Icon(
                      Icons.local_taxi,
                      color: core.kPatientPrimary,
                      size: 40,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
