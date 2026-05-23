import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideCard extends StatelessWidget {
  final String rideId;
  final String status;
  final String rideType;
  final String pickupAddress;
  final String requestedAt;
  final double? estimatedFare;
  final VoidCallback? onTap;

  const RideCard({
    super.key,
    required this.rideId,
    required this.status,
    required this.rideType,
    required this.pickupAddress,
    required this.requestedAt,
    this.estimatedFare,
    this.onTap,
  });

  Color _statusColor(BuildContext context) => switch (status) {
    'completed' => Colors.green,
    'cancelled' => Colors.red,
    'active' || 'driver_assigned' => Theme.of(context).colorScheme.primary,
    _ => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(requestedAt)?.toLocal();
    final formatted = dt != null
        ? DateFormat('dd MMM yyyy, h:mm a').format(dt)
        : requestedAt;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    rideType == 'emergency' ? Icons.emergency : Icons.directions_car,
                    size: 16,
                    color: rideType == 'emergency' ? Colors.red : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    rideType.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pickupAddress,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formatted,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (estimatedFare != null) ...[
                    const Spacer(),
                    Text(
                      'PKR ${estimatedFare!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
