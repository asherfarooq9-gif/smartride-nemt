import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/features/rides/home_map.dart';
import 'package:patient_app/shared/english_vector_map.dart';

void main() {
  testWidgets('shows the gray raster map, not a blank one, while the vector '
      'style is still loading', (tester) async {
    final controller = MapController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // A style that never arrives, like a slow connection.
          englishMapStyleProvider.overrideWith(
            (ref, isDark) => Completer<EnglishMapStyle>().future,
          ),
          locationGatewayProvider.overrideWithValue(_NoLocation()),
        ],
        child: MaterialApp(
          home: Scaffold(body: HomeMap(controller: controller)),
        ),
      ),
    );
    await tester.pump();

    // Esri's base map and its label layer.
    expect(find.byType(TileLayer), findsNWidgets(2));
  });
}

class _NoLocation implements LocationGateway {
  @override
  Future<bool> serviceEnabled() async => false;
  @override
  Future<LocationPermission> permission() async => LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
  @override
  Future<Position?> position() async => null;
  @override
  Future<void> openSettings() async {}
}
