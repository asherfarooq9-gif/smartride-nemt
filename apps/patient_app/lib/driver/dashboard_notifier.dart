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
    if (reportErrors) {
      core.ErrorReporter.report('Driver heartbeat failed', e, st);
    }
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

/// The ride this driver is in the middle of, from their ride history (newest
/// first). The only way back into a ride after the app was closed or crashed.
core.RideResponse? findActiveDriverRide(List<core.RideResponse> rides) {
  const live = {
    core.RideStatus.driverAssigned,
    core.RideStatus.driverEnRoute,
    core.RideStatus.patientPickedUp,
    core.RideStatus.arrivedAtHospital,
  };
  for (final ride in rides) {
    if (live.contains(ride.status)) return ride;
  }
  return null;
}

/// The server calls the dashboard makes. A seam so tests can say what the server
/// answers; the app uses the real endpoints.
class DashboardApi {
  const DashboardApi({
    this.getDriver = core.getDriverMe,
    this.getPendingRides = core.getDriverPendingRides,
    this.getEarnings = core.getDriverEarnings,
    this.getMyRides = core.getMyRides,
    this.updateStatus = core.updateDriverStatus,
    this.timeout = const Duration(seconds: 20),
  });

  final Future<core.DriverResponse> Function() getDriver;
  final Future<List<core.RideResponse>> Function() getPendingRides;
  final Future<Map<String, dynamic>> Function() getEarnings;
  final Future<core.RideListResponse> Function({int pageSize}) getMyRides;
  final Future<void> Function(core.DriverStatus) updateStatus;

  /// How long any one request may take before the screen stops waiting and says
  /// so, instead of loading for ever.
  final Duration timeout;
}

class DashboardState {
  const DashboardState({
    this.driver,
    this.activeRide,
    this.pendingRides = const [],
    this.todayEarningsPkr,
    this.isLoading = false,
    this.isUpdatingStatus = false,
    this.error,
  });

  final core.DriverResponse? driver;

  /// A ride in progress for this driver, so the dashboard can offer to resume it.
  final core.RideResponse? activeRide;
  final List<core.RideResponse> pendingRides;

  /// Null until the server has said; never a made-up zero.
  final double? todayEarningsPkr;
  final bool isLoading;

  /// True while an online/offline request is in flight, so the controls can show
  /// progress and a second tap cannot send a second request.
  final bool isUpdatingStatus;
  final String? error;

  bool get isOnline => driver?.isOnline ?? false;

  DashboardState copyWith({
    core.DriverResponse? driver,
    core.RideResponse? activeRide,
    List<core.RideResponse>? pendingRides,
    double? todayEarningsPkr,
    bool? isLoading,
    bool? isUpdatingStatus,
    String? error,
  }) =>
      DashboardState(
        driver: driver ?? this.driver,
        activeRide: activeRide ?? this.activeRide,
        pendingRides: pendingRides ?? this.pendingRides,
        todayEarningsPkr: todayEarningsPkr ?? this.todayEarningsPkr,
        isLoading: isLoading ?? this.isLoading,
        isUpdatingStatus: isUpdatingStatus ?? this.isUpdatingStatus,
        error: error,
      );
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  ref.watch(sessionTokenProvider);
  return DashboardNotifier(ref);
});

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._ref, {DashboardApi api = const DashboardApi()})
      : _api = api,
        super(const DashboardState()) {
    refresh();
  }

  final Ref _ref;
  final DashboardApi _api;

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

  /// One server call that never throws: its answer, or the words to show.
  Future<({T? value, String? error})> _attempt<T>(
    Future<T> Function() call,
  ) async {
    try {
      return (value: await call().timeout(_api.timeout), error: null);
    } on TimeoutException {
      return (
        value: null,
        error: 'This is taking too long. Check your connection and try again.',
      );
    } on core.AppError catch (e) {
      return (value: null, error: e.message);
    } catch (e, st) {
      // A parsing bug must not hide behind a bare "Failed to load".
      core.ErrorReporter.report('Driver dashboard refresh failed', e, st);
      return (value: null, error: 'Failed to load');
    }
  }

  /// Loads the driver's account first, then the rest, each on its own: one
  /// refused or failed call no longer discards the others. (The server refuses
  /// the request list to a driver who is not verified; that used to fail the
  /// whole load and leave the account blank.)
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    final account = await _attempt(_api.getDriver);
    if (!mounted) return; // signed out while this was in flight
    final driver = account.value;
    if (driver == null) {
      state = state.copyWith(
        isLoading: false,
        error: account.error ?? 'Failed to load',
      );
      return;
    }

    // An unverified driver cannot receive requests, and asking is a 403.
    final (rides, earnings, active) = await (
      driver.isVerified
          ? _attempt(_api.getPendingRides)
          : Future.value((value: <core.RideResponse>[], error: null)),
      _attempt(_api.getEarnings),
      _loadActiveRide(),
    ).wait;
    if (!mounted) return;

    state = DashboardState(
      driver: driver,
      activeRide: active,
      pendingRides: rides.value == null
          ? state.pendingRides
          : rides.value!
              .where((r) => !_declined.contains(r.id.toString()))
              .toList(),
      todayEarningsPkr: earnings.value == null
          ? state.todayEarningsPkr
          : _calcTodayEarnings(earnings.value!),
      isLoading: false,
      // A background refresh must not unlock the controls mid-request.
      isUpdatingStatus: state.isUpdatingStatus,
      error: rides.error ?? earnings.error,
    );
    _syncHeartbeat();
  }

  /// A failure here must not break the dashboard: keep what was shown before.
  Future<core.RideResponse?> _loadActiveRide() async {
    try {
      final mine = await _api.getMyRides(pageSize: 10);
      return findActiveDriverRide(mine.items);
    } on core.AppError {
      return state.activeRide;
    }
  }

  void declineRide(String rideId) {
    _declined.add(rideId);
    state = state.copyWith(
      pendingRides:
          state.pendingRides.where((r) => r.id.toString() != rideId).toList(),
    );
  }

  Future<void> toggleOnline() async {
    if (state.isUpdatingStatus) return;
    final current = state.driver?.status ?? core.DriverStatus.offline;
    final next = current == core.DriverStatus.offline
        ? core.DriverStatus.available
        : core.DriverStatus.offline;
    state = state.copyWith(isUpdatingStatus: true, error: null);
    try {
      await _api.updateStatus(next);
      await refresh();
    } catch (e) {
      if (!mounted) return;
      // The driver is left as the server last confirmed them.
      state = state.copyWith(
        error: e is core.AppError ? e.message : 'Status update failed',
      );
    } finally {
      if (mounted) {
        // copyWith clears the error unless it is passed again.
        state = state.copyWith(isUpdatingStatus: false, error: state.error);
      }
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
