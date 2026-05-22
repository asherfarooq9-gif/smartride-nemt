import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(activeRideProvider.notifier).refresh();
    ref.read(driverProfileProvider.notifier).load();
    ref.read(rideHistoryProvider.notifier).load();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    return DateFormat('dd MMM, HH:mm').format(DateTime.parse(iso).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final driverStatus = ref.watch(driverStatusProvider);
    final activeRide = ref.watch(activeRideProvider);
    final profile = ref.watch(driverProfileProvider);
    final history = ref.watch(rideHistoryProvider);
    final isAvailable = driverStatus == DriverStatus.available;

    final todayEarnings = history.rides
        .where((r) {
          final dt = DateTime.tryParse(r['requested_at'] as String? ?? '');
          return dt != null && dt.day == DateTime.now().day && r['final_fare_pkr'] != null;
        })
        .fold<double>(0, (sum, r) => sum + (r['final_fare_pkr'] as num).toDouble());

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartRide Driver'),
        actions: [
          if (profile.data != null)
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: kGreen.withValues(alpha: 0.15),
                  child: Text(
                    (profile.data!['full_name'] as String? ?? 'D')[0].toUpperCase(),
                    style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(gpsStreamProvider.notifier).stopStreaming();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'History'),
          NavigationDestination(icon: Icon(Icons.payments_rounded), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 1: context.push('/history'); break;
            case 2: context.push('/earnings'); break;
            case 3: context.push('/settings'); break;
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(activeRideProvider.notifier).refresh();
          await ref.read(rideHistoryProvider.notifier).load();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Online toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isAvailable ? kGreen.withValues(alpha: 0.4) : const Color(0xFFE5E7EB)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: isAvailable ? kGreen : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAvailable ? 'Online' : 'Offline',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isAvailable ? kGreen : Colors.grey),
                        ),
                        Text(
                          isAvailable ? 'Ready to receive rides' : 'Toggle to go online',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isAvailable,
                    activeThumbColor: kGreen,
                    activeTrackColor: kGreen.withValues(alpha: 0.3),
                    onChanged: (v) => ref.read(driverStatusProvider.notifier).setAvailable(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Earnings summary
            Row(
              children: [
                Expanded(child: _MiniStatCard(label: "Today's Earnings", value: 'PKR ${todayEarnings.toStringAsFixed(0)}', icon: Icons.payments_rounded, color: kGreen)),
                const SizedBox(width: 12),
                Expanded(child: _MiniStatCard(label: 'Total Rides', value: '${history.rides.length}', icon: Icons.directions_car_rounded, color: kBlue)),
              ],
            ),
            const SizedBox(height: 20),

            // Active ride
            if (activeRide != null) ...[
              const Text('Active Ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _ActiveRideCard(ride: activeRide, formatDate: _formatDate),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_taxi_rounded,
                      size: 52,
                      color: isAvailable ? kGreen.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isAvailable ? 'Waiting for ride requests…' : 'Go online to receive rides',
                      style: TextStyle(color: isAvailable ? kGreen : Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveRideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final String Function(String?) formatDate;
  const _ActiveRideCard({required this.ride, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final isEmergency = ride['ride_type'] == 'emergency';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEmergency ? kRed.withValues(alpha: 0.3) : kGreen.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isEmergency ? Icons.emergency_rounded : Icons.calendar_month_rounded, color: isEmergency ? kRed : kBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                isEmergency ? 'Emergency Ride' : 'Scheduled Ride',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text((ride['status'] as String? ?? '').replaceAll('_', ' '), style: const TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Requested: ${formatDate(ride['requested_at'] as String?)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: const Text('Continue Ride'),
              onPressed: () => context.push('/ride/${ride['id']}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
