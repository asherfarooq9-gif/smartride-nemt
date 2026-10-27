import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/ride_events.dart';
import 'package:smartride_core/smartride_core.dart' as core;

void main() {
  group('isRideEndedMessage', () {
    test('recognises the server telling the driver the ride is over', () {
      expect(isRideEndedMessage({'event': 'ride_ended'}), isTrue);
      expect(isRideEndedMessage({'event': 'ride_ended', 'status': 'cancelled'}),
          isTrue);
    });

    test('ignores acks, pings and malformed frames', () {
      expect(isRideEndedMessage({'ack': true, 'lat': 1.0, 'lng': 2.0}), isFalse);
      expect(isRideEndedMessage({'event': 'ping'}), isFalse);
      expect(isRideEndedMessage({'error': 'invalid or too frequent update'}),
          isFalse);
      expect(isRideEndedMessage({}), isFalse);
      expect(isRideEndedMessage({'event': 5}), isFalse);
    });
  });

  group('rideHasEnded', () {
    test('only completed and cancelled rides are over', () {
      const over = {core.RideStatus.completed, core.RideStatus.cancelled};
      for (final s in core.RideStatus.values) {
        expect(rideHasEnded(s), over.contains(s), reason: '$s');
      }
    });

    test('a ride handed back to the queue is not over for the dispatch loop,'
        ' but it is no longer this driver\'s', () {
      expect(rideHasEnded(core.RideStatus.pending), isFalse);
      expect(rideLeftThisDriver(core.RideStatus.pending), isTrue);
    });

    test('live statuses keep the driver on the ride screen', () {
      for (final s in [
        core.RideStatus.driverAssigned,
        core.RideStatus.driverEnRoute,
        core.RideStatus.patientPickedUp,
        core.RideStatus.arrivedAtHospital,
      ]) {
        expect(rideLeftThisDriver(s), isFalse, reason: '$s');
      }
    });
  });
}
