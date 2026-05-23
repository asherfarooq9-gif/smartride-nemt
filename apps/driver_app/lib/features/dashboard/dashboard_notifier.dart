import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class PendingRide {
  final String id;
  final String pickupAddress;
  final String rideType;
  final String requestedAt;

  const PendingRide({
    required this.id,
    required this.pickupAddress,
    required this.rideType,
    required this.requestedAt,
  });

  factory PendingRide.fromJson(Map<String, dynamic> j) => PendingRide(
    id: j['id'] as String,
    pickupAddress: (j['pickup_address'] as String?) ?? 'Unknown location',
    rideType: j['ride_type'] as String,
    requestedAt: j['requested_at'] as String,
  );
}

class DashboardState {
  final bool isOnline;
  final List<PendingRide> pendingRides;

  const DashboardState({
    this.isOnline = false,
    this.pendingRides = const [],
  });

  DashboardState copyWith({bool? isOnline, List<PendingRide>? pendingRides}) =>
      DashboardState(
        isOnline: isOnline ?? this.isOnline,
        pendingRides: pendingRides ?? this.pendingRides,
      );
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() => _fetch();

  Future<DashboardState> _fetch() async {
    final data = await ApiClient.get('/api/v1/rides',
            query: {'status': 'pending', 'page_size': 20})
        as Map<String, dynamic>;
    final rides = (data['items'] as List)
        .map((e) => PendingRide.fromJson(e as Map<String, dynamic>))
        .toList();
    return DashboardState(pendingRides: rides);
  }

  Future<void> toggleOnline() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final newStatus = !current.isOnline;
    try {
      await ApiClient.patch('/api/v1/drivers/me/status',
          body: {'status': newStatus ? 'available' : 'offline'});
      state = AsyncData(current.copyWith(isOnline: newStatus));
    } on ApiException catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(
        DashboardNotifier.new);
