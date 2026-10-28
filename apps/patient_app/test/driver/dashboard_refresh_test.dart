import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

core.DriverResponse _driver({
  bool isVerified = true,
  core.DriverStatus status = core.DriverStatus.offline,
}) =>
    core.DriverResponse(
      id: 'd1',
      phone: '+923001234567',
      status: status,
      fullName: 'Asher Khan',
      rating: 4.8,
      isVerified: isVerified,
      walletBalancePkr: 1250,
    );

core.RideResponse _ride(String id) => core.RideResponse.fromJson({
      'id': id,
      'patient_id': 'p1',
      'ride_type': 'scheduled',
      'status': 'pending',
      'pickup_address': 'F-7 Markaz',
      'pickup_lat': 33.7,
      'pickup_lng': 73.0,
      'requested_at': '2026-10-27T10:00:00Z',
    });

class _Calls {
  int driver = 0;
  int pending = 0;
  int earnings = 0;
  int status = 0;
}

/// What the server says, one call at a time. Offline drivers only, so the
/// notifier never starts its heartbeat.
DashboardApi _api(
  _Calls calls, {
  Future<core.DriverResponse> Function()? driver,
  Future<List<core.RideResponse>> Function()? pending,
  Future<Map<String, dynamic>> Function()? earnings,
  Future<void> Function(core.DriverStatus)? status,
  Duration timeout = const Duration(seconds: 5),
}) =>
    DashboardApi(
      getDriver: () {
        calls.driver++;
        return (driver ?? () async => _driver())();
      },
      getPendingRides: () {
        calls.pending++;
        return (pending ?? () async => <core.RideResponse>[])();
      },
      getEarnings: () {
        calls.earnings++;
        return (earnings ?? () async => <String, dynamic>{'rides': []})();
      },
      getMyRides: ({int pageSize = 10}) async => const core.RideListResponse(
        items: [],
        total: 0,
        page: 1,
        pageSize: 10,
      ),
      updateStatus: (s) {
        calls.status++;
        return (status ?? (_) async {})(s);
      },
      timeout: timeout,
    );

Future<(ProviderContainer, DashboardNotifier)> _load(DashboardApi api) async {
  final provider = StateNotifierProvider<DashboardNotifier, DashboardState>(
    (ref) => DashboardNotifier(ref, api: api),
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final notifier = container.read(provider.notifier);
  // The constructor starts the first load; wait until it settles.
  while (container.read(provider).isLoading) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return (container, notifier);
}

DashboardState _state((ProviderContainer, DashboardNotifier) loaded) =>
    loaded.$2.state;

void main() {
  group('loading the dashboard', () {
    test(
        'an unverified driver still gets their account: the server refuses '
        'them the request list, so it is never asked for', () async {
      final calls = _Calls();
      final loaded = await _load(_api(
        calls,
        driver: () async => _driver(isVerified: false),
        pending: () async =>
            throw const core.AppError('Driver not verified', statusCode: 403),
      ));

      final state = _state(loaded);
      expect(state.driver, isNotNull);
      expect(state.driver!.isVerified, isFalse);
      expect(state.error, isNull);
      expect(state.pendingRides, isEmpty);
      expect(calls.pending, 0, reason: 'the server would answer 403');
    });

    test('a verified driver gets their requests and today\'s earnings',
        () async {
      final today = DateTime.now().toUtc().toIso8601String();
      final loaded = await _load(_api(
        _Calls(),
        pending: () async => [_ride('r1')],
        earnings: () async => {
          'rides': [
            {'completed_at': today, 'fare_pkr': 1500},
            {'completed_at': today, 'fare_pkr': 840},
            {'completed_at': '2020-01-01T00:00:00Z', 'fare_pkr': 9999},
          ],
        },
      ));

      final state = _state(loaded);
      expect(state.driver!.isVerified, isTrue);
      expect(state.pendingRides, hasLength(1));
      expect(state.todayEarningsPkr, 2340);
      expect(state.error, isNull);
    });

    test('earnings failing does not discard the account, and is not shown as 0',
        () async {
      final loaded = await _load(_api(
        _Calls(),
        earnings: () async =>
            throw const core.AppError('Server error', statusCode: 500),
      ));

      final state = _state(loaded);
      expect(state.driver, isNotNull);
      expect(state.todayEarningsPkr, isNull, reason: 'unknown, not zero');
      expect(state.error, 'Server error');
    });

    test('a failed account request is an error, not an endless loading state',
        () async {
      final loaded = await _load(_api(
        _Calls(),
        driver: () async => throw const core.AppError(
          'No internet connection',
          statusCode: null,
        ),
      ));

      final state = _state(loaded);
      expect(state.driver, isNull, reason: 'nothing is made up');
      expect(state.isLoading, isFalse);
      expect(state.error, 'No internet connection');
    });

    test('a request that never answers stops loading and says so', () async {
      final never = Completer<core.DriverResponse>();
      final loaded = await _load(_api(
        _Calls(),
        driver: () => never.future,
        timeout: const Duration(milliseconds: 60),
      ));

      final state = _state(loaded);
      expect(state.isLoading, isFalse);
      expect(state.driver, isNull);
      expect(state.error, contains('too long'));
    });

    test('Try again after a failure loads the account', () async {
      var shouldFail = true;
      final calls = _Calls();
      final loaded = await _load(_api(
        calls,
        driver: () async {
          if (shouldFail) throw const core.AppError('Server error');
          return _driver();
        },
      ));
      expect(_state(loaded).driver, isNull);

      shouldFail = false;
      await loaded.$2.refresh();

      expect(_state(loaded).driver, isNotNull);
      expect(_state(loaded).error, isNull);
    });
  });

  group('going online and offline', () {
    test('a second tap while one request is running sends nothing', () async {
      final calls = _Calls();
      final release = Completer<void>();
      final loaded = await _load(_api(
        calls,
        status: (_) => release.future,
      ));

      final first = loaded.$2.toggleOnline();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(_state(loaded).isUpdatingStatus, isTrue);
      await loaded.$2.toggleOnline();
      expect(calls.status, 1);

      release.complete();
      await first;
      expect(_state(loaded).isUpdatingStatus, isFalse);
    });

    test('a refused change leaves the driver as the server last confirmed',
        () async {
      final loaded = await _load(_api(
        _Calls(),
        status: (_) async =>
            throw const core.AppError('Driver not verified', statusCode: 403),
      ));

      await loaded.$2.toggleOnline();

      final state = _state(loaded);
      expect(state.driver!.status, core.DriverStatus.offline);
      expect(state.isUpdatingStatus, isFalse);
      expect(state.error, 'Driver not verified');
    });
  });
}
