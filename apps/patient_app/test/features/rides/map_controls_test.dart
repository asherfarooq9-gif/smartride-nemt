import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/features/rides/home_map.dart';
import 'package:patient_app/features/rides/home_sheet.dart'
    show kHomeSheetRestSize;
import 'package:patient_app/features/rides/map_controls.dart';

final _blankTile = MemoryImage(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
));

class _BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _blankTile;
}

Position _at(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 10, 27),
      accuracy: 20,
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
  LocationPermission afterRequest = LocationPermission.whileInUse;
  Position? fix;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermission> permission() async => permissionState;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    permissionState = afterRequest;
    return permissionState;
  }

  @override
  Future<Position?> position() async => fix;
  @override
  Future<void> openSettings() async => settingsOpened++;
}

Widget _app(_Gateway gateway, MapController controller) => ProviderScope(
      overrides: [locationGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              HomeMap(
                controller: controller,
                tileLayer: TileLayer(
                  urlTemplate: 'blank/{z}/{x}/{y}.png',
                  tileProvider: _BlankTiles(),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 200,
                child: RecenterButton(controller: controller),
              ),
              const Positioned(top: 100, left: 16, child: LocationHint()),
            ],
          ),
        ),
      ),
    );

/// The position sits in the middle of the part of the map the home sheet
/// leaves uncovered, not behind the sheet.
void _expectShownAboveSheet(MapController controller, LatLng position) {
  final camera = controller.camera;
  final spot = camera.latLngToScreenPoint(position);
  final visibleHeight = camera.size.y * (1 - kHomeSheetRestSize);
  expect(spot.x, closeTo(camera.size.x / 2, 2));
  expect(spot.y, closeTo(visibleHeight / 2, 2));
}

void main() {
  testWidgets('recenter flies back to the real position after panning away',
      (tester) async {
    final controller = MapController();
    final gateway = _Gateway(fix: _at(31.5204, 74.3587));
    await tester.pumpWidget(_app(gateway, controller));
    await tester.pumpAndSettle();
    controller.move(const LatLng(24.8607, 67.0011), 12); // pan far away

    await tester.tap(find.byTooltip('Centre on my location'));
    await tester.pumpAndSettle();

    _expectShownAboveSheet(controller, const LatLng(31.5204, 74.3587));
  });

  testWidgets('recenter asks for permission when it is missing, then centres',
      (tester) async {
    final controller = MapController();
    final gateway = _Gateway(
      permissionState: LocationPermission.denied,
      fix: _at(33.0, 73.0),
    );
    await tester.pumpWidget(_app(gateway, controller));
    await tester.pumpAndSettle();
    expect(gateway.requests, 0);

    await tester.tap(find.byTooltip('Centre on my location'));
    await tester.pumpAndSettle();

    expect(gateway.requests, 1);
    _expectShownAboveSheet(controller, const LatLng(33.0, 73.0));
  });

  testWidgets('the hint offers to turn location on only when it is off',
      (tester) async {
    final gateway = _Gateway(
      permissionState: LocationPermission.denied,
      fix: _at(33.0, 73.0),
    );
    await tester.pumpWidget(_app(gateway, MapController()));
    await tester.pumpAndSettle();

    expect(find.text('Turn on location'), findsOneWidget);

    await tester.tap(find.text('Turn on location'));
    await tester.pumpAndSettle();

    expect(gateway.requests, 1);
    expect(find.text('Turn on location'), findsNothing);
  });

  testWidgets('no hint when location already works', (tester) async {
    await tester.pumpWidget(
      _app(_Gateway(fix: _at(33.0, 73.0)), MapController()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turn on location'), findsNothing);
    expect(find.text('Open settings'), findsNothing);
  });

  testWidgets('permanently denied sends the user to settings', (tester) async {
    final gateway = _Gateway(permissionState: LocationPermission.deniedForever);
    await tester.pumpWidget(_app(gateway, MapController()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(gateway.requests, 0);
    expect(gateway.settingsOpened, 1);
  });

  testWidgets('the recenter button is at least 44 logical pixels',
      (tester) async {
    await tester.pumpWidget(_app(_Gateway(), MapController()));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byTooltip('Centre on my location'));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
