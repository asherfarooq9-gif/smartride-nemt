import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final _earningsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (_) => core.getDriverEarnings(),
);

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(_earningsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.myEarnings)),
      body: earningsAsync.when(
        loading: () => core.LoadingState(message: context.l10n.loadingEarnings),
        error: (e, _) => core.ErrorState(
          message:
              e is core.AppError ? e.message : context.l10n.failedLoadEarnings,
          onRetry: () => ref.refresh(_earningsProvider),
        ),
        data: (data) {
          final rides = (data['rides'] as List<dynamic>? ?? []);
          return Column(
            children: [
              _SummaryCard(
                totalEarned:
                    (data['total_earned_pkr'] as num?)?.toDouble() ?? 0,
                rideCount: (data['ride_count'] as int?) ?? 0,
              ),
              Expanded(
                child: rides.isEmpty
                    ? core.EmptyState(
                        message: context.l10n.noCompletedRidesYet,
                        icon: Icons.payments_outlined,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(core.kSpaceLG),
                        itemCount: rides.length,
                        itemBuilder: (context, i) {
                          final ride = rides[i] as Map<String, dynamic>;
                          return _EarningsTile(ride: ride);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalEarned, required this.rideCount});

  final double totalEarned;
  final int rideCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(core.kSpaceLG),
      padding: const EdgeInsets.all(core.kSpaceXL),
      decoration: BoxDecoration(
        color: core.kDriverPrimary,
        borderRadius: BorderRadius.circular(core.kRadiusLG),
      ),
      child: Column(
        children: [
          Text(
            context.l10n.totalEarned,
            style:
                const TextStyle(color: Colors.white70, fontSize: core.kFontSM),
          ),
          const SizedBox(height: core.kSpaceXS),
          Text(
            'PKR ${totalEarned.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: core.kSpaceXS),
          Text(
            context.l10n.completedRides(rideCount),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _EarningsTile extends StatelessWidget {
  const _EarningsTile({required this.ride});

  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final fare = (ride['fare_pkr'] as num?)?.toDouble() ?? 0;
    final address = ride['pickup_address'] as String? ?? 'Unknown';
    final completedAt = ride['completed_at'] as String?;
    final isEmergency = ride['ride_type'] == 'emergency';

    return Card(
      margin: const EdgeInsets.only(bottom: core.kSpaceSM),
      child: ListTile(
        leading: Icon(
          isEmergency ? Icons.emergency : Icons.calendar_today,
          color: isEmergency ? core.kEmergencyRed : core.kDriverPrimary,
        ),
        title: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: completedAt != null ? Text(_formatDate(completedAt)) : null,
        trailing: Text(
          'PKR ${fare.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: core.kFontMD,
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } on FormatException {
      return iso;
    }
  }
}
