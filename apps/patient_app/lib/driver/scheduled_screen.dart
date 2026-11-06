import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/core/date_format.dart';
import 'package:patient_app/shared/press_scale.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// Booked rides near the driver that nobody has reserved yet.
final openScheduledProvider =
    FutureProvider.autoDispose<List<core.RideResponse>>(
  (_) => core.getOpenScheduledRides(),
);

/// The booked rides this driver reserved.
final claimedScheduledProvider =
    FutureProvider.autoDispose<List<core.RideResponse>>(
  (_) => core.getClaimedRides(),
);

typedef RideAction = Future<core.RideResponse> Function(String rideId);

/// Indirection so tests can run the actions without a server.
final claimRideProvider = Provider<RideAction>((_) => core.claimRide);
final releaseRideProvider = Provider<RideAction>((_) => core.releaseRide);

enum _Tab { open, mine }

/// Where a driver reserves booked rides ahead of time and sees the ones they
/// hold. A reserved ride becomes theirs when its pickup window opens.
class DriverScheduledScreen extends ConsumerStatefulWidget {
  const DriverScheduledScreen({super.key});

  @override
  ConsumerState<DriverScheduledScreen> createState() =>
      _DriverScheduledScreenState();
}

class _DriverScheduledScreenState extends ConsumerState<DriverScheduledScreen> {
  _Tab _tab = _Tab.open;
  final Set<String> _busyIds = {};

  Future<void> _run(
    String rideId,
    RideAction action, {
    required String doneMessage,
  }) async {
    if (_busyIds.contains(rideId)) return;
    setState(() => _busyIds.add(rideId));
    try {
      await action(rideId);
      HapticFeedback.mediumImpact();
      ref.invalidate(openScheduledProvider);
      ref.invalidate(claimedScheduledProvider);
      _say(doneMessage);
    } on core.AppError catch (e) {
      // The server says why (taken, at the limit, too close to pickup).
      HapticFeedback.heavyImpact();
      _say(e.message);
      ref.invalidate(openScheduledProvider);
      ref.invalidate(claimedScheduledProvider);
    } finally {
      if (mounted) setState(() => _busyIds.remove(rideId));
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _tab == _Tab.open;
    final rides =
        ref.watch(isOpen ? openScheduledProvider : claimedScheduledProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.scheduled)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<_Tab>(
                groupValue: _tab,
                children: {
                  _Tab.open: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.l10n.openRides),
                  ),
                  _Tab.mine: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.l10n.myRides),
                  ),
                },
                onValueChanged: (v) => setState(() => _tab = v ?? _tab),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: rides.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _Message(
                    icon: Icons.wifi_off_rounded,
                    title: context.l10n.couldNotLoadRides,
                    body: context.l10n.checkConnectionPullDown,
                    onRefresh: _refresh,
                  ),
                  data: (list) => list.isEmpty
                      ? _Message(
                          icon: isOpen
                              ? Icons.event_available_outlined
                              : Icons.bookmark_border_rounded,
                          title: isOpen
                              ? context.l10n.noOpenRidesTitle
                              : context.l10n.noReservedTitle,
                          body: isOpen
                              ? context.l10n.noOpenRidesBody
                              : context.l10n.noReservedBody,
                          onRefresh: _refresh,
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _RideCard(
                              ride: list[i],
                              isMine: !isOpen,
                              isBusy: _busyIds.contains(list[i].id),
                              onPressed: () => isOpen
                                  ? _run(
                                      list[i].id,
                                      ref.read(claimRideProvider),
                                      doneMessage: context.l10n.reservedMessage,
                                    )
                                  : _run(
                                      list[i].id,
                                      ref.read(releaseRideProvider),
                                      doneMessage:
                                          context.l10n.givenBackMessage,
                                    ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(openScheduledProvider);
    ref.invalidate(claimedScheduledProvider);
    await ref.read(
      (_tab == _Tab.open ? openScheduledProvider : claimedScheduledProvider)
          .future,
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.ride,
    required this.isMine,
    required this.isBusy,
    required this.onPressed,
  });

  final core.RideResponse ride;
  final bool isMine;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when =
        ride.scheduledAt == null ? null : DateTime.tryParse(ride.scheduledAt!);
    final destination = ride.hospitalName;

    return Semantics(
      container: true,
      label: 'Booked ride ${when == null ? '' : formatWhen(when)}',
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                when == null
                    ? context.l10n.timeToBeConfirmed
                    : formatWhen(when),
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: -0.2),
              ),
              const SizedBox(height: 12),
              _Line(icon: Icons.my_location, text: ride.pickupAddress),
              if (destination != null && destination.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Line(icon: Icons.local_hospital_outlined, text: destination),
              ],
              const SizedBox(height: 16),
              PressScale(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: isMine
                      ? OutlinedButton(
                          onPressed: isBusy ? null : onPressed,
                          child: _label(isBusy, context.l10n.giveBack),
                        )
                      : FilledButton(
                          onPressed: isBusy ? null : onPressed,
                          child: _label(isBusy, context.l10n.reserveThisRide),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(bool isBusy, String text) => isBusy
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text(text);
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(child: Text(text.isEmpty ? 'Pickup location shared' : text)),
      ],
    );
  }
}

/// An empty or error state that can still be pulled down to refresh.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.onRefresh,
  });

  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
