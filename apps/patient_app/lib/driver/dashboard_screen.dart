import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:patient_app/driver/driver_home_sheet.dart';
import 'package:patient_app/driver/driver_nav_bar.dart';
import 'package:patient_app/features/rides/home_map.dart';
import 'package:patient_app/features/rides/home_top_bar.dart';
import 'package:patient_app/features/rides/map_controls.dart';
import 'package:patient_app/shared/role_switcher.dart';

/// How often the dashboard asks the server for fresh requests and status.
const _kRefreshEvery = Duration(seconds: 15);

/// The driver home screen: the same full-screen map, glass controls and frosted
/// sheet as the patient's, carrying the driver's dashboard.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, this.tileLayer});

  /// Overridable so tests can avoid the network.
  final TileLayer? tileLayer;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _map = MapController();
  final _sheetExtent = ValueNotifier<double>(kDriverSheetRestSize);
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      _kRefreshEvery,
      (_) => ref.read(dashboardProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _map.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The driver home wears the patient's blue glass look, as in the design;
    // the other driver screens keep the portal's own colours.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: AppTheme.patient(dark: isDark),
      child: Scaffold(
        // The map continues behind the tab bar; the sheet does not (see below).
        extendBody: true,
        drawer: const PortalDrawer(),
        body: Builder(builder: _body),
        bottomNavigationBar: const DriverNavBar(),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Everything the tab bar takes: the bar and the system inset under it.
    final navArea =
        kDriverNavBarHeight + MediaQuery.viewPaddingOf(context).bottom;
    // The sheet ends exactly where the bar begins, so no control can ever sit
    // behind it: content scrolls and is clipped at that edge instead.
    final sheetBottom = navArea;
    final sheetRegion = size.height - sheetBottom;
    final isVectorMap = widget.tileLayer == null &&
        ref.watch(isVectorMapShownProvider(
          Theme.of(context).brightness == Brightness.dark,
        ));

    return Stack(
      children: [
        HomeMap(
          controller: _map,
          tileLayer: widget.tileLayer,
          // Where the resting sheet's top edge is, as a share of the screen.
          sheetFraction: kDriverSheetRestSize * sheetRegion / size.height,
          isPulsing: true,
        ),
        HomeTopBar(
          portal: 'driver',
          onMenu: () => Scaffold.of(context).openDrawer(),
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
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: sheetBottom,
          child: DriverHomeSheet(
            onAccept: _accept,
            onExtentChanged: (e) => _sheetExtent.value = e,
            bottomPadding: kSpaceMD,
          ),
        ),
        // Rides just above the sheet, whatever position it is in.
        ValueListenableBuilder<double>(
          valueListenable: _sheetExtent,
          builder: (context, extent, _) => Positioned(
            left: kSpaceLG,
            right: kSpaceLG,
            bottom: sheetBottom + extent * sheetRegion + kSpaceMD,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: MapAttribution(isVectorMap: isVectorMap),
                  ),
                ),
                const SizedBox(width: kSpaceSM),
                RecenterButton(controller: _map),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _accept(String rideId) async {
    final outcome =
        await ref.read(dashboardProvider.notifier).acceptRide(rideId);
    if (!mounted) return;
    final result = outcome.result;
    if (result == AcceptResult.success) {
      context.push('/driver/ride/$rideId');
    } else if (result == AcceptResult.successWithoutTracking) {
      context.push('/driver/ride/$rideId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride accepted, but location sharing is off. '
              'Allow location access so the patient can see you.'),
          duration: Duration(seconds: 8),
        ),
      );
    } else {
      // alreadyTaken, notNearby and error all say why, in the server's words,
      // in a snackbar that outlives the 15 s refresh.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(outcome.message ?? 'Could not accept the ride'),
          duration: const Duration(seconds: 6),
        ),
      );
      ref.read(dashboardProvider.notifier).refresh();
    }
  }
}
