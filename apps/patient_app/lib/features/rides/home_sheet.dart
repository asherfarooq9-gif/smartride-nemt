import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/features/rides/emergency_button.dart';
import 'package:patient_app/features/rides/emergency_confirm_sheet.dart';
import 'package:patient_app/features/rides/home_sheet_parts.dart';
import 'package:patient_app/features/rides/rides_notifier.dart';
import 'package:patient_app/shared/glass_surface.dart';

const _kPeekSize = 0.30;

/// Where the sheet starts: the layout in the design, with the round SOS.
const kHomeSheetRestSize = 0.55;
const _kRestSize = kHomeSheetRestSize;
const _kFullSize = 0.92;

/// How opaque the frosted sheet is: the map shows through, text stays legible.
const _kSheetOpacity = 0.74;

/// How strongly the map behind the sheet is blurred.
const _kSheetBlurSigma = 24.0;

/// Diameter of the round SOS button on the home sheet.
const _kSosDiameter = 118.0;

/// Room kept under the content for the floating tab bar.
const _kNavClearance = 76.0;

/// Below this fraction of the screen the sheet is "collapsed" and swaps the big
/// SOS button for a compact one so the essentials still fit.
const _kCollapsedBelow = 0.45;

/// The draggable bottom sheet on the home screen. Three positions:
/// - collapsed: greeting, a compact SOS and Book a Ride;
/// - half open: the layout in the design, with the round SOS;
/// - expanded: the same, plus the patient's recent rides.
///
/// The map above stays interactive. All colours come from the theme's colour
/// scheme, so the sheet follows light and dark mode.
class HomeSheet extends ConsumerStatefulWidget {
  const HomeSheet({super.key, this.onExtentChanged});

  /// Called with the sheet's height as a fraction of the screen while it moves,
  /// so controls over the map can follow its top edge.
  final ValueChanged<double>? onExtentChanged;

  @override
  ConsumerState<HomeSheet> createState() => _HomeSheetState();
}

class _HomeSheetState extends ConsumerState<HomeSheet> {
  final _extent = ValueNotifier<double>(_kRestSize);

  @override
  void dispose() {
    _extent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final activeRide = ref.watch(activeRideProvider);

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        _extent.value = n.extent;
        widget.onExtentChanged?.call(n.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: _kRestSize,
        minChildSize: _kPeekSize,
        maxChildSize: _kFullSize,
        snap: true,
        snapSizes: const [_kPeekSize, _kRestSize, _kFullSize],
        // Flutter rejects a zero duration, so reduced motion gets a 1 ms snap.
        snapAnimationDuration: Duration(milliseconds: reduceMotion ? 1 : 320),
        builder: (context, controller) {
          return GlassSurface(
            key: const ValueKey('sheet-top'),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(kRadiusSheet),
            ),
            // The sheet carries a lot of text, so it is milkier than the
            // small controls.
            opacity: _kSheetOpacity,
            sigma: _kSheetBlurSigma,
            // A bright hairline along the top edge, like light on glass.
            borderColor: Theme.of(context).brightness == Brightness.dark
                ? null
                : Colors.white.withValues(alpha: 0.85),
            borderWidth: 1,
            shadows: kSheetShadow,
            child: ListView(
              controller: controller,
              // Room for the tab bar and safe area the sheet runs under.
              padding: EdgeInsets.fromLTRB(
                kSpaceLG + 2,
                0,
                kSpaceLG + 2,
                _kNavClearance + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                const SheetGrabber(),
                const SheetGreeting(),
                const SizedBox(height: kSpaceSM),
                if (activeRide != null) ...[
                  ActiveRideBanner(
                    ride: activeRide,
                    onTap: () => context.push('/ride/${activeRide.id}'),
                  ),
                  const SizedBox(height: kSpaceMD),
                ],
                ValueListenableBuilder<double>(
                  valueListenable: _extent,
                  builder: (context, extent, _) {
                    final isCollapsed = extent < _kCollapsedBelow;
                    return AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: isCollapsed
                          ? const CompactEmergency(
                              key: ValueKey('compact-emergency'),
                            )
                          : const Center(
                              key: ValueKey('round-emergency'),
                              child: EmergencyButton(size: _kSosDiameter),
                            ),
                    );
                  },
                ),
                const SizedBox(height: kSpaceSM),
                BookRideCard(onTap: () => context.push('/book-ride')),
                const SizedBox(height: kSpaceSM + 2),
                const QuickCardsRow(),
                const SizedBox(height: kSpaceXL),
                const RecentRidesSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The compact emergency pill used when the sheet is collapsed.
class CompactEmergency extends StatelessWidget {
  const CompactEmergency({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Request emergency ride',
      excludeSemantics: true,
      child: Material(
        color: kEmergencyRed,
        borderRadius: BorderRadius.circular(kRadiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusPill),
          onTap: () => showEmergencyConfirm(context),
          child: const SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_rounded, color: Colors.white),
                SizedBox(width: kSpaceSM),
                Text(
                  'EMERGENCY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
