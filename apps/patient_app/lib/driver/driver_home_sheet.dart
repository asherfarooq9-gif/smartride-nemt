import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/driver/dashboard_notifier.dart';
import 'package:patient_app/driver/driver_home_cards.dart';
import 'package:patient_app/driver/driver_home_controls.dart';
import 'package:patient_app/driver/ride_request_card.dart';
import 'package:patient_app/features/rides/home_glass_card.dart';
import 'package:patient_app/features/rides/home_sheet_parts.dart'
    show SheetGrabber;
import 'package:patient_app/shared/glass_surface.dart';

/// Where the sheet starts: every control is in view, the map above it.
///
/// A fraction of the space above the tab bar, not of the whole screen: the sheet
/// ends where the tab bar begins, so it can never be covered by it.
const kDriverSheetRestSize = 0.76;
const _kPeekSize = 0.36;
const _kFullSize = 0.92;
const _kSheetOpacity = 0.6;
const _kSheetBlurSigma = 24.0;

/// The frosted bottom sheet on the driver home screen: greeting, verification
/// notice, earnings and rating, wallet, availability, shortcuts and the ride
/// requests. Everything shown comes from [dashboardProvider].
class DriverHomeSheet extends ConsumerStatefulWidget {
  const DriverHomeSheet({
    super.key,
    required this.onAccept,
    this.onExtentChanged,
    this.bottomPadding = 0,
  });

  /// Room kept under the last row of the sheet, which ends at the tab bar.
  final double bottomPadding;

  /// Accepts a ride; owned by the screen, which also routes to the ride.
  final Future<void> Function(String rideId) onAccept;

  /// The sheet's height as a fraction of the screen while it moves.
  final ValueChanged<double>? onExtentChanged;

  @override
  ConsumerState<DriverHomeSheet> createState() => _DriverHomeSheetState();
}

class _DriverHomeSheetState extends ConsumerState<DriverHomeSheet> {
  final _sheet = DraggableScrollableController();

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _openFully() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sheet.animateTo(
      _kFullSize,
      duration: Duration(milliseconds: reduceMotion ? 1 : 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Only what the sheet shows: a map or availability change elsewhere does
    // not rebuild it.
    final dash = ref.watch(dashboardProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        widget.onExtentChanged?.call(n.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _sheet,
        initialChildSize: kDriverSheetRestSize,
        minChildSize: _kPeekSize,
        maxChildSize: _kFullSize,
        snap: true,
        snapSizes: const [_kPeekSize, kDriverSheetRestSize, _kFullSize],
        snapAnimationDuration: Duration(milliseconds: reduceMotion ? 1 : 320),
        builder: (context, scroll) => GlassSurface(
          key: const ValueKey('driver-sheet'),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(core.kRadiusSheet),
          ),
          opacity: _kSheetOpacity,
          sigma: _kSheetBlurSigma,
          borderColor: isLight ? Colors.white.withValues(alpha: 0.85) : null,
          borderWidth: 1,
          shadows: core.kSheetShadow,
          child: ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(
              core.kSpaceLG + 2,
              0,
              core.kSpaceLG + 2,
              widget.bottomPadding,
            ),
            children: [
              const SheetGrabber(),
              DriverGreeting(name: dash.driver?.fullName),
              const SizedBox(height: 6),
              if (dash.driver == null && !dash.isLoading) ...[
                // The account itself did not load: say so up here, with a way
                // to retry, rather than showing zeros.
                _MessageCard(
                  key: const ValueKey('account-error'),
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load your account',
                  message: dash.error ?? 'Failed to load',
                  actionLabel: 'Try again',
                  onAction: ref.read(dashboardProvider.notifier).refresh,
                ),
                const SizedBox(height: 6),
              ],
              if (dash.driver != null && !dash.driver!.isVerified) ...[
                const VerificationCard(),
                const SizedBox(height: 6),
              ],
              if (dash.activeRide != null) ...[
                ResumeRideBanner(
                  statusLabel: dash.activeRide!.status.displayLabel,
                  onResume: () =>
                      context.push('/driver/ride/${dash.activeRide!.id}'),
                ),
                const SizedBox(height: 6),
              ],
              DriverStatsRow(
                todayEarningsPkr:
                    dash.driver == null ? null : dash.todayEarningsPkr,
                rating: dash.driver?.rating,
              ),
              const SizedBox(height: 6),
              WalletCard(
                balancePkr: dash.driver?.walletBalancePkr,
                isLowBalance: dash.driver?.isLowBalance ?? false,
              ),
              const SizedBox(height: 6),
              const AvailabilityCard(),
              const SizedBox(height: 6),
              DriverActionsGrid(onShowRequests: _openFully),
              const SizedBox(height: core.kSpaceSM),
              const GoOnlineButton(),
              const SizedBox(height: core.kSpaceMD),
              RequestsSection(onAccept: widget.onAccept),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading, error, empty and the live list of ride requests. Never shows a
/// request the server did not send.
class RequestsSection extends ConsumerWidget {
  const RequestsSection({super.key, required this.onAccept});

  final Future<void> Function(String rideId) onAccept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final palette = HomePalette.of(context);
    final isFirstLoad = dash.isLoading && dash.driver == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // An account that failed to load has its own card at the top.
        if (dash.error != null && dash.driver != null) ...[
          _MessageCard(
            key: const ValueKey('requests-error'),
            icon: Icons.error_outline_rounded,
            title: 'Could not load',
            message: dash.error!,
            actionLabel: 'Try again',
            onAction: notifier.refresh,
          ),
          const SizedBox(height: 6),
        ],
        if (isFirstLoad)
          const _MessageCard(
            key: ValueKey('requests-loading'),
            icon: Icons.hourglass_top_rounded,
            title: 'Loading',
            message: 'Getting your ride requests',
            isLoading: true,
          )
        else if (dash.isOnline) ...[
          Semantics(
            header: true,
            child: Text(
              'Ride requests',
              style: TextStyle(
                fontSize: core.kFontSubhead,
                fontWeight: FontWeight.w700,
                color: palette.heading,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (dash.pendingRides.isEmpty)
            const _MessageCard(
              key: ValueKey('requests-empty'),
              icon: Icons.wifi_tethering_rounded,
              title: 'No ride requests right now',
              message: 'New requests will appear here.',
            )
          else
            for (final ride in dash.pendingRides)
              RideRequestCard(
                // Keyed by ride: each card owns a 30 s countdown in its State.
                key: ValueKey(ride.id),
                ride: ride,
                driverLat: dash.driver?.currentLat,
                driverLng: dash.driver?.currentLng,
                onAccept: () => onAccept(ride.id.toString()),
                onDecline: () => notifier.declineRide(ride.id.toString()),
              ),
        ],
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $message',
      excludeSemantics: actionLabel == null,
      child: HomeGlassCard(
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(core.kSpaceMD),
          child: Row(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Icon(icon, color: palette.muted),
              const SizedBox(width: core.kSpaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: core.kFontBody,
                        fontWeight: FontWeight.w700,
                        color: palette.heading,
                      ),
                    ),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: core.kFontSmall,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, core.kMinTapTarget),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
