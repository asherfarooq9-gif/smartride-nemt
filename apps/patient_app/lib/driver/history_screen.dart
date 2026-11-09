import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/driver/money_format.dart';
import 'package:patient_app/shared/apple_list.dart';

final _historyProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (_) => getDriverEarnings(),
);

class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tripHistory),
        leading: const BackButton(),
      ),
      body: ref.watch(_historyProvider).when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => ErrorState(
              message:
                  e is AppError ? e.message : context.l10n.failedLoadHistory,
              onRetry: () => ref.invalidate(_historyProvider),
            ),
            data: (data) {
              final rides = data['rides'] as List<dynamic>? ?? [];
              if (rides.isEmpty) {
                return EmptyState(
                  message: context.l10n.noCompletedTrips,
                  icon: Icons.directions_car_outlined,
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(_historyProvider),
                child: ListView(
                  // Always scrollable so pull-to-refresh works on a short list.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: kSpaceXXL),
                  children: [
                    AppleSection(
                      dividerIndent: appleIconDividerIndent,
                      children: [
                        for (final ride in rides)
                          _tripRow(context, ride as Map<String, dynamic>),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}

/// One completed trip: route, when and with which kind of ride, and the fare.
Widget _tripRow(BuildContext context, Map<String, dynamic> ride) {
  final pickupAddress = ride['pickup_address'] as String? ?? 'Unknown pickup';
  final hospitalName = ride['hospital_name'] as String?;
  final fareRaw = (ride['fare_pkr'] as num?)?.toDouble() ?? 0;
  final completedAt = ride['completed_at'] as String?;
  final isEmergency = (ride['ride_type'] as String? ?? '') == 'emergency';
  final fareFormatted = formatPkr(fareRaw);
  final routeLabel =
      hospitalName != null ? '$pickupAddress → $hospitalName' : pickupAddress;
  final kind =
      isEmergency ? context.l10n.emergencyWord : context.l10n.scheduled;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AppleRow(
    icon: Icons.local_hospital_outlined,
    iconColor: isEmergency ? kEmergencyRed : null,
    title: routeLabel,
    subtitle: '${_formatDate(completedAt)} · $kind',
    trailing: Text(
      fareFormatted == 'PKR 0' ? fareFormatted : '+$fareFormatted',
      style: TextStyle(
        fontSize: kFontBody,
        fontWeight: FontWeight.w700,
        color: isDark ? kIosGreen : kOnlineGreen,
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, $timeStr';
}
