import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class RideHistoryScreen extends ConsumerStatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  String _search = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideHistoryProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(rideHistoryProvider);

    final filtered = history.rides.where((r) {
      final matchSearch = _search.isEmpty ||
          (r['id'] as String? ?? '').toLowerCase().contains(_search.toLowerCase()) ||
          (r['ride_type'] as String? ?? '').contains(_search.toLowerCase());
      final matchStatus = _statusFilter == null || r['status'] == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: Column(
        children: [
          // Summary row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _SummaryChip(label: 'Total', value: '${history.rides.length}', color: kBlue),
                const SizedBox(width: 8),
                _SummaryChip(label: 'Completed', value: '${history.completedCount}', color: kGreen),
                const SizedBox(width: 8),
                _SummaryChip(label: 'Emergency', value: '${history.emergencyCount}', color: kRed),
                const Spacer(),
                Text(
                  'PKR ${history.totalEarnings.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kGreen),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search + filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search rides…',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _statusFilter,
                    hint: const Text('Status', style: TextStyle(fontSize: 13)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      ...['completed', 'cancelled', 'driver_assigned', 'patient_picked_up']
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)),
                              )),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: history.loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: () => ref.read(rideHistoryProvider.notifier).load(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _RideCard(ride: filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('No rides found', style: TextStyle(color: Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final status = ride['status'] as String? ?? '';
    final rideType = ride['ride_type'] as String? ?? '';
    final isEmergency = rideType == 'emergency';
    final fare = ride['final_fare_pkr'] as num?;
    final estFare = ride['estimated_fare_pkr'] as num?;
    final date = _formatDate(ride['requested_at'] as String?);

    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isEmergency ? kRed : kBlue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(isEmergency ? Icons.emergency_rounded : Icons.calendar_month_rounded,
                color: isEmergency ? kRed : kBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEmergency ? 'Emergency Ride' : 'Scheduled Ride',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fare != null ? 'PKR ${fare.toStringAsFixed(0)}' : (estFare != null ? '~PKR ${estFare.toStringAsFixed(0)}' : '—'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    if (s == 'completed') return kGreen;
    if (s == 'cancelled') return kRed;
    return kBlue;
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('dd MMM, HH:mm').format(dt.toLocal());
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
