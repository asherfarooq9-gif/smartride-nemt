import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/ride_card.dart';
import '../../widgets/loading_overlay.dart';
import 'rides_notifier.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  String? _locationLabel;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _fetchLocation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationLabel = 'Location unavailable');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _locationLabel =
              '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLabel = 'Location unavailable');
    }
  }

  void _callEmergency() {
    final pos = _currentPosition;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location unavailable — enable GPS and try again'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    context.push('/symptoms', extra: {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'address': _locationLabel,
    });
  }

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(ridesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartRide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ridesNotifierProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_locationLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDDE8FA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(0xFF1565C0)),
                      const SizedBox(width: 4),
                      Semantics(
                        label: 'Current location: ${_locationLabel ?? "unavailable"}',
                        child: Text(
                          _locationLabel!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF1565C0)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              // Emergency button with pulse animation
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Transform.scale(
                  scale: 1.0 + (_pulseCtrl.value * 0.03),
                  child: child,
                ),
                child: Semantics(
                  label: 'Emergency — tap to request immediate medical transport',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: _callEmergency,
                      icon: const Icon(Icons.emergency, size: 24),
                      label: const Text(
                        'EMERGENCY RIDE',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Active ride banner
              ridesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (state) => state.activeRide != null
                    ? GestureDetector(
                        onTap: () =>
                            context.push('/ride/${state.activeRide!.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1565C0),
                                Color(0xFF1976D2)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_car,
                                  color: Colors.white, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Active Ride',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      state.activeRide!.status
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const Text(
                'Recent Rides',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B3E)),
              ),
              const SizedBox(height: 12),
              ridesAsync.when(
                loading: () => Column(
                  children: List.generate(3, (_) => const SkeletonCard()),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.red)),
                ),
                data: (state) => state.rides.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No rides yet',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : Column(
                        children: state.rides
                            .take(10)
                            .map((r) => RideCard(
                                  rideId: r.id,
                                  status: r.status,
                                  rideType: r.rideType,
                                  pickupAddress: r.pickupAddress,
                                  requestedAt: r.requestedAt,
                                  estimatedFare: r.estimatedFarePkr,
                                  onTap: () =>
                                      context.push('/ride/${r.id}'),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => context.push('/rides'),
                icon: const Icon(Icons.list),
                label: const Text('View all rides'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
