import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

// ---------------------------------------------------------------------------
// DashboardNotifier hits the network directly in refresh()/acceptRide()/
// toggleOnline() (no injectable API seam, same constraint as the rest of the
// app). This fake skips the constructor's automatic refresh() call so tests
// don't depend on network, and lets each test seed state directly to
// exercise the pure client-side logic (declineRide, DashboardState).
// ---------------------------------------------------------------------------

class _FakeDashboardNotifier extends DashboardNotifier {
  _FakeDashboardNotifier(super.ref);

  @override
  Future<void> refresh() async {
    // No-op: skip the real network calls the base class constructor
    // triggers. Tests seed state via seed().
  }

  void seed(DashboardState newState) => state = newState;
}

core.DriverResponse _driver({core.DriverStatus status = core.DriverStatus.available}) =>
    core.DriverResponse(id: 'd1', phone: '+923001234567', status: status);

core.RideResponse _ride(String id) => core.RideResponse(
      id: id,
      status: core.RideStatus.pending,
      rideType: core.RideType.emergency,
      pickupAddress: 'Test Address $id',
    );

void main() {
  group('DashboardNotifier.declineRide', () {
    test('removes only the declined ride from the pending list', () {
      final container = ProviderContainer(
        overrides: [
          dashboardProvider.overrideWith((ref) => _FakeDashboardNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(dashboardProvider.notifier) as _FakeDashboardNotifier;
      notifier.seed(DashboardState(
        driver: _driver(),
        pendingRides: [_ride('1'), _ride('2'), _ride('3')],
      ));

      notifier.declineRide('2');

      final remaining =
          container.read(dashboardProvider).pendingRides.map((r) => r.id);
      expect(remaining, ['1', '3']);
    });

    test('is a no-op when the ride id is not in the pending list', () {
      final container = ProviderContainer(
        overrides: [
          dashboardProvider.overrideWith((ref) => _FakeDashboardNotifier(ref)),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(dashboardProvider.notifier) as _FakeDashboardNotifier;
      notifier.seed(DashboardState(driver: _driver(), pendingRides: [_ride('1')]));

      notifier.declineRide('does-not-exist');

      expect(container.read(dashboardProvider).pendingRides.length, 1);
    });
  });

  group('DashboardState', () {
    test('isOnline is false with no driver loaded yet', () {
      const state = DashboardState();
      expect(state.isOnline, isFalse);
    });

    test('isOnline reflects the driver status', () {
      final online = DashboardState(driver: _driver(status: core.DriverStatus.available));
      final offline = DashboardState(driver: _driver(status: core.DriverStatus.offline));
      expect(online.isOnline, isTrue);
      expect(offline.isOnline, isFalse);
    });

    test('copyWith replaces only the given fields', () {
      const original = DashboardState(todayEarningsPkr: 100, isLoading: true);
      final updated = original.copyWith(isLoading: false);
      expect(updated.todayEarningsPkr, 100);
      expect(updated.isLoading, isFalse);
    });

    test('copyWith always resets error to the new value, including null', () {
      const original = DashboardState(error: 'stale error');
      final cleared = original.copyWith();
      expect(cleared.error, isNull);
    });
  });
}
