import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:patient_app/core/providers.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final ridesProvider =
    AsyncNotifierProvider<RidesNotifier, core.RideListResponse>(
  RidesNotifier.new,
);

class RidesNotifier extends AsyncNotifier<core.RideListResponse> {
  @override
  Future<core.RideListResponse> build() {
    // Rebuild (and drop the previous account's rides) when the session changes.
    ref.watch(sessionTokenProvider);
    return fetchRides();
  }

  @protected
  Future<core.RideListResponse> fetchRides() => core.getMyRides();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(fetchRides);
  }
}

final activeRideProvider = Provider<core.RideResponse?>((ref) {
  final rides = ref.watch(ridesProvider);
  return rides.whenOrNull(
    data: (r) => r.items.where((e) => e.isActive).firstOrNull,
  );
});
