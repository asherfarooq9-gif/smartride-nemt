import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/features/rides/home_map.dart';

/// A 1x1 transparent PNG, so tests never touch the network.
final _blankTile = MemoryImage(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
));

class _BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _blankTile;
}

TileLayer _offlineTiles() => TileLayer(
      urlTemplate: 'blank/{z}/{x}/{y}.png',
      tileProvider: _BlankTiles(),
    );

Position _at(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 10, 30),
      accuracy: 25,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// Permission is granted but the GPS fix has not arrived yet.
class _SlowGateway implements LocationGateway {
  final fix = Completer<Position?>();

  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermission> permission() async => LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position?> position() => fix.future;
  @override
  Future<void> openSettings() async {}
}

Widget _app(
  _SlowGateway gateway,
  MapController controller,
  Future<Position?> Function() lastKnown,
) =>
    ProviderScope(
      overrides: [
        locationGatewayProvider.overrideWithValue(gateway),
        lastKnownPositionProvider.overrideWithValue(lastKnown),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: HomeMap(controller: controller, tileLayer: _offlineTiles()),
        ),
      ),
    );

void main() {
  const lastSeen = LatLng(33.6638, 73.0454);

  double offCentreX(MapController controller) {
    final camera = controller.camera;
    return (camera.latLngToScreenPoint(lastSeen).x - camera.size.x / 2).abs();
  }

  testWidgets('opens on the last known position before the GPS fix arrives',
      (tester) async {
    final controller = MapController();
    final gateway = _SlowGateway();
    await tester.pumpWidget(
      _app(gateway, controller, () async => _at(33.6638, 73.0454)),
    );
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, kLocatedMapZoom);
    expect(offCentreX(controller), lessThan(2));
    // The fix has not arrived: the dot is not shown yet.
    expect(find.byKey(const ValueKey('you-are-here')), findsNothing);
  });

  testWidgets('moves to the accurate fix once it arrives', (tester) async {
    final controller = MapController();
    final gateway = _SlowGateway();
    await tester.pumpWidget(
      _app(gateway, controller, () async => _at(33.6638, 73.0454)),
    );
    await tester.pumpAndSettle();

    gateway.fix.complete(_at(33.7000, 73.0600));
    await tester.pumpAndSettle();

    final camera = controller.camera;
    final spot = camera.latLngToScreenPoint(const LatLng(33.7000, 73.0600));
    expect(spot.x, closeTo(camera.size.x / 2, 2));
    expect(find.byKey(const ValueKey('you-are-here')), findsOneWidget);
  });

  testWidgets('stays on the neutral view when no position is known',
      (tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      _app(_SlowGateway(), controller, () async => null),
    );
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, kNeutralMapZoom);
  });

  testWidgets('a failing last-known lookup does not break the map',
      (tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      _app(
        _SlowGateway(),
        controller,
        () async => throw const PermissionDeniedException('no'),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, kNeutralMapZoom);
  });
}
