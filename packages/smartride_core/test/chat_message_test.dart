import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

void main() {
  group('RideMessage.fromJson', () {
    test('reads a server message', () {
      final m = RideMessage.fromJson({
        'id': 7,
        'ride_id': 'abc',
        'sender': 'driver',
        'body': 'Two minutes away',
        'created_at': '2026-11-08T10:15:00Z',
      });

      expect(m.id, 7);
      expect(m.rideId, 'abc');
      expect(m.sender, ChatSender.driver);
      expect(m.body, 'Two minutes away');
      expect(m.createdAt.toUtc(), DateTime.utc(2026, 11, 8, 10, 15));
    });

    test('reads a patient message', () {
      final m = RideMessage.fromJson({
        'id': 1,
        'ride_id': 'abc',
        'sender': 'patient',
        'body': 'hi',
        'created_at': '2026-11-08T10:15:00+00:00',
      });

      expect(m.sender, ChatSender.patient);
    });

    test('rejects a sender it does not know', () {
      expect(
        () => RideMessage.fromJson({
          'id': 1,
          'ride_id': 'abc',
          'sender': 'admin',
          'body': 'hi',
          'created_at': '2026-11-08T10:15:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  test('messages with the same id are equal', () {
    final json = {
      'id': 3,
      'ride_id': 'abc',
      'sender': 'patient',
      'body': 'x',
      'created_at': '2026-11-08T10:15:00Z',
    };

    expect(RideMessage.fromJson(json), RideMessage.fromJson(json));
  });
}
