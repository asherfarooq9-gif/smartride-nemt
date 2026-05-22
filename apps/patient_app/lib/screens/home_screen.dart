import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  Position? _position;
  bool _locating = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ridesProvider.notifier).loadHistory();
      ref.read(profileProvider.notifier).load();
      _getLocation();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    if (!mounted) return;
    setState(() => _locating = true);
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) { if (mounted) setState(() => _locating = false); return; }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) { if (mounted) setState(() => _locating = false); return; }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() { _position = pos; _locating = false; });
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onEmergency() {
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for GPS location…')),
      );
      return;
    }
    context.push('/symptom');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final rides = ref.watch(ridesProvider);
    final name = profile.data?['full_name'] as String? ?? '';
    final activeRide = rides.activeRide;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('SmartRide'),
        actions: [
          if (name.isNotEmpty)
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: kBlue.withValues(alpha: 0.12),
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(color: kBlue, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          IconButton(onPressed: () => context.push('/history'), icon: const Icon(Icons.history_rounded), tooltip: 'History'),
          IconButton(onPressed: () => ref.read(authProvider.notifier).logout(), icon: const Icon(Icons.logout_rounded), tooltip: 'Sign out'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ridesProvider.notifier).loadHistory(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Welcome
            if (name.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kBlue, Color(0xFF1976D2)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Active ride banner
            if (activeRide != null) ...[
              _ActiveRideCard(ride: activeRide),
              const SizedBox(height: 20),
            ],

            // GPS
            _GpsStatusCard(locating: _locating, position: _position, onRefresh: _getLocation),
            const SizedBox(height: 24),

            // Emergency button
            ScaleTransition(
              scale: _pulseAnimation,
              child: SizedBox(
                height: 130,
                child: ElevatedButton(
                  onPressed: _onEmergency,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency_rounded, size: 44),
                      SizedBox(height: 8),
                      Text('EMERGENCY RIDE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      Text('Tap to request now', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scheduled
            OutlinedButton.icon(
              onPressed: () => context.push('/scheduled-ride'),
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Book Scheduled Ride'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kBlue,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: kBlue),
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            if (rides.rides.isNotEmpty) _StatsRow(rides: rides.rides),
          ],
        ),
      ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _ActiveRideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final status = (ride['status'] as String? ?? '').replaceAll('_', ' ');
    final rideId = ride['id'] as String? ?? '';
    return GestureDetector(
      onTap: () => context.push('/tracking/$rideId'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.local_taxi_rounded, color: kRed, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(status, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _GpsStatusCard extends StatelessWidget {
  final bool locating;
  final Position? position;
  final VoidCallback onRefresh;
  const _GpsStatusCard({required this.locating, required this.position, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(
            position != null ? Icons.location_on_rounded : Icons.location_searching_rounded,
            color: position != null ? kGreen : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              locating
                  ? 'Detecting location…'
                  : position != null
                      ? '${position!.latitude.toStringAsFixed(4)}, ${position!.longitude.toStringAsFixed(4)}'
                      : 'Location unavailable — tap retry',
              style: TextStyle(fontSize: 13, color: locating ? Colors.grey : (position != null ? const Color(0xFF111827) : Colors.red)),
            ),
          ),
          if (!locating && position == null)
            TextButton(onPressed: onRefresh, child: const Text('Retry', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  const _StatsRow({required this.rides});

  @override
  Widget build(BuildContext context) {
    final completed = rides.where((r) => r['status'] == 'completed').length;
    final emergency = rides.where((r) => r['ride_type'] == 'emergency').length;
    return Row(
      children: [
        Expanded(child: _StatChip(label: 'Total', value: '${rides.length}', icon: Icons.directions_car_rounded, color: kBlue)),
        const SizedBox(width: 12),
        Expanded(child: _StatChip(label: 'Done', value: '$completed', icon: Icons.check_circle_outline_rounded, color: kGreen)),
        const SizedBox(width: 12),
        Expanded(child: _StatChip(label: 'SOS', value: '$emergency', icon: Icons.emergency_rounded, color: kRed)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
