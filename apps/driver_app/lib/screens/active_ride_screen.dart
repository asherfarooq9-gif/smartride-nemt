import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers.dart';
import '../core/theme.dart';

const _statusFlow = [
  ('driver_en_route', 'En Route', Icons.directions_car_rounded),
  ('patient_picked_up', 'Picked Up', Icons.person_rounded),
  ('arrived_at_hospital', 'At Hospital', Icons.local_hospital_rounded),
  ('completed', 'Complete', Icons.check_circle_rounded),
];

const _statusOrder = ['driver_assigned', 'driver_en_route', 'patient_picked_up', 'arrived_at_hospital', 'completed'];

class ActiveRideScreen extends ConsumerStatefulWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  GoogleMapController? _mapController;
  bool _mapExpanded = false;

  @override
  void initState() {
    super.initState();
    final token = ref.read(authProvider).token;
    if (token != null) {
      ref.read(gpsStreamProvider.notifier).startStreaming(widget.rideId, token);
    }
  }

  @override
  void dispose() {
    ref.read(gpsStreamProvider.notifier).stopStreaming();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _advanceStatus(String newStatus) async {
    await ref.read(activeRideProvider.notifier).updateStatus(widget.rideId, newStatus);
    if (!mounted) return;
    if (newStatus == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride completed!'), backgroundColor: kGreen),
      );
      context.go('/');
    }
  }

  String? _nextStatus(String? current) {
    if (current == 'driver_assigned') return 'driver_en_route';
    for (int i = 0; i < _statusFlow.length - 1; i++) {
      if (_statusFlow[i].$1 == current) return _statusFlow[i + 1].$1;
    }
    return null;
  }

  String _nextLabel(String? current) {
    final next = _nextStatus(current);
    for (final (status, label, _) in _statusFlow) {
      if (status == next) return label;
    }
    return 'Update Status';
  }

  Future<void> _callPhone(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(activeRideProvider);
    final isStreaming = ref.watch(gpsStreamProvider);
    final currentStatus = ride?['status'] as String?;
    final nextStatus = _nextStatus(currentStatus);

    final pickupLat = (ride?['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (ride?['pickup_lng'] as num?)?.toDouble();
    final isEmergency = ride?['ride_type'] == 'emergency';

    final patient = ride?['patient'] as Map<String, dynamic>?;
    final hospital = ride?['hospital'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEmergency ? 'Emergency Ride' : 'Scheduled Ride'),
        backgroundColor: isEmergency ? kRed : kGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: Icon(_mapExpanded ? Icons.expand_less_rounded : Icons.map_rounded),
            tooltip: _mapExpanded ? 'Collapse map' : 'Expand map',
            onPressed: () => setState(() => _mapExpanded = !_mapExpanded),
          ),
        ],
      ),
      body: Column(
        children: [
          // GPS indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: isStreaming ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(isStreaming ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                    color: isStreaming ? kGreen : kAmber, size: 16),
                const SizedBox(width: 8),
                Text(
                  isStreaming ? 'GPS streaming active' : 'GPS not streaming',
                  style: TextStyle(color: isStreaming ? kGreen : kAmber, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),

          // Map
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _mapExpanded ? MediaQuery.of(context).size.height * 0.55 : 200,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: pickupLat != null && pickupLng != null
                    ? LatLng(pickupLat, pickupLng)
                    : const LatLng(33.6844, 73.0479),
                zoom: 15,
              ),
              onMapCreated: (c) => _mapController = c,
              markers: {
                if (pickupLat != null && pickupLng != null)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(pickupLat, pickupLng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'Patient Pickup'),
                  ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),

          // Bottom panel
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status progress
                  _StatusTimeline(currentStatus: currentStatus),
                  const SizedBox(height: 12),

                  // Patient info
                  if (patient != null || ride != null)
                    _InfoCard(
                      title: 'Patient',
                      icon: Icons.person_rounded,
                      color: kBlue,
                      trailing: _callButton(() => _callPhone(patient?['phone'] as String?)),
                      children: [
                        _InfoRow(label: 'Name', value: patient?['full_name'] as String? ?? 'Patient'),
                        if ((ride?['pickup_address'] as String?) != null)
                          _InfoRow(label: 'Pickup', value: ride!['pickup_address'] as String),
                        if (patient?['mobility_needs'] != null)
                          _InfoRow(label: 'Mobility', value: patient!['mobility_needs'] as String),
                      ],
                    ),
                  if (patient != null || ride != null) const SizedBox(height: 8),

                  // Hospital info
                  if (hospital != null)
                    _InfoCard(
                      title: 'Destination Hospital',
                      icon: Icons.local_hospital_rounded,
                      color: kRed,
                      children: [
                        _InfoRow(label: 'Name', value: hospital['name'] as String? ?? '—'),
                        if (hospital['address'] != null)
                          _InfoRow(label: 'Address', value: hospital['address'] as String),
                      ],
                    ),
                  if (hospital != null) const SizedBox(height: 12),

                  // Advance button
                  if (nextStatus != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isEmergency ? kRed : kGreen,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(_nextLabel(currentStatus), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      onPressed: () => _advanceStatus(nextStatus),
                    ),
                  if (currentStatus == 'completed')
                    const Center(
                      child: Text('Ride completed!', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _callButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.phone_rounded, size: 18, color: kGreen),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String? currentStatus;
  const _StatusTimeline({this.currentStatus});

  bool _isBefore(String? current, String check) {
    final ci = _statusOrder.indexOf(current ?? '');
    final ti = _statusOrder.indexOf(check);
    return ti < ci;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFlow.asMap().entries.map((entry) {
          final i = entry.key;
          final (status, label, icon) = entry.value;
          final isDone = _isBefore(currentStatus, status);
          final isCurrent = currentStatus == status || (status == 'driver_en_route' && currentStatus == 'driver_assigned');

          return Row(
            children: [
              if (i > 0)
                Container(
                  width: 20,
                  height: 2,
                  color: isDone ? kGreen : const Color(0xFFE5E7EB),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent ? kGreen : (isDone ? kGreen.withValues(alpha: 0.1) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isCurrent ? kGreen : (isDone ? kGreen.withValues(alpha: 0.3) : const Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: isCurrent ? Colors.white : (isDone ? kGreen : Colors.grey)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? Colors.white : (isDone ? kGreen : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final Widget? trailing;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const Divider(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
