import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';

final _historyProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (_) => getDriverEarnings(),
);

class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: kCanvas,
      appBar: AppBar(
        backgroundColor: kBlue600,
        foregroundColor: Colors.white,
        title: const Text('Trip History'),
        leading: const BackButton(),
      ),
      body: ref.watch(_historyProvider).when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: kBlue600),
            ),
            error: (e, _) => ErrorState(
              message: e is AppError ? e.message : 'Failed to load trip history',
              onRetry: () => ref.invalidate(_historyProvider),
            ),
            data: (data) {
              final rides = data['rides'] as List<dynamic>? ?? [];
              if (rides.isEmpty) {
                return const EmptyState(
                  message: 'No completed trips yet.\nAccept a ride to get started.',
                  icon: Icons.directions_car_outlined,
                );
              }
              return RefreshIndicator(
                color: kBlue600,
                onRefresh: () async => ref.invalidate(_historyProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      kSpaceLG, kSpaceMD, kSpaceLG, kSpaceLG),
                  itemCount: rides.length,
                  itemBuilder: (context, i) => _TripCard(
                    ride: rides[i] as Map<String, dynamic>,
                  ),
                ),
              );
            },
          ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final pickupAddress = ride['pickup_address'] as String? ?? 'Unknown pickup';
    final hospitalName = ride['hospital_name'] as String?;
    final fareRaw = (ride['fare_pkr'] as num?)?.toDouble() ?? 0;
    final rideType = ride['ride_type'] as String? ?? '';
    final completedAt = ride['completed_at'] as String?;

    final isEmergency = rideType == 'emergency';
    final fareFormatted = fareRaw
        .toInt()
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    final dateLabel = _formatDate(completedAt);
    final routeLabel = hospitalName != null
        ? '$pickupAddress → $hospitalName'
        : pickupAddress;

    return Container(
      margin: const EdgeInsets.only(bottom: kSpaceMD),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusXL),
        border: Border.all(color: kBorderLight),
        boxShadow: kCardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isEmergency
                        ? kRed50
                        : kBlue100,
                    borderRadius: BorderRadius.circular(kRadiusSM),
                  ),
                  child: Icon(
                    Icons.local_hospital_outlined,
                    size: 18,
                    color: isEmergency ? kRed600 : kBlue600,
                  ),
                ),
                const SizedBox(width: kSpaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routeLabel,
                        style: const TextStyle(
                          fontSize: kFontSmall,
                          fontWeight: FontWeight.w700,
                          color: kText900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: kFontCaption,
                          color: kText400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpaceSM),
                Text(
                  '+PKR $fareFormatted',
                  style: const TextStyle(
                    fontSize: kFontBody,
                    fontWeight: FontWeight.w800,
                    color: kOnlineGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpaceMD),
            const Divider(height: 1, color: kBorderLight),
            const SizedBox(height: kSpaceSM),
            Row(
              children: [
                _TypeBadge(isEmergency: isEmergency),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '—';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '—';
    final local = dt.toLocal();
    final now = DateTime.now();

    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final isYesterday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day - 1;

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final amPm = local.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour:$minute $amPm';

    if (isToday) return 'Today, $timeStr';
    if (isYesterday) return 'Yesterday, $timeStr';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, $timeStr';
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isEmergency});
  final bool isEmergency;

  @override
  Widget build(BuildContext context) {
    if (isEmergency) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpaceSM, vertical: 2),
        decoration: BoxDecoration(
          color: kRed50,
          borderRadius: BorderRadius.circular(kRadiusSM),
        ),
        child: const Text(
          'Emergency',
          style: TextStyle(
            fontSize: kFontCaption,
            fontWeight: FontWeight.w700,
            color: kRed600,
          ),
        ),
      );
    }
    return const Text(
      'Scheduled',
      style: TextStyle(
        fontSize: kFontCaption,
        fontWeight: FontWeight.w600,
        color: kText400,
      ),
    );
  }
}
