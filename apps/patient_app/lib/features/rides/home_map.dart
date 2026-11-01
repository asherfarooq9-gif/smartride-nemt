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
LatLng centerAboveSheet(
  MapCamera camera,
  LatLng target,
  double zoom, {
  double sheetFraction = kHomeSheetRestSize,
}) {
  final sheetHeight = camera.size.y * sheetFraction;
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
  const HomeMap({
    super.key,
    required this.controller,
    this.tileLayer,
    this.sheetFraction = kHomeSheetRestSize,
    this.isPulsing = false,
  });

  final MapController controller;

  /// How much of the screen the resting sheet covers, so the position is
  /// centred in the part of the map that stays visible.
  final double sheetFraction;

  /// Whether the location dot gently pulses (off for reduced motion).
  final bool isPulsing;

  /// Overridable so tests can avoid the network.
  final TileLayer? tileLayer;

  @override
  ConsumerState<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends ConsumerState<HomeMap> {
  bool _isMapReady = false;
  bool _hasCentered = false;

  /// Where the phone last saw itself. It lets the map open in the right place
  /// while the accurate fix, which can take seconds, is still on its way.
  LatLng? _lastKnown;
  bool _hasMovedToLastKnown = false;

  @override
  void initState() {
    super.initState();
    // After the first frame so the provider is not modified during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(patientLocationProvider.notifier).refresh();
      _loadLastKnown();
    });
  }

  Future<void> _loadLastKnown() async {
    try {
      final position = await ref.read(lastKnownPositionProvider)();
      if (!mounted || position == null) return;
      _lastKnown = LatLng(position.latitude, position.longitude);
      _centerOnLastKnown();
    } on Exception catch (e, st) {
      ErrorReporter.report('Could not read the last known location', e, st);
    }
  }

  /// Moves to the last known spot, unless the accurate fix already centred the
  /// map (or this has already happened).
  void _centerOnLastKnown() {
    final spot = _lastKnown;
    if (spot == null || _hasCentered || _hasMovedToLastKnown || !_isMapReady) {
      return;
    }
    _hasMovedToLastKnown = true;
    widget.controller.move(
      centerAboveSheet(
        widget.controller.camera,
        spot,
        kLocatedMapZoom,
        sheetFraction: widget.sheetFraction,
      ),
      kLocatedMapZoom,
    );
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
        sheetFraction: widget.sheetFraction,
      ),
      kLocatedMapZoom,
    );
  }

  /// The colourful English map, or the plain gray English one if the style
  /// cannot be loaded (offline, or the service is down). The gray map also
  /// shows while the colourful style loads, so the map is never blank.
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
          loading: () => englishTileLayers(dark: isDark),
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
          _centerOnLastKnown();
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
                width: 56,
                height: 56,
                child: Semantics(
                  label: 'Your location',
                  child: _PulsingLocationDot(
                    isPulsing: widget.isPulsing &&
                        !MediaQuery.disableAnimationsOf(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The blue dot, with a soft ring that grows and fades around it.
class _PulsingLocationDot extends StatefulWidget {
  const _PulsingLocationDot({required this.isPulsing});

  final bool isPulsing;

  @override
  State<_PulsingLocationDot> createState() => _PulsingLocationDotState();
}

class _PulsingLocationDotState extends State<_PulsingLocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Created up front, not lazily: a lazy one would first be built in dispose.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.isPulsing) _pulse.repeat();
  }

  @override
  void didUpdateWidget(_PulsingLocationDot old) {
    super.didUpdateWidget(old);
    if (widget.isPulsing && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.isPulsing && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.isPulsing)
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Opacity(
                opacity: 0.35 * (1 - t),
                child: Container(
                  width: 28 + 28 * t,
                  height: 28 + 28 * t,
                  decoration: const BoxDecoration(
                    color: kBlueIos,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        const SizedBox(
          width: 28,
          height: 28,
          child: _LocationDot(key: ValueKey('you-are-here')),
        ),
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
