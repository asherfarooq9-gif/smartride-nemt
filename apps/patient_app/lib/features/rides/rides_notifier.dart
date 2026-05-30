import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;

final ridesProvider =
    AsyncNotifierProvider<RidesNotifier, core.RideListResponse>(
  RidesNotifier.new,
);

class RidesNotifier extends AsyncNotifier<core.RideListResponse> {
  @override
  Future<core.RideListResponse> build() => core.getMyRides();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => core.getMyRides());
  }
}

final activeRideProvider = Provider<core.RideResponse?>((ref) {
  final rides = ref.watch(ridesProvider);
  return rides.whenOrNull(
    data: (r) => r.items.where((e) => e.isActive).firstOrNull,
  );
});
