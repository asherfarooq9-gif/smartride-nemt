import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/patient_location.dart';
import 'package:patient_app/features/rides/home_map.dart';
import 'package:patient_app/shared/english_map_tiles.dart';
import 'package:patient_app/shared/english_vector_map.dart';
import 'package:patient_app/shared/glass_circle_button.dart';
import 'package:patient_app/shared/glass_surface.dart';
import 'package:patient_app/shared/press_scale.dart';

/// Round glass button that flies the map back to the patient's real position.
///
/// If location permission is missing it asks (this is a deliberate tap, so a
/// prompt is fine); if it was refused for good it opens settings instead.
class RecenterButton extends ConsumerStatefulWidget {
  const RecenterButton({super.key, required this.controller});

  final MapController controller;

  @override
  ConsumerState<RecenterButton> createState() => _RecenterButtonState();
}

class _RecenterButtonState extends ConsumerState<RecenterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight;

  @override
  void initState() {
    super.initState();
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  Future<void> _recenter() async {
    final notifier = ref.read(patientLocationProvider.notifier);
    var location = ref.read(patientLocationProvider);
    if (!location.hasPosition) {
      await notifier.request();
      if (!mounted) return;
      location = ref.read(patientLocationProvider);
    } else {
      await notifier.refresh();
      if (!mounted) return;
      location = ref.read(patientLocationProvider);
    }
    final position = location.position;
    if (position == null) return;
    await _flyTo(LatLng(position.latitude, position.longitude));
  }

  Future<void> _flyTo(LatLng target) async {
    final camera = widget.controller.camera;
    // Land with the position in the visible part of the map, not under the sheet.
    final focus = centerAboveSheet(camera, target, kLocatedMapZoom);
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.controller.move(focus, kLocatedMapZoom);
      return;
    }
    final lat = Tween<double>(
      begin: camera.center.latitude,
      end: focus.latitude,
    );
    final lng = Tween<double>(
      begin: camera.center.longitude,
      end: focus.longitude,
    );
    final zoom = Tween<double>(begin: camera.zoom, end: kLocatedMapZoom);
    final curved =
        CurvedAnimation(parent: _flight, curve: Curves.easeInOutCubic);
    void step() {
      widget.controller.move(
        LatLng(lat.evaluate(curved), lng.evaluate(curved)),
        zoom.evaluate(curved),
      );
    }

    curved.addListener(step);
    _flight.reset();
    await _flight.forward().orCancel.catchError((_) {});
    curved.removeListener(step);
    curved.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCircleButton(
      tooltip: 'Centre on my location',
      icon: Icons.near_me_rounded,
      iconColor: Theme.of(context).colorScheme.primary,
      onPressed: _recenter,
    );
  }
}

/// A small pill over the map that appears only when location is not working,
/// and offers the one action that fixes it.
class LocationHint extends ConsumerWidget {
  const LocationHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(patientLocationProvider).status;
    final label = switch (status) {
      LocationStatus.denied => 'Turn on location',
      LocationStatus.deniedForever => 'Open settings',
      LocationStatus.serviceOff => 'Location is off',
      LocationStatus.noFix => 'Finding you…',
      LocationStatus.loading || LocationStatus.granted => null,
    };
    if (label == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final isActionable = status != LocationStatus.noFix;
    return Semantics(
      button: isActionable,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: isActionable
            ? () => ref.read(patientLocationProvider.notifier).request()
            : null,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(kRadiusPill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpaceLG),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: kSpaceSM),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: kFontSmall,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The map provider's credit. Its terms require it to stay visible, so it sits
/// just above the sheet, opposite the recenter button.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.isVectorMap});

  /// Which basemap is showing, so the right provider is credited.
  final bool isVectorMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpaceSM,
            vertical: kSpaceXS,
          ),
          child: Text(
            isVectorMap ? kVectorMapAttribution : kMapAttribution,
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
