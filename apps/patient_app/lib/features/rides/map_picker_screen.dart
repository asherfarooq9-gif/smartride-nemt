import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:patient_app/core/location.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Full-screen pin-drop map. Tap anywhere to place the destination marker,
/// then confirm. Pops with the selected LatLng, or null if cancelled.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapController = MapController();
  LatLng? _selected;
  static const _fallbackCenter = LatLng(33.6844, 73.0479); // Islamabad

  @override
  void initState() {
    super.initState();
    _centerOnCurrentLocation();
  }

  Future<void> _centerOnCurrentLocation() async {
    final position = await getCurrentPositionSafe();
    if (position == null || !mounted) return;
    _mapController.move(LatLng(position.latitude, position.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select destination'),
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _fallbackCenter,
              initialZoom: 12,
              onTap: (_, point) => setState(() => _selected = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.smartride.patient',
              ),
              if (_selected != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _selected!,
                    width: 40,
                    height: 40,
                    child: Semantics(
                      label: 'Selected destination',
                      child: const Icon(
                        Icons.location_on,
                        color: core.kPatientPrimary,
                        size: 40,
                      ),
                    ),
                  ),
                ]),
            ],
          ),
          const Positioned(
            top: core.kSpaceLG,
            left: core.kSpaceLG,
            right: core.kSpaceLG,
            child: _Instructions(),
          ),
          Positioned(
            left: core.kSpaceLG,
            right: core.kSpaceLG,
            bottom: core.kSpaceLG,
            child: SizedBox(
              height: core.kMinTapTarget,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => context.pop(_selected),
                child: const Text('Confirm destination'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(core.kRadiusMD),
      elevation: 2,
      child: const Padding(
        padding: EdgeInsets.all(core.kSpaceMD),
        child: Text(
          'Tap the map to drop a pin at your destination',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
