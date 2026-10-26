import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/core/location.dart';
import 'package:patient_app/core/providers.dart';

/// How often an online driver tells the server they are still reachable.
/// Dispatch only considers drivers seen in the last 120 seconds, so this must
/// stay well below that.
const driverHeartbeatInterval = Duration(seconds: 30);

enum HeartbeatResult { sent, noLocation, failed }

/// One heartbeat: read the position and post it. Never throws.
/// [reportErrors] lets the caller log only the first failure of a streak.
Future<HeartbeatResult> sendHeartbeat({
  required Future<Position?> Function() readLocation,
  required Future<void> Function(double lat, double lng) post,
  bool reportErrors = true,
}) async {
  final pos = await readLocation();
  if (pos == null) return HeartbeatResult.noLocation;
  try {
    await post(pos.latitude, pos.longitude);
    return HeartbeatResult.sent;
  } on core.AppError catch (e, st) {
    if (reportErrors) core.ErrorReporter.report('Driver heartbeat failed', e, st);
    return HeartbeatResult.failed;
  }
}

/// [successWithoutTracking]: the ride is accepted but location sharing could
/// not start, so the driver must be told the patient cannot see them.
/// [notNearby]: the server refused because the ride is not within reach of this
/// driver's last known position (or the position is unknown).
enum AcceptResult {
  success,
  successWithoutTracking,
  alreadyTaken,
  notNearby,
  error,
}

/// What an accept attempt came to, and the words to show the driver. Every
/// failure carries a message: the next 15 s refresh clears `state.error`, so a
/// refusal shown only there is gone before it can be read.
class AcceptOutcome {
  const AcceptOutcome(this.result, {this.message});
  final AcceptResult result;
  final String? message;
}

/// Maps a failed accept to an outcome. The server's own message is kept because
/// a 409 does not always mean "taken" ("go online first" is also a 409).
AcceptOutcome acceptOutcomeForError(core.AppError e) {
  final message = e.message.isEmpty ? 'Could not accept the ride' : e.message;
  switch (e.statusCode) {
    case 409:
      return AcceptOutcome(AcceptResult.alreadyTaken, message: message);
    case 403:
      return AcceptOutcome(AcceptResult.notNearby, message: message);
    default:
      return AcceptOutcome(AcceptResult.error, message: message);
  }
}

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
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  ref.watch(sessionTokenProvider);
  return DashboardNotifier(ref);
});

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._ref) : super(const DashboardState()) {
    refresh();
  }

  final Ref _ref;

  /// Rides this driver passed on; they stay hidden on later refreshes.
  final _declined = <String>{};

  Timer? _heartbeat;
  bool _isBeatFailing = false;

  /// Runs while the driver is online so dispatch can see them. During a ride
  /// the GPS stream already posts location, so the beat skips itself.
  // ponytail: runs only while the app process is alive; background support
  // (foreground service) if pilot drivers lock their screens.
  void _syncHeartbeat() {
    if (!state.isOnline) {
      _heartbeat?.cancel();
      _heartbeat = null;
      return;
    }
    if (_heartbeat != null) return;
    _heartbeat = Timer.periodic(driverHeartbeatInterval, (_) => _beat());
    _beat();
  }

  Future<void> _beat() async {
    if (_ref.read(gpsStreamProvider).isActive) return;
    final result = await sendHeartbeat(
      readLocation: _ref.read(locationReaderProvider),
      post: core.updateDriverLocation,
      reportErrors: !_isBeatFailing,
    );
    if (!mounted) return;
    _isBeatFailing = result != HeartbeatResult.sent;
    if (result == HeartbeatResult.noLocation) {
      state = state.copyWith(
        error: 'Location is off. You will not receive ride requests '
            'until you turn it on.',
      );
    }
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final (driver, rides, earnings) = await (
        core.getDriverMe(),
        core.getDriverPendingRides(),
        core.getDriverEarnings(),
      ).wait;
      state = DashboardState(
        driver: driver,
        pendingRides:
            rides.where((r) => !_declined.contains(r.id.toString())).toList(),
        todayEarningsPkr: _calcTodayEarnings(earnings),
        isLoading: false,
      );
      _syncHeartbeat();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is core.AppError ? e.message : 'Failed to load',
      );
    }
  }

  void declineRide(String rideId) {
    _declined.add(rideId);
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

  Future<AcceptOutcome> acceptRide(String rideId) async {
    try {
      await core.acceptRide(rideId);
    } on core.AppError catch (e) {
      return acceptOutcomeForError(e);
    } on Exception catch (e, st) {
      core.ErrorReporter.report('Accepting a ride failed', e, st);
      return const AcceptOutcome(
        AcceptResult.error,
        message: 'Failed to accept ride',
      );
    }
    final tracking =
        await _ref.read(gpsStreamProvider.notifier).startStreaming(rideId);
    final isSharing = tracking == GpsStartResult.started ||
        tracking == GpsStartResult.alreadyStreaming;
    return AcceptOutcome(
      isSharing ? AcceptResult.success : AcceptResult.successWithoutTracking,
    );
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
