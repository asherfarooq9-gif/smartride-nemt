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

Position _at(double lat, double lng, {double accuracy = 25}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 10, 27),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _Gateway implements LocationGateway {
  _Gateway({this.permissionState = LocationPermission.whileInUse, this.fix});
  LocationPermission permissionState;
  Position? fix;
  int requests = 0;

  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermission> permission() async => permissionState;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permissionState;
  }

  @override
  Future<Position?> position() async => fix;
  @override
  Future<void> openSettings() async {}
}

Widget _app(_Gateway gateway, MapController controller) => ProviderScope(
      overrides: [locationGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        home: Scaffold(
          body: HomeMap(controller: controller, tileLayer: _offlineTiles()),
        ),
      ),
    );

void main() {
  testWidgets('shows the real position as a blue dot with an accuracy ring',
      (tester) async {
    final controller = MapController();
    final gateway = _Gateway(fix: _at(31.5204, 74.3587, accuracy: 30));
    await tester.pumpWidget(_app(gateway, controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('you-are-here')), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(controller.camera.center.latitude, closeTo(31.5204, 0.001));
    expect(controller.camera.center.longitude, closeTo(74.3587, 0.001));
    expect(controller.camera.zoom, greaterThan(13));
  });

  testWidgets('without permission there is no dot and no invented city',
      (tester) async {
    final controller = MapController();
    final gateway = _Gateway(permissionState: LocationPermission.denied);
    await tester.pumpWidget(_app(gateway, controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('you-are-here')), findsNothing);
    expect(controller.camera.zoom, lessThan(7)); // a country overview
    const islamabad = LatLng(33.6844, 73.0479);
    expect(controller.camera.center, isNot(islamabad));
  });

  testWidgets('opening the map never asks for permission', (tester) async {
    final gateway = _Gateway(permissionState: LocationPermission.denied);
    await tester.pumpWidget(_app(gateway, MapController()));
    await tester.pumpAndSettle();

    expect(gateway.requests, 0);
  });

  testWidgets('the map can be dragged and pinched but not rotated',
      (tester) async {
    await tester.pumpWidget(_app(_Gateway(), MapController()));
    await tester.pump();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final flags = map.options.interactionOptions.flags;
    expect(InteractiveFlag.hasDrag(flags), isTrue);
    expect(InteractiveFlag.hasPinchZoom(flags), isTrue);
    expect(InteractiveFlag.hasFlingAnimation(flags), isTrue);
    expect(InteractiveFlag.hasRotate(flags), isFalse);
  });

  testWidgets('the dot is labelled for screen readers', (tester) async {
    await tester.pumpWidget(
      _app(_Gateway(fix: _at(31.5, 74.3)), MapController()),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Your location'), findsOneWidget);
  });
}
