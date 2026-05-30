import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

void main() {
  group('TokenResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'access_token': 'abc123',
        'token_type': 'bearer',
        'role': 'patient',
        'user_id': '42',
      };
      final t = TokenResponse.fromJson(json);
      expect(t.accessToken, 'abc123');
      expect(t.role, 'patient');
      expect(t.userId, '42');
    });
  });

  group('RideStatus', () {
    test('round-trips all values', () {
      for (final s in RideStatus.values) {
        expect(RideStatusX.fromString(s.value), s);
      }
    });

    test('isActive and isTrackable', () {
      expect(RideStatus.pending.value, 'pending');
      final r = RideResponse.fromJson({
        'id': '1',
        'status': 'driver_en_route',
        'ride_type': 'emergency',
        'pickup_address': '123 Main St',
      });
      expect(r.isActive, true);
      expect(r.isTrackable, true);
    });
  });

  group('PatientResponse', () {
    test('fromJson handles nulls', () {
      final p = PatientResponse.fromJson({'id': 1, 'phone': '+1234567890'});
      expect(p.fullName, isNull);
      expect(p.totalRides, 0);
    });
  });

  group('DriverResponse', () {
    test('fromJson parses status', () {
      final d = DriverResponse.fromJson({
        'id': '7',
        'phone': '+123',
        'status': 'available',
      });
      expect(d.status, DriverStatus.available);
      expect(d.isOnline, true);
    });
  });

  group('EmergencyRideRequest', () {
    test('toJson round-trip', () {
      const req = EmergencyRideRequest(
        pickupAddress: '10 Downing St',
        symptomText: 'chest pain',
        pickupLat: 51.5,
        pickupLng: -0.12,
      );
      final json = req.toJson();
      expect(json['pickup_address'], '10 Downing St');
      expect(json['pickup_lat'], 51.5);
    });
  });
}
