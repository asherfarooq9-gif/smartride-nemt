import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/features/rides/home_sheet.dart'
    show kHomeSheetRestSize;
import 'package:patient_app/shared/english_map_tiles.dart';
import 'package:patient_app/shared/english_vector_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// The map shown before we know where the patient is: a country overview, not
/// a guess at their city.
const kNeutralMapCenter = LatLng(30.3753, 69.3451);
const kNeutralMapZoom = 5.0;

/// Zoom used once there is a real position.
const kLocatedMapZoom = 14.2;

/// The map centre that puts [target] in the middle of the part of the map the
/// home sheet leaves uncovered, rather than behind the sheet.
///
/// The map fills the whole screen but the sheet covers its lower part, so the
/// screen centre is under the sheet. The screen centre is moved south of the
/// target by half the sheet's height.
LatLng centerAboveSheet(MapCamera camera, LatLng target, double zoom) {
  final sheetHeight = camera.size.y * kHomeSheetRestSize;
  final point = camera.project(target, zoom);
  return camera.unproject(math.Point(point.x, point.y + sheetHeight / 2), zoom);
}

/// The full-screen map behind the home screen.
///
/// It can be panned and pinched. When the patient's real position is known it
/// shows a blue dot with an accuracy ring and flies there once; until then it
/// shows a neutral overview and never invents a location. Opening the screen
/// only reads the location state, it never asks for permission.
class HomeMap extends ConsumerStatefulWidget {
  const HomeMap({super.key, required this.controller, this.tileLayer});

  final MapController controller;

  /// Overridable so tests can avoid the network.
  final TileLayer? tileLayer;

  @override
  ConsumerState<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends ConsumerState<HomeMap> {
  bool _isMapReady = false;
  bool _hasCentered = false;

  @override
  void initState() {
    super.initState();
    // After the first frame so the provider is not modified during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(patientLocationProvider.notifier).refresh();
    });
  }

  void _centerOnce(PatientLocation location) {
    final position = location.position;
    if (position == null || _hasCentered || !_isMapReady) return;
    _hasCentered = true;
    widget.controller.move(
      centerAboveSheet(
        widget.controller.camera,
        LatLng(position.latitude, position.longitude),
        kLocatedMapZoom,
      ),
      kLocatedMapZoom,
    );
  }

  /// The colourful English map, or the plain gray English one if the style
  /// cannot be loaded (offline, or the service is down). While it loads the map
  /// shows only its background colour.
  List<Widget> _basemap(bool isDark) {
    return ref.watch(englishMapStyleProvider(isDark)).when(
          data: (style) => [
            VectorTileLayer(
              tileProviders: style.providers,
              theme: style.theme,
              sprites: style.sprites,
              maximumZoom: 19,
              // OpenMapTiles styles are drawn for 512px tiles; at the default
              // 256px the labels and icons come out twice too big.
              tileOffset: TileOffset.mapbox,
            ),
          ],
          loading: () => const [],
          error: (_, __) => englishTileLayers(dark: isDark),
        );
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(patientLocationProvider);
    ref.listen<PatientLocation>(patientLocationProvider, (_, next) {
      _centerOnce(next);
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final position = location.position;
    final here =
        position == null ? null : LatLng(position.latitude, position.longitude);

    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: kNeutralMapCenter,
        initialZoom: kNeutralMapZoom,
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: isDark ? kDarkBg : kCanvas,
        interactionOptions: const InteractionOptions(
          // Pan, pinch and fling, but no rotation: a tilted map confuses
          // people who are stressed and in a hurry.
          flags: InteractiveFlag.drag |
              InteractiveFlag.flingAnimation |
              InteractiveFlag.pinchMove |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
        onMapReady: () {
          _isMapReady = true;
          _centerOnce(ref.read(patientLocationProvider));
        },
      ),
      children: [
        if (widget.tileLayer != null)
          widget.tileLayer!
        else
          ..._basemap(isDark),
        if (here != null && position != null) ...[
          CircleLayer(
            circles: [
              CircleMarker(
                point: here,
                radius: position.accuracy.clamp(10, 500).toDouble(),
                useRadiusInMeter: true,
                color: kBlueIos.withValues(alpha: 0.14),
                borderColor: kBlueIos.withValues(alpha: 0.35),
                borderStrokeWidth: 1,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: here,
                width: 28,
                height: 28,
                child: Semantics(
                  label: 'Your location',
                  child: const _LocationDot(key: ValueKey('you-are-here')),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LocationDot extends StatelessWidget {
  const _LocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kBlueIos,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: kShadowInk.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// True while the colourful vector basemap is what the map actually shows.
final isVectorMapShownProvider = Provider.family<bool, bool>((ref, isDark) {
  return ref.watch(englishMapStyleProvider(isDark)).hasValue;
});
