import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:smartride_core/smartride_core.dart' as core;

core.RideResponse _ride(String id, core.RideStatus status) => core.RideResponse(
      id: id,
      status: status,
      rideType: core.RideType.emergency,
      pickupAddress: 'Somewhere',
    );

void main() {
  group('findActiveDriverRide', () {
    test('returns the ride the driver is in the middle of', () {
      for (final status in [
        core.RideStatus.driverAssigned,
        core.RideStatus.driverEnRoute,
        core.RideStatus.patientPickedUp,
        core.RideStatus.arrivedAtHospital,
      ]) {
        final rides = [
          _ride('done', core.RideStatus.completed),
          _ride('live', status),
        ];
        expect(findActiveDriverRide(rides)?.id, 'live', reason: '$status');
      }
    });

    test('ignores finished, cancelled and queued rides', () {
      final rides = [
        _ride('a', core.RideStatus.completed),
        _ride('b', core.RideStatus.cancelled),
        _ride('c', core.RideStatus.pending),
      ];
      expect(findActiveDriverRide(rides), isNull);
    });

    test('an empty history has no active ride', () {
      expect(findActiveDriverRide(const []), isNull);
    });

    test('the most recent live ride wins (the server lists newest first)', () {
      final rides = [
        _ride('newer', core.RideStatus.driverEnRoute),
        _ride('older', core.RideStatus.patientPickedUp),
      ];
      expect(findActiveDriverRide(rides)?.id, 'newer');
    });
  });
}
