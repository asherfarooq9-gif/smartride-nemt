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
import 'package:patient_app/shared/apple_list.dart';

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
        data: (ride) => ListView(
          padding: const EdgeInsets.symmetric(vertical: core.kSpaceLG),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: core.kSpaceLG),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _StatusBadge(ride.status),
              ),
            ),
            AppleSection(
              dividerIndent: appleIconDividerIndent,
              children: [
                AppleRow(
                  icon: Icons.location_on,
                  title: context.l10n.pickupTitle,
                  subtitle: ride.pickupAddress,
                  detail: true,
                ),
                if (ride.symptomText != null)
                  AppleRow(
                    icon: Icons.medical_information,
                    title: context.l10n.symptomsTitle,
                    subtitle: ride.symptomText!,
                    detail: true,
                  ),
                if (ride.createdAt != null)
                  AppleRow(
                    icon: Icons.access_time,
                    title: context.l10n.requestedTitle,
                    subtitle: formatIsoDateTime(ride.createdAt!,
                        lang: Localizations.localeOf(context).languageCode),
                    detail: true,
                  ),
                if (ride.status == core.RideStatus.completed &&
                    (ride.finalFarePkr ?? ride.estimatedFarePkr) != null)
                  AppleRow(
                    icon: Icons.payments_outlined,
                    title: context.l10n.fareLabel,
                    subtitle:
                        '${formatPkr((ride.finalFarePkr ?? ride.estimatedFarePkr)!)}\n'
                        '${context.l10n.fareHint}',
                    detail: true,
                  ),
              ],
            ),
            if (ride.driver != null)
              AppleSection(
                header: context.l10n.roleDriver,
                dividerIndent: appleIconDividerIndent,
                children: [
                  AppleRow(
                    icon: Icons.person,
                    title: (ride.driver!['full_name'] as String?) ??
                        context.l10n.roleDriver,
                    subtitle: _driverSubtitle(context, ride.driver!),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                core.kSpaceLG,
                core.kSpaceXL,
                core.kSpaceLG,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          ],
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
