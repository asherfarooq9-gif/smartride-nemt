import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

final _rideDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return await ApiClient.get('/api/v1/rides/$id/detail')
      as Map<String, dynamic>;
});

// Maps current status → next status on button press
const _nextStatus = {
  'pending': 'driver_assigned',
  'driver_assigned': 'active',
  'active': 'completed',
};

const _nextLabel = {
  'pending': 'Accept Ride',
  'driver_assigned': 'Start Ride',
  'active': 'Complete Ride',
};

class ActiveRideScreen extends ConsumerWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(_rideDetailProvider(rideId));

    return Scaffold(
      appBar: AppBar(title: const Text('Active Ride')),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.red))),
        data: (ride) {
          final status = ride['status'] as String;
          final patient = ride['patient'] as Map<String, dynamic>?;
          final nextS = _nextStatus[status];
          final nextL = _nextLabel[status];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF00695C).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF00695C)),
                  ),
                ),
                const SizedBox(height: 16),
                // Pickup info
                _InfoRow('Pickup',
                    (ride['pickup_address'] as String?) ?? 'N/A'),
                const SizedBox(height: 12),
                // Patient info
                if (patient != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Patient',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF00695C))),
                          const Divider(height: 16),
                          _InfoRow('Name', patient['full_name'] as String),
                          _InfoRow('Phone', patient['phone'] as String),
                          if (patient['mobility_needs'] != null)
                            _InfoRow('Mobility Needs',
                                patient['mobility_needs'] as String),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                // Primary action button
                if (nextS != null)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ApiClient.patch(
                              '/api/v1/rides/$rideId/status',
                              body: {'status': nextS});
                          ref.invalidate(_rideDetailProvider(rideId));
                          if (nextS == 'completed' && context.mounted) {
                            context.pop();
                          }
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.message),
                                backgroundColor: Colors.red[700],
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00695C),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(nextL ?? '',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (status == 'active') ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel Ride'),
                          content: const Text(
                              'Are you sure you want to cancel this ride?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(false),
                                child: const Text('No')),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(ctx).pop(true),
                              child: const Text('Yes, Cancel',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await ApiClient.patch(
                              '/api/v1/rides/$rideId/status',
                              body: {'status': 'cancelled'});
                          if (context.mounted) context.pop();
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel Ride',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 100,
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13))),
          ],
        ),
      );
}
