import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';

final _rideDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return await ApiClient.get('/api/v1/rides/$id/detail') as Map<String, dynamic>;
});

class RideDetailScreen extends ConsumerWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(_rideDetailProvider(rideId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
        data: (ride) {
          final patient = ride['patient'] as Map<String, dynamic>?;
          final driver = ride['driver'] as Map<String, dynamic>?;
          final hospital = ride['hospital'] as Map<String, dynamic>?;
          final triage = ride['triage'] as Map<String, dynamic>?;
          final status = ride['status'] as String;
          final requestedAt = ride['requested_at'] as String;
          final dt = DateTime.tryParse(requestedAt)?.toLocal();
          final formatted = dt != null
              ? DateFormat('dd MMM yyyy, h:mm a').format(dt)
              : requestedAt;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StatusBadge(status: status),
                const SizedBox(height: 16),
                _Section(title: 'Trip Info', children: [
                  _Row('Type', ride['ride_type'] as String),
                  _Row('Requested', formatted),
                  _Row('Pickup',
                      (ride['pickup_address'] as String?) ?? 'N/A'),
                  if (ride['estimated_fare_pkr'] != null)
                    _Row('Est. Fare', 'PKR ${ride['estimated_fare_pkr']}'),
                  if (ride['final_fare_pkr'] != null)
                    _Row('Final Fare', 'PKR ${ride['final_fare_pkr']}'),
                ]),
                if (patient != null) ...[
                  const SizedBox(height: 12),
                  _Section(title: 'Patient', children: [
                    _Row('Name', patient['full_name'] as String? ?? 'N/A'),
                    _Row('Phone', patient['phone'] as String? ?? 'N/A'),
                    if ((patient['mobility_needs'] as String?) != null)
                      _Row('Mobility Needs', patient['mobility_needs'] as String),
                  ]),
                ],
                if (driver != null) ...[
                  const SizedBox(height: 12),
                  _Section(title: 'Driver', children: [
                    _Row('Name', driver['full_name'] as String? ?? 'N/A'),
                    _Row('Phone', driver['phone'] as String? ?? 'N/A'),
                    _Row('Vehicle',
                        '${driver['vehicle_type'] ?? 'N/A'} — ${driver['vehicle_plate'] ?? 'N/A'}'),
                  ]),
                ],
                if (hospital != null) ...[
                  const SizedBox(height: 12),
                  _Section(title: 'Hospital', children: [
                    _Row('Name', hospital['name'] as String? ?? 'N/A'),
                    _Row('Address', hospital['address'] as String? ?? 'N/A'),
                    _Row('City', hospital['city'] as String? ?? 'N/A'),
                  ]),
                ],
                if (triage != null) ...[
                  const SizedBox(height: 12),
                  _Section(title: 'Triage', children: [
                    _Row('Symptoms', triage['symptom_text'] as String? ?? 'N/A'),
                    _Row('Specialty',
                        triage['predicted_specialty'] as String? ?? 'N/A'),
                    _Row('Severity', triage['severity_level'] as String? ?? 'N/A'),
                  ]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1565C0))),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
