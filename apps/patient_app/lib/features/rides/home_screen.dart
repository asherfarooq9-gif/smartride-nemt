import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/features/rides/home_map.dart';
import 'package:patient_app/features/rides/home_sheet.dart';
import 'package:patient_app/features/rides/home_top_bar.dart';
import 'package:patient_app/features/rides/map_controls.dart';
import 'package:patient_app/shared/patient_nav_bar.dart';
import 'package:patient_app/shared/role_switcher.dart';

/// The patient home screen: a full-screen, interactive map; two round glass
/// buttons on top; a draggable sheet with the emergency button, Book a Ride and
/// quick cards; and a floating tab bar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.tileLayer});

  /// Overridable so tests can avoid the network.
  final TileLayer? tileLayer;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _map = MapController();
  final _sheetExtent = ValueNotifier<double>(kHomeSheetRestSize);

  @override
  void dispose() {
    _map.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      // The map and sheet continue behind the floating tab bar.
      extendBody: true,
      drawer: const PortalDrawer(),
      body: Stack(
        children: [
          HomeMap(controller: _map, tileLayer: widget.tileLayer),
          Builder(
            builder: (ctx) => HomeTopBar(
              onMenu: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          // Under the top buttons, only when location is not working.
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: kMinTapTarget + kSpaceXL),
              child: Align(
                alignment: Alignment.topCenter,
                child: LocationHint(),
              ),
            ),
          ),
          HomeSheet(onExtentChanged: (e) => _sheetExtent.value = e),
          // Rides just above the sheet, whatever position it is in.
          ValueListenableBuilder<double>(
            valueListenable: _sheetExtent,
            builder: (context, extent, _) => Positioned(
              right: kSpaceLG,
              bottom: extent * height + kSpaceMD,
              child: RecenterButton(controller: _map),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const PatientNavBar(currentIndex: 0, glass: true),
    );
  }
}
