import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/navigation_links.dart';
import 'package:smartride_core/smartride_core.dart' as core;

core.RideDetailResponse _ride(
  core.RideStatus status, {
  Map<String, dynamic>? hospital,
}) =>
    core.RideDetailResponse(
      id: 'r1',
      status: status,
      rideType: core.RideType.emergency,
      pickupAddress: 'F-7 Markaz',
      pickupLat: 33.72,
      pickupLng: 73.04,
      hospital: hospital,
    );

void main() {
  group('navigationOptions', () {
    test('Android opens Google Maps navigation straight to the point', () {
      final options = navigationOptions(
        33.72,
        73.04,
        platform: TargetPlatform.android,
      );

      expect(options, hasLength(1));
      expect(options.single.label, 'Google Maps');
      expect(options.single.uri.toString(),
          'google.navigation:q=33.72,73.04&mode=d');
    });

    test('iOS offers Apple Maps and Google Maps', () {
      final options = navigationOptions(
        33.72,
        73.04,
        platform: TargetPlatform.iOS,
      );

      expect(options.map((o) => o.label), ['Apple Maps', 'Google Maps']);
      expect(options.first.uri.host, 'maps.apple.com');
      expect(options.first.uri.queryParameters['daddr'], '33.72,73.04');
      expect(options.last.uri.host, 'www.google.com');
      expect(options.last.uri.queryParameters['destination'], '33.72,73.04');
    });

    test('anything else falls back to the Google Maps web link', () {
      final options = navigationOptions(
        33.72,
        73.04,
        platform: TargetPlatform.windows,
      );

      expect(options, hasLength(1));
      expect(options.single.uri.scheme, 'https');
    });
  });

  group('navigationTarget', () {
    test('before pickup it points at the patient', () {
      for (final status in [
        core.RideStatus.driverAssigned,
        core.RideStatus.driverEnRoute,
      ]) {
        final target = navigationTarget(_ride(status));
        expect(target?.label, 'Navigate to patient', reason: '$status');
        expect(target?.lat, 33.72);
        expect(target?.lng, 73.04);
      }
    });

    test('after pickup it points at the hospital', () {
      final target = navigationTarget(
        _ride(
          core.RideStatus.patientPickedUp,
          hospital: {'name': 'PIMS', 'lat': 33.70, 'lng': 73.05},
        ),
      );

      expect(target?.label, 'Navigate to hospital');
      expect(target?.lat, 33.70);
      expect(target?.lng, 73.05);
    });

    test('there is no target when the hospital has no coordinates', () {
      expect(
        navigationTarget(
          _ride(core.RideStatus.patientPickedUp, hospital: {'name': 'PIMS'}),
        ),
        isNull,
      );
      expect(navigationTarget(_ride(core.RideStatus.patientPickedUp)), isNull);
    });

    test('there is no target once the ride is over', () {
      expect(navigationTarget(_ride(core.RideStatus.completed)), isNull);
      expect(navigationTarget(_ride(core.RideStatus.cancelled)), isNull);
    });
  });
}
