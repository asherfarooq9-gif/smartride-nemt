import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class RideDetailScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends ConsumerState<RideDetailScreen> {
  Map<String, dynamic>? _ride;
  bool _loading = true;
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final data = await ref.read(ridesProvider.notifier).getRideDetail(widget.rideId);
    if (!mounted) return;
    setState(() {
      _ride = data;
      _loading = false;
      _error = data == null ? 'Failed to load ride details' : null;
    });
  }

  bool get _canCancel {
    final status = _ride?['status'] as String? ?? '';
    return status == 'pending' || status == 'driver_assigned';
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Ride', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    final success = await ref.read(ridesProvider.notifier).cancelRide(widget.rideId);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride cancelled'), backgroundColor: kGreen));
      context.go('/history');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel ride'), backgroundColor: kRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: kRed)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final ride = _ride!;
    final status = ride['status'] as String? ?? '';
    final rideType = ride['ride_type'] as String? ?? '';
    final driver = ride['driver'] as Map<String, dynamic>?;
    final hospital = ride['hospital'] as Map<String, dynamic>?;
    final triage = ride['triage'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Status banner
        _StatusBanner(status: status, rideType: rideType),
        const SizedBox(height: 20),

        // Pickup info
        _InfoSection(title: 'Pickup', icon: Icons.location_on_rounded, color: kBlue, items: [
          _DetailRow('Address', ride['pickup_address'] as String? ?? '${(ride['pickup_lat'] as num?)?.toStringAsFixed(4)}, ${(ride['pickup_lng'] as num?)?.toStringAsFixed(4)}'),
          _DetailRow('Requested', _formatDate(ride['requested_at'] as String?)),
          if (ride['scheduled_for'] != null) _DetailRow('Scheduled For', _formatDate(ride['scheduled_for'] as String?)),
          if (ride['driver_assigned_at'] != null) _DetailRow('Driver Assigned', _formatDate(ride['driver_assigned_at'] as String?)),
          if (ride['completed_at'] != null) _DetailRow('Completed', _formatDate(ride['completed_at'] as String?)),
        ]),
        const SizedBox(height: 16),

        // Fare
        if (ride['estimated_fare_pkr'] != null || ride['final_fare_pkr'] != null) ...[
          _InfoSection(title: 'Fare', icon: Icons.payments_rounded, color: kGreen, items: [
            if (ride['estimated_fare_pkr'] != null) _DetailRow('Estimated', 'PKR ${(ride['estimated_fare_pkr'] as num).toStringAsFixed(0)}'),
            if (ride['final_fare_pkr'] != null) _DetailRow('Final', 'PKR ${(ride['final_fare_pkr'] as num).toStringAsFixed(0)}'),
          ]),
          const SizedBox(height: 16),
        ],

        // Driver
        if (driver != null) ...[
          _InfoSection(title: 'Driver', icon: Icons.person_rounded, color: const Color(0xFF7C3AED), items: [
            _DetailRow('Name', driver['full_name'] as String? ?? '—'),
            _DetailRow('Vehicle', driver['vehicle_plate'] as String? ?? '—'),
            _DetailRow('Type', driver['vehicle_type'] as String? ?? '—'),
          ]),
          const SizedBox(height: 16),
        ],

        // Hospital
        if (hospital != null) ...[
          _InfoSection(title: 'Hospital', icon: Icons.local_hospital_rounded, color: kRed, items: [
            _DetailRow('Name', hospital['name'] as String? ?? '—'),
            _DetailRow('Address', '${hospital['address']}, ${hospital['city']}'),
          ]),
          const SizedBox(height: 16),
        ],

        // Triage
        if (triage != null) ...[
          _InfoSection(title: 'AI Triage', icon: Icons.psychology_rounded, color: kAmber, items: [
            _DetailRow('Symptoms', triage['symptom_text'] as String? ?? '—'),
            _DetailRow('Specialty', (triage['predicted_specialty'] as String? ?? '').replaceAll('_', ' ')),
            _DetailRow('Severity', 'Level ${triage['severity_level']}'),
            _DetailRow('Confidence', '${((triage['confidence_score'] as num? ?? 0) * 100).toStringAsFixed(1)}%'),
          ]),
          const SizedBox(height: 16),
        ],

        // Cancel button
        if (_canCancel) ...[
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _cancelling ? null : _cancel,
            style: ElevatedButton.styleFrom(backgroundColor: kRed),
            child: _cancelling
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Cancel Ride'),
          ),
        ],
      ],
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try { return DateTime.parse(iso).toLocal().toString().substring(0, 16); } catch (_) { return iso; }
  }
}

class _StatusBanner extends StatelessWidget {
  final String status, rideType;
  const _StatusBanner({required this.status, required this.rideType});

  @override
  Widget build(BuildContext context) {
    final colors = <String, Color>{
      'pending': kAmber, 'driver_assigned': kBlue, 'driver_en_route': const Color(0xFF4F46E5),
      'patient_picked_up': const Color(0xFF0891B2), 'arrived_at_hospital': const Color(0xFF7C3AED),
      'completed': kGreen, 'cancelled': kRed,
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Icon(rideType == 'emergency' ? Icons.emergency_rounded : Icons.calendar_month_rounded, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rideType.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              Text(status.replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> items;
  const _InfoSection({required this.title, required this.icon, required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...items,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
