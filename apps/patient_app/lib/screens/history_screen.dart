import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(ridesProvider.notifier).loadHistory();
  }

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      'pending' => Colors.orange,
      _ => Colors.blue,
    };
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ridesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: Builder(builder: (_) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null) {
          return Center(child: Text(state.error!, style: const TextStyle(color: Colors.red)));
        }
        if (state.rides.isEmpty) {
          return const Center(child: Text('No rides yet.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final ride = state.rides[i];
            final status = ride['status'] as String? ?? '';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                  child: Icon(
                    ride['ride_type'] == 'emergency' ? Icons.emergency : Icons.calendar_today,
                    color: _statusColor(status),
                  ),
                ),
                title: Text(
                  ride['ride_type'] == 'emergency' ? 'Emergency Ride' : 'Scheduled Ride',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(_formatDate(ride['requested_at'] as String?)),
                trailing: Chip(
                  label: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11)),
                  backgroundColor: _statusColor(status).withValues(alpha: 0.12),
                ),
                onTap: () => context.push('/tracking/${ride['id']}'),
              ),
            );
          },
        );
      }),
    );
  }
}
