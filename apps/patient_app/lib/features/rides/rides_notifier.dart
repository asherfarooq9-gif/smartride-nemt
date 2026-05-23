import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class Ride {
  final String id;
  final String status;
  final String rideType;
  final String pickupAddress;
  final String requestedAt;
  final double? estimatedFarePkr;
  final String? driverId;

  const Ride({
    required this.id,
    required this.status,
    required this.rideType,
    required this.pickupAddress,
    required this.requestedAt,
    this.estimatedFarePkr,
    this.driverId,
  });

  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
    id: j['id'] as String,
    status: j['status'] as String,
    rideType: j['ride_type'] as String,
    pickupAddress: (j['pickup_address'] as String?) ?? 'Unknown location',
    requestedAt: j['requested_at'] as String,
    estimatedFarePkr: (j['estimated_fare_pkr'] as num?)?.toDouble(),
    driverId: j['driver_id'] as String?,
  );
}

class RidesState {
  final List<Ride> rides;
  final Ride? activeRide;
  final int total;

  const RidesState({
    this.rides = const [],
    this.activeRide,
    this.total = 0,
  });
}

class RidesNotifier extends AsyncNotifier<RidesState> {
  @override
  Future<RidesState> build() => _fetch();

  Future<RidesState> _fetch() async {
    final data = await ApiClient.get('/api/v1/rides', query: {'page_size': 50})
        as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => Ride.fromJson(e as Map<String, dynamic>))
        .toList();
    final active = items.where((r) =>
      r.status == 'active' ||
      r.status == 'driver_assigned' ||
      r.status == 'pending'
    ).firstOrNull;
    return RidesState(
      rides: items,
      activeRide: active,
      total: (data['total'] as num).toInt(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final ridesNotifierProvider =
    AsyncNotifierProvider<RidesNotifier, RidesState>(RidesNotifier.new);
