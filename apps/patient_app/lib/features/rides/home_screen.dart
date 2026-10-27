import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:patient_app/features/rides/home_top_bar.dart';
import 'package:patient_app/features/rides/home_sheet.dart';
import 'package:patient_app/shared/pale_map_tiles.dart';
import 'package:patient_app/shared/patient_nav_bar.dart';
import 'package:patient_app/shared/role_switcher.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // The map and sheet continue behind the frosted tab bar.
      extendBody: true,
      drawer: const PortalDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(33.6844, 73.0479),
              initialZoom: 13,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [paleTileLayer()],
          ),
          Builder(
            builder: (ctx) => HomeTopBar(
              onMenu: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const HomeSheet(),
        ],
      ),
      bottomNavigationBar: const PatientNavBar(currentIndex: 0, glass: true),
    );
  }
}
