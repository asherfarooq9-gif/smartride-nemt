import 'package:patient_app/core/ride_status_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/date_format.dart';
import 'package:patient_app/core/payment_methods.dart';
import 'package:patient_app/driver/money_format.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';

final rideDetailProvider =
    FutureProvider.autoDispose.family<core.RideDetailResponse, String>(
  (ref, id) => core.getRideDetail(id),
);

class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _CancelReasonDialog(),
    );
    if (reason == null || !context.mounted) return;
    try {
      await core.updateRideStatus(
        rideId,
        core.RideStatus.cancelled,
        cancelReason: reason.isEmpty ? 'Cancelled by patient' : reason,
      );
      if (!context.mounted) return;
      ref.invalidate(rideDetailProvider(rideId));
      ref.invalidate(ridesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.rideCancelled)),
      );
    } on core.AppError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } on Exception catch (e, st) {
      core.ErrorReporter.report('Cancelling a ride failed', e, st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotCancel)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(rideDetailProvider(rideId));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.rideDetails)),
      body: rideAsync.when(
        loading: () => const core.LoadingState(),
        error: (e, _) => core.ErrorState(
          message: e is core.AppError ? e.message : context.l10n.failedLoadRide,
          onRetry: () => ref.invalidate(rideDetailProvider(rideId)),
        ),
        data: (ride) => SingleChildScrollView(
          padding: const EdgeInsets.all(core.kSpaceLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusBadge(ride.status),
              const SizedBox(height: core.kSpaceLG),
              _InfoCard(
                title: context.l10n.pickupTitle,
                value: ride.pickupAddress,
                icon: Icons.location_on,
              ),
              if (ride.symptomText != null)
                _InfoCard(
                  title: context.l10n.symptomsTitle,
                  value: ride.symptomText!,
                  icon: Icons.medical_information,
                ),
              if (ride.createdAt != null)
                _InfoCard(
                  title: context.l10n.requestedTitle,
                  value: formatIsoDateTime(ride.createdAt!,
                      lang: Localizations.localeOf(context).languageCode),
                  icon: Icons.access_time,
                ),
              if (ride.status == core.RideStatus.completed &&
                  (ride.finalFarePkr ?? ride.estimatedFarePkr) != null)
                _InfoCard(
                  title: context.l10n.fareLabel,
                  value:
                      '${formatPkr((ride.finalFarePkr ?? ride.estimatedFarePkr)!)}\n'
                      '${context.l10n.fareHint}',
                  icon: Icons.payments_outlined,
                ),
              if (ride.driver != null) ...[
                const SizedBox(height: core.kSpaceSM),
                Text(
                  context.l10n.roleDriver,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      (ride.driver!['full_name'] as String?) ??
                          context.l10n.roleDriver,
                    ),
                    subtitle: Text(_driverSubtitle(context, ride.driver!)),
                  ),
                ),
              ],
              const SizedBox(height: core.kSpaceXL),
              if (ride.status == core.RideStatus.completed &&
                  ride.patientRating == null)
                core.PrimaryButton(
                  label: context.l10n.rateDriverAction,
                  onPressed: () => context.push('/rate-driver/$rideId'),
                  color: core.kPatientPrimary,
                ),
              if (ride.isTrackable)
                core.PrimaryButton(
                  label: context.l10n.trackLive,
                  onPressed: () => context.push('/tracking/$rideId'),
                  color: core.kPatientPrimary,
                ),
              if (ride.status == core.RideStatus.pending ||
                  ride.status == core.RideStatus.driverAssigned) ...[
                const SizedBox(height: core.kSpaceMD),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(context.l10n.cancelRide),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onPressed: () => _confirmCancel(context, ref),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Owns its text controller so it is disposed with the dialog.
/// Plate number, then the ways this driver takes payment, when they listed any.
String _driverSubtitle(BuildContext context, Map<String, dynamic> driver) {
  final plate = (driver['vehicle_plate'] as String?) ?? '';
  final methods = [
    for (final m in (driver['payment_methods'] as List<dynamic>? ?? const []))
      m.toString(),
  ];
  if (methods.isEmpty) return plate;
  final l = context.l10n;
  return '$plate\n${l.payByLabel}: ${paymentMethodsSummary(l, methods)}';
}

class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.cancelRide),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(hintText: context.l10n.reasonOptional),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.keepRide),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(context.l10n.cancelRide),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final core.RideStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: core.kSpaceLG,
        vertical: core.kSpaceSM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(core.kRadiusXL),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: core.kSpaceSM),
          Text(
            rideStatusLabel(context.l10n, status),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: core.kSpaceSM),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontSize: core.kFontSM)),
        subtitle: Text(value),
      ),
    );
  }
}
