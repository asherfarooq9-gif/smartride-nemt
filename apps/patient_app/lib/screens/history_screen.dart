import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../core/theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _search = '';
  String _filterStatus = '';

  static const _statusOptions = ['', 'pending', 'completed', 'cancelled', 'driver_en_route'];

  @override
  void initState() {
    super.initState();
    ref.read(ridesProvider.notifier).loadHistory();
  }

  Color _statusColor(String status) => switch (status) {
    'completed' => kGreen,
    'cancelled' => kRed,
    'pending' => kAmber,
    _ => kBlue,
  };

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try { return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso).toLocal()); }
    catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ridesProvider);
    final rides = state.rides.where((r) {
      final status = r['status'] as String? ?? '';
      final type = r['ride_type'] as String? ?? '';
      final addr = r['pickup_address'] as String? ?? '';
      final matchesSearch = _search.isEmpty ||
          status.contains(_search.toLowerCase()) ||
          type.contains(_search.toLowerCase()) ||
          addr.toLowerCase().contains(_search.toLowerCase());
      final matchesFilter = _filterStatus.isEmpty || status == _filterStatus;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('History (${state.rides.length})')),
      body: Column(
        children: [
          // Search + filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search rides…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _filterStatus,
                  borderRadius: BorderRadius.circular(12),
                  underline: const SizedBox(),
                  items: _statusOptions.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.isEmpty ? 'All' : s.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setState(() => _filterStatus = v ?? ''),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(state.error!, style: const TextStyle(color: kRed)),
                        TextButton(onPressed: () => ref.read(ridesProvider.notifier).loadHistory(), child: const Text('Retry')),
                      ]))
                    : rides.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.history_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text('No rides found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                            if (_search.isNotEmpty || _filterStatus.isNotEmpty)
                              TextButton(onPressed: () => setState(() { _search = ''; _filterStatus = ''; }), child: const Text('Clear filters')),
                          ]))
                        : RefreshIndicator(
                            onRefresh: () => ref.read(ridesProvider.notifier).loadHistory(),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: rides.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final ride = rides[i];
                                final status = ride['status'] as String? ?? '';
                                final rideType = ride['ride_type'] as String? ?? '';
                                final isEmergency = rideType == 'emergency';
                                final fare = ride['final_fare_pkr'] ?? ride['estimated_fare_pkr'];
                                return GestureDetector(
                                  onTap: () => context.push('/rides/${ride['id']}'),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: (isEmergency ? kRed : kBlue).withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isEmergency ? Icons.emergency_rounded : Icons.calendar_month_rounded,
                                            color: isEmergency ? kRed : kBlue,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isEmergency ? 'Emergency Ride' : 'Scheduled Ride',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(_formatDate(ride['requested_at'] as String?), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                              if (fare != null) ...[
                                                const SizedBox(height: 2),
                                                Text('PKR ${(fare as num).toStringAsFixed(0)}', style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w500)),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _statusColor(status).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                status.replaceAll('_', ' '),
                                                style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
