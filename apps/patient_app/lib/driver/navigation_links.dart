import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:smartride_core/smartride_core.dart' as core;

/// One maps app a driver can hand a destination to.
class NavigationOption {
  const NavigationOption(this.label, this.uri);

  final String label;
  final Uri uri;
}

/// Where the driver should head next, and what to call the button.
class NavigationTarget {
  const NavigationTarget(this.label, this.lat, this.lng);

  final String label;
  final double lat;
  final double lng;
}

/// The maps apps that can navigate to a point on [platform]. Turn-by-turn is
/// left to them: the app only passes the coordinates.
List<NavigationOption> navigationOptions(
  double lat,
  double lng, {
  required TargetPlatform platform,
}) {
  final point = '$lat,$lng';
  final googleWeb = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': point,
    'travelmode': 'driving',
  });
  return switch (platform) {
    TargetPlatform.android => [
        NavigationOption(
          'Google Maps',
          Uri.parse('google.navigation:q=$point&mode=d'),
        ),
      ],
    TargetPlatform.iOS => [
        NavigationOption(
          'Apple Maps',
          Uri.https('maps.apple.com', '/', {'daddr': point, 'dirflg': 'd'}),
        ),
        NavigationOption('Google Maps', googleWeb),
      ],
    _ => [NavigationOption('Google Maps', googleWeb)],
  };
}

/// The patient before pickup, the hospital after. Null when there is nowhere
/// to send the driver: the ride is over, or the hospital has no coordinates.
NavigationTarget? navigationTarget(core.RideDetailResponse ride) {
  switch (ride.status) {
    case core.RideStatus.driverAssigned:
    case core.RideStatus.driverEnRoute:
      final lat = ride.pickupLat;
      final lng = ride.pickupLng;
      if (lat == null || lng == null) return null;
      return NavigationTarget('Navigate to patient', lat, lng);
    case core.RideStatus.patientPickedUp:
    case core.RideStatus.arrivedAtHospital:
      final lat = (ride.hospital?['lat'] as num?)?.toDouble();
      final lng = (ride.hospital?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return NavigationTarget('Navigate to hospital', lat, lng);
    default:
      return null;
  }
}
