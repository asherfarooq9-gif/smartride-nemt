import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Check for active rides on load
    ref.read(activeRideProvider.notifier).refresh();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    return DateFormat('dd MMM, HH:mm').format(DateTime.parse(iso).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final driverStatus = ref.watch(driverStatusProvider);
    final activeRide = ref.watch(activeRideProvider);
    final isAvailable = driverStatus == DriverStatus.available;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartRide Driver'),
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(gpsStreamProvider.notifier).stopStreaming();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Availability toggle
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isAvailable ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isAvailable ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isAvailable ? 'You are available for rides' : 'You are offline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      Switch(
                        value: isAvailable,
                        activeThumbColor: Colors.green,
                        onChanged: (v) => ref.read(driverStatusProvider.notifier).setAvailable(v),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Active ride card
              if (activeRide != null) ...[
                const Text('Active Ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Card(
                  color: const Color(0xFFE8F5E9),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emergency, color: Color(0xFFD32F2F)),
                            const SizedBox(width: 8),
                            Text(
                              activeRide['ride_type'] == 'emergency' ? 'Emergency Ride' : 'Scheduled Ride',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Status: ${activeRide['status']}',
                          style: const TextStyle(color: Colors.grey)),
                        Text('Requested: ${_formatDate(activeRide['requested_at'] as String?)}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
                            icon: const Icon(Icons.navigation),
                            label: const Text('Open Ride'),
                            onPressed: () => context.push('/ride/${activeRide['id']}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_taxi, size: 64,
                          color: isAvailable ? Colors.green.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          isAvailable ? 'Waiting for a ride request…' : 'Go online to receive rides',
                          style: TextStyle(color: isAvailable ? Colors.green : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
