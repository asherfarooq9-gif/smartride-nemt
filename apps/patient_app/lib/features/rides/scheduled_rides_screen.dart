import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/ride_card.dart';
import '../../widgets/loading_overlay.dart';
import 'rides_notifier.dart';

const _statuses = ['all', 'pending', 'active', 'completed', 'cancelled'];

class ScheduledRidesScreen extends ConsumerStatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  ConsumerState<ScheduledRidesScreen> createState() =>
      _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState
    extends ConsumerState<ScheduledRidesScreen> {
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(ridesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Rides')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statuses.length,
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final selected = s == _selectedStatus;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_capitalize(s)),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedStatus = s),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ridesAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(5, (_) => const SkeletonCard()),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (state) {
                final filtered = _selectedStatus == 'all'
                    ? state.rides
                    : state.rides
                        .where((r) => r.status == _selectedStatus)
                        .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_car_outlined,
                            size: 56, color: Color(0xFFBBD3F5)),
                        const SizedBox(height: 16),
                        Text(
                          _selectedStatus == 'all'
                              ? 'No rides yet'
                              : 'No ${_capitalize(_selectedStatus)} rides',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your ride history will appear here.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(ridesNotifierProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => RideCard(
                      rideId: filtered[i].id,
                      status: filtered[i].status,
                      rideType: filtered[i].rideType,
                      pickupAddress: filtered[i].pickupAddress,
                      requestedAt: filtered[i].requestedAt,
                      estimatedFare: filtered[i].estimatedFarePkr,
                      onTap: () => context.push('/ride/${filtered[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
