import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:smartride_core/smartride_core.dart' as core;

/// Holds a single scheduled-ride booking that failed to submit because the
/// device was offline, and resubmits it once connectivity returns.
///
/// Deliberately scoped to scheduled rides only. Emergency ride requests must
/// never be silently queued — a patient in a medical emergency needs to know
/// immediately if the request didn't go through, not have the app quietly
/// hold it and give a false sense that help is on the way.
class PendingRideQueue {
  PendingRideQueue._();
  static final instance = PendingRideQueue._();

  static const _key = 'smartride_pending_scheduled_ride';

  Future<void> enqueue({
    required String pickupAddress,
    required DateTime scheduledFor,
    required String idempotencyKey,
    double? pickupLat,
    double? pickupLng,
    String? hospitalId,
  }) {
    final payload = jsonEncode({
      'pickup_address': pickupAddress,
      'scheduled_for': scheduledFor.toUtc().toIso8601String(),
      'idempotency_key': idempotencyKey,
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
      if (hospitalId != null) 'hospital_id': hospitalId,
    });
    return core.SecureStorage.instance.saveValue(_key, payload);
  }

  Future<bool> get hasPending async {
    final raw = await core.SecureStorage.instance.readValue(_key);
    return raw != null && raw.isNotEmpty;
  }

  Future<void> _clear() => core.SecureStorage.instance.saveValue(_key, '');

  /// Best-effort resubmit. If it fails again (still offline, or the backend
  /// rejects it), the booking stays queued and the next reconnect retries.
  Future<void> drain() async {
    final raw = await core.SecureStorage.instance.readValue(_key);
    if (raw == null || raw.isEmpty) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      await core.createScheduledRide(
        core.ScheduledRideRequest(
          pickupAddress: json['pickup_address'] as String,
          scheduledFor: DateTime.parse(json['scheduled_for'] as String),
          pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
          pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
          hospitalId: json['hospital_id'] as String?,
        ),
        idempotencyKey: json['idempotency_key'] as String?,
      );
      await _clear();
    } on Exception catch (e) {
      debugPrint('Pending ride resubmit failed, staying queued: $e');
    }
  }
}
