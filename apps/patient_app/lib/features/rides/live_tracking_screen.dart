import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:url_launcher/url_launcher.dart';
import 'package:patient_app/shared/english_map_tiles.dart';
import 'package:patient_app/driver/ride_events.dart' show rideHasEnded;

const _genericLoadError =
    'We could not load your ride. Please check your connection and try again.';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  core.WsClient? _ws;
  LatLng? _driverPos;
  LatLng? _pickupPos;
  core.RideDetailResponse? _ride;
  bool _loaded = false;
  bool _isMapReady = false;
  String? _error;

  // The WsClient owns reconnection; this screen only mirrors its state.
  bool _connected = false;
  bool _hasGivenUp = false;
  bool _ended = false;

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
      if (!mounted) return;
      // The ride is already known, so show it now; the live socket connects in
      // the background and the status panel says while it is not yet live.
      setState(() {
        _ride = ride;
        _loaded = true;
      });
      unawaited(_connectWs());
    } on core.AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception catch (e, st) {
      core.ErrorReporter.report('Live tracking failed to load', e, st);
      if (mounted) setState(() => _error = _genericLoadError);
    }
  }

  Future<void> _connectWs() async {
    final token = await core.SecureStorage.instance.readToken();
    if (token == null || !mounted) return;
    final uri = Uri.parse(
        '${core.ApiClient.instance.wsBaseUrl}/ws/ride/${widget.rideId}');
    final ws = _ws ??= core.WsClient(
      onMessage: _handleWsMessage,
      tokenProvider: core.SecureStorage.instance.readToken,
      onConnected: () {
        _setConnection(isConnected: true);
        // The ride may have finished while the socket was down; the server's
        // 'ride_ended' only reaches a client that is connected when it is sent.
        unawaited(_refreshRide());
      },
      onDisconnected: () => _setConnection(isConnected: false),
      onError: _onWsError,
    );
    if (mounted) setState(() => _hasGivenUp = false);
    await ws.connect(uri, token);
  }

  void _setConnection({required bool isConnected}) {
    if (!mounted || _ended) return;
    setState(() {
      _connected = isConnected;
      if (isConnected) _hasGivenUp = false;
    });
  }

  void _onWsError(Object error) {
    if (!mounted || _ended || error is! core.WsRetriesExhausted) return;
    setState(() => _hasGivenUp = true);
    unawaited(_refreshRide());
  }

  /// Reads the ride again and, if it is over, shows the same completion dialog the
  /// socket would have. Without this a patient whose tunnel dropped at the wrong
  /// moment stays on "help is on the way" for a ride that is already finished.
  Future<void> _refreshRide() async {
    try {
      final ride = await core.getRideDetail(widget.rideId);
      if (!mounted) return;
      setState(() => _ride = ride);
      if (rideHasEnded(ride.status) && !_ended) {
        _ended = true;
        unawaited(_ws?.disconnect());
        _showCompletionDialog(
          ride.status == core.RideStatus.completed ? 'completed' : 'cancelled',
        );
      }
    } on core.AppError {
      // Keep what is on screen; the socket or the next reconnect will say more.
    }
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final lat = msg['lat'];
    final lng = msg['lng'];
    if (lat is num && lng is num) {
      final pos = LatLng(lat.toDouble(), lng.toDouble());
      setState(() => _driverPos = pos);
      if (_isMapReady) _mapController.move(pos, 15);
      return;
    }
    if (msg['event'] == 'ride_ended') {
      _ended = true;
      _ws?.disconnect();
      _showCompletionDialog(msg['status'] as String? ?? 'completed');
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
          if (status == 'completed')
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/rate-driver/${widget.rideId}');
              },
              child: const Text('Rate Driver'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/');
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ended = true;
    _ws?.disconnect();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone app available on this device')),
      );
    }
  }

  /// Open the SMS composer pre-filled with the ride details so the patient
  /// can send it to family. SMS works without data — important mid-emergency.
  Future<void> _shareWithFamily() async {
    final hospital = _ride?.hospital?['name'] as String? ?? 'hospital';
    final pos = _driverPos;
    final mapLink = pos != null
        ? ' Track: https://www.openstreetmap.org/?mlat=${pos.latitude}&mlon=${pos.longitude}#map=16/${pos.latitude}/${pos.longitude}'
        : '';
    final body = Uri.encodeComponent(
        'I am in a SmartRide medical transport to $hospital. '
        'Ride ID: ${widget.rideId}.$mapLink');
    final uri = Uri.parse('sms:?body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No SMS app available on this device')),
      );
    }
  }

  /// ETA from the driver's last known position to the pickup point, or null
  /// until we have both — never display a made-up number.
  String? get _etaLabel {
    final d = _driverPos, p = _pickupPos;
    if (d == null || p == null) return null;
    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, d, p);
    final minutes = (km / 25.0 * 60).ceil().clamp(1, 999);
    return 'ETA: ~$minutes min';
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
      return const Scaffold(body: core.LoadingState(message: 'Connecting...'));
    }

    final center = _driverPos ?? _pickupPos ?? const LatLng(33.6844, 73.0479);

    return Scaffold(
      body: Stack(
        children: [
          _TrackingMap(
            controller: _mapController,
            center: center,
            pickup: _pickupPos,
            driver: _driverPos,
            onMapReady: () => _isMapReady = true,
          ),
          SafeArea(
            child: _StatusPanel(
              statusLabel: _ride?.status.displayLabel ?? 'En Route',
              etaLabel: _etaLabel,
              hospitalName: _ride?.hospital?['name'] as String?,
              isConnected: _connected,
              hasGivenUp: _hasGivenUp,
              onRetry: _connectWs,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _DriverCard(
              driver: _ride?.driver,
              onCall: _callDriver,
              onShare: _shareWithFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({
    required this.controller,
    required this.center,
    required this.pickup,
    required this.driver,
    required this.onMapReady,
  });

  final MapController controller;
  final LatLng center;
  final LatLng? pickup;
  final LatLng? driver;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        onMapReady: onMapReady,
      ),
      children: [
        ...englishTileLayers(),
        MarkerLayer(markers: [
          if (pickup != null)
            Marker(
              point: pickup!,
              width: 40,
              height: 40,
              child: Semantics(
                label: 'Pickup location',
                child: const Icon(Icons.location_on,
                    color: core.kEmergencyRed, size: 40),
              ),
            ),
          if (driver != null)
            Marker(
              point: driver!,
              width: 40,
              height: 40,
              child: Semantics(
                label: 'Driver location',
                child: const Icon(Icons.local_taxi,
                    color: core.kDriverPrimary, size: 40),
              ),
            ),
        ]),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.statusLabel,
    required this.etaLabel,
    required this.hospitalName,
    required this.isConnected,
    required this.hasGivenUp,
    required this.onRetry,
  });

  final String statusLabel;
  final String? etaLabel;
  final String? hospitalName;
  final bool isConnected;
  final bool hasGivenUp;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: Colors.white,
              fontSize: core.kFontSmall,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Help is on the way',
            style: TextStyle(
              color: Colors.white,
              fontSize: core.kFontLG,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: core.kSpaceSM),
          Wrap(
            spacing: core.kSpaceSM,
            runSpacing: core.kSpaceSM,
            children: [
              if (etaLabel != null)
                _StatusChip(label: etaLabel!, icon: Icons.access_time),
              if (hospitalName != null)
                _StatusChip(
                  label: hospitalName!,
                  icon: Icons.local_hospital_outlined,
                ),
            ],
          ),
          if (hasGivenUp)
            _ConnectionNotice(
              message: 'Live location is unavailable.',
              onRetry: onRetry,
            )
          else if (!isConnected)
            const _ConnectionNotice(
              message: 'Reconnecting — driver location may be out of date',
            ),
        ],
      ),
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: core.kSpaceSM),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontSize: core.kFontSmall),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize:
                      const Size(core.kMinTapTarget, core.kMinTapTarget),
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.onCall,
    required this.onShare,
  });

  final Map<String, dynamic>? driver;
  final Future<void> Function(String phone) onCall;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final phone = driver?['phone'] as String?;
    final name = driver?['full_name'] as String? ?? 'Your Driver';
    final vehicle = driver != null
        ? '${driver!['vehicle_type'] ?? ''} · ${driver!['vehicle_plate'] ?? ''}'
        : 'En route to you';

    return Container(
      margin: const EdgeInsets.all(core.kSpaceLG),
      padding: const EdgeInsets.all(core.kSpaceLG),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(core.kRadiusXL),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primaryContainer,
                child: Icon(Icons.person, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: core.kSpaceLG),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      vehicle,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Call driver',
                onPressed: phone == null ? null : () => onCall(phone),
                icon: const Icon(Icons.phone),
                style: IconButton.styleFrom(
                  minimumSize:
                      const Size(core.kMinTapTarget, core.kMinTapTarget),
                ),
              ),
            ],
          ),
          const SizedBox(height: core.kSpaceMD),
          OutlinedButton.icon(
            onPressed: onShare,
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
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: core.kFontSmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
