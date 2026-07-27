import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/core/pending_ride_queue.dart';
import 'package:smartride_core/smartride_core.dart' as core;

sealed class ScheduleSubmitResult {
  const ScheduleSubmitResult();
}

class ScheduleSubmitSuccess extends ScheduleSubmitResult {
  const ScheduleSubmitSuccess(this.ride);
  final core.RideResponse ride;
}

/// The device was offline; the booking was queued and will resubmit
/// automatically once connectivity returns (see PendingRideQueue).
class ScheduleSubmitQueuedOffline extends ScheduleSubmitResult {
  const ScheduleSubmitQueuedOffline();
}

class ScheduleSubmitFailed extends ScheduleSubmitResult {
  const ScheduleSubmitFailed(this.error);
  final Object error;
}

final scheduleSubmitProvider =
    StateNotifierProvider.autoDispose<ScheduleSubmitNotifier, AsyncValue<void>>(
  (_) => ScheduleSubmitNotifier(),
);

class ScheduleSubmitNotifier extends StateNotifier<AsyncValue<void>> {
  ScheduleSubmitNotifier() : super(const AsyncValue.data(null));

  Future<ScheduleSubmitResult> submit({
    required String pickupAddress,
    required DateTime scheduledFor,
    String? hospitalId,
  }) async {
    state = const AsyncValue.loading();
    // One key for this whole submission attempt, reused across the network
    // retry and the offline-queue retry below — the backend dedupes by this
    // value, so a fresh key per retry would defeat the point.
    final idempotencyKey = core.generateIdempotencyKey();
    try {
      final ride = await core.createScheduledRide(
        core.ScheduledRideRequest(
          pickupAddress: pickupAddress,
          scheduledFor: scheduledFor,
          hospitalId: hospitalId,
        ),
        idempotencyKey: idempotencyKey,
      );
      state = const AsyncValue.data(null);
      return ScheduleSubmitSuccess(ride);
    } on core.NetworkError {
      // Offline: don't just fail — queue it and resubmit automatically once
      // connectivity returns, so the patient doesn't lose the whole form.
      await PendingRideQueue.instance.enqueue(
        pickupAddress: pickupAddress,
        scheduledFor: scheduledFor,
        idempotencyKey: idempotencyKey,
        hospitalId: hospitalId,
      );
      state = const AsyncValue.data(null);
      return const ScheduleSubmitQueuedOffline();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return ScheduleSubmitFailed(e);
    }
  }
}
