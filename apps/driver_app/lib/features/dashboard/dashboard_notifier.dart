import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import '../../core/providers.dart';

class DashboardState {
  const DashboardState({
    this.driver,
    this.pendingRides = const [],
    this.isLoading = false,
    this.error,
  });

  final core.DriverResponse? driver;
  final List<core.RideResponse> pendingRides;
  final bool isLoading;
  final String? error;

  bool get isOnline => driver?.isOnline ?? false;

  DashboardState copyWith({
    core.DriverResponse? driver,
    List<core.RideResponse>? pendingRides,
    bool? isLoading,
    String? error,
  }) =>
      DashboardState(
        driver: driver ?? this.driver,
        pendingRides: pendingRides ?? this.pendingRides,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(ref),
);

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._ref) : super(const DashboardState()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        core.getDriverMe(),
        core.getDriverPendingRides(),
      ]);
      state = DashboardState(
        driver: results[0] as core.DriverResponse,
        pendingRides: results[1] as List<core.RideResponse>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is core.AppError ? e.message : 'Failed to load',
      );
    }
  }

  Future<void> toggleOnline() async {
    final current = state.driver?.status ?? core.DriverStatus.offline;
    final next = current == core.DriverStatus.offline
        ? core.DriverStatus.available
        : core.DriverStatus.offline;
    try {
      await core.updateDriverStatus(next);
      await refresh();
    } catch (e) {
      state = state.copyWith(
        error: e is core.AppError ? e.message : 'Status update failed',
      );
    }
  }

  Future<bool> acceptRide(String rideId) async {
    try {
      await core.acceptRide(rideId);
      await _ref.read(gpsStreamProvider.notifier).startStreaming(rideId);
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is core.AppError ? e.message : 'Failed to accept ride',
      );
      return false;
    }
  }
}
