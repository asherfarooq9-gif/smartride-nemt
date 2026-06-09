import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/providers.dart';

enum AcceptResult { success, alreadyTaken, error }

class DashboardState {
  const DashboardState({
    this.driver,
    this.pendingRides = const [],
    this.todayEarningsPkr = 0.0,
    this.isLoading = false,
    this.error,
  });

  final core.DriverResponse? driver;
  final List<core.RideResponse> pendingRides;
  final double todayEarningsPkr;
  final bool isLoading;
  final String? error;

  bool get isOnline => driver?.isOnline ?? false;

  DashboardState copyWith({
    core.DriverResponse? driver,
    List<core.RideResponse>? pendingRides,
    double? todayEarningsPkr,
    bool? isLoading,
    String? error,
  }) =>
      DashboardState(
        driver: driver ?? this.driver,
        pendingRides: pendingRides ?? this.pendingRides,
        todayEarningsPkr: todayEarningsPkr ?? this.todayEarningsPkr,
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
      final driver = await core.getDriverMe();
      final rides = await core.getDriverPendingRides();
      final earnings = await core.getDriverEarnings();
      state = DashboardState(
        driver: driver,
        pendingRides: rides,
        todayEarningsPkr: _calcTodayEarnings(earnings),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is core.AppError ? e.message : 'Failed to load',
      );
    }
  }

  void declineRide(String rideId) {
    state = state.copyWith(
      pendingRides: state.pendingRides
          .where((r) => r.id.toString() != rideId)
          .toList(),
    );
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

  Future<AcceptResult> acceptRide(String rideId) async {
    try {
      await core.acceptRide(rideId);
      await _ref.read(gpsStreamProvider.notifier).startStreaming(rideId);
      return AcceptResult.success;
    } catch (e) {
      if (e is core.AppError && e.statusCode == 409) {
        return AcceptResult.alreadyTaken;
      }
      state = state.copyWith(
        error: e is core.AppError ? e.message : 'Failed to accept ride',
      );
      return AcceptResult.error;
    }
  }

  double _calcTodayEarnings(Map<String, dynamic> data) {
    final rides = data['rides'] as List<dynamic>? ?? [];
    final today = DateTime.now();
    var total = 0.0;
    for (final ride in rides) {
      final map = ride as Map<String, dynamic>;
      final completedAtStr = map['completed_at'] as String?;
      if (completedAtStr == null) continue;
      final completedAt = DateTime.tryParse(completedAtStr)?.toLocal();
      if (completedAt == null) continue;
      if (completedAt.year == today.year &&
          completedAt.month == today.month &&
          completedAt.day == today.day) {
        total += (map['fare_pkr'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }
}
