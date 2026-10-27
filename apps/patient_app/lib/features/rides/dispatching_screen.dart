import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:url_launcher/url_launcher.dart';

/// What, if anything, is stopping us from learning the ride's status.
enum _StatusProblem { none, offline, unavailable }

typedef RideLoader = Future<core.RideDetailResponse> Function(String rideId);

class DispatchingScreen extends StatefulWidget {
  const DispatchingScreen({
    super.key,
    required this.rideId,
    this.loadRide = core.getRideDetail,
    this.pollInterval = const Duration(seconds: 4),
  });

  final String rideId;

  /// Injectable so the poll can be driven without a server.
  final RideLoader loadRide;
  final Duration pollInterval;

  @override
  State<DispatchingScreen> createState() => _DispatchingScreenState();
}

class _DispatchingScreenState extends State<DispatchingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _pollTimer;

  // After this many consecutive failed polls (~24s) the patient is told the
  // connection is in trouble instead of staring at an endless spinner.
  static const _maxConsecutiveFailures = 6;
  int _consecutiveFailures = 0;
  _StatusProblem _problem = _StatusProblem.none;
  bool _isDone = false; // navigated away or stopped: no further polls or pushes

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scheduleNextPoll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: hold the pulse at rest instead of looping it.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  /// One poll at a time: the next is only scheduled after this one finishes,
  /// so a slow response can never overlap another and navigate twice.
  void _scheduleNextPoll() {
    if (_isDone) return;
    _pollTimer = Timer(widget.pollInterval, _poll);
  }

  Future<void> _poll() async {
    if (!mounted || _isDone) return;
    try {
      final ride = await widget.loadRide(widget.rideId);
      if (!mounted || _isDone) return;
      _onPollSucceeded();
      if (_leaveIfRideMoved(ride)) return;
    } on core.AppError catch (e, st) {
      if (!mounted || _isDone) return;
      if (e.isPermanent) {
        _stopWithProblem(e, st);
        return;
      }
      _onTransientFailure(e, st);
    } on Exception catch (e, st) {
      if (!mounted || _isDone) return;
      _onTransientFailure(e, st);
    }
    _scheduleNextPoll();
  }

  void _onPollSucceeded() {
    if (_consecutiveFailures == 0 && _problem == _StatusProblem.none) return;
    setState(() {
      _consecutiveFailures = 0;
      _problem = _StatusProblem.none;
    });
  }

  /// Returns true when the screen navigated away.
  bool _leaveIfRideMoved(core.RideDetailResponse ride) {
    if (ride.status == core.RideStatus.pending) return false;
    _isDone = true;
    if (ride.isTrackable) {
      context.go('/tracking/${widget.rideId}');
    } else if (ride.status == core.RideStatus.cancelled) {
      // Nobody could take the ride (the server gives up after a while):
      // say so and offer 1122 instead of dropping back to the home screen.
      context.go('/');
      context.push('/no-drivers');
    } else {
      // Completed or already at the hospital: the detail page tells the story.
      context.go('/');
      context.push('/ride/${widget.rideId}');
    }
    return true;
  }

  void _onTransientFailure(Object error, StackTrace stack) {
    _consecutiveFailures++;
    final isFirstLoss = _consecutiveFailures == _maxConsecutiveFailures;
    if (isFirstLoss) {
      core.ErrorReporter.report('Ride status polling keeps failing', error, stack);
    }
    if (isFirstLoss && _problem == _StatusProblem.none) {
      setState(() => _problem = _StatusProblem.offline);
    }
  }

  /// A 403/404 will not fix itself; stop polling and say so.
  void _stopWithProblem(core.AppError error, StackTrace stack) {
    core.ErrorReporter.report('Ride status is not available', error, stack);
    _isDone = true;
    setState(() => _problem = _StatusProblem.unavailable);
  }

  @override
  void dispose() {
    _isDone = true;
    _pulse.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:1122');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: core.kAuthDarkBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(core.kSpaceXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),
                    Center(child: _PulsingTaxi(animation: _pulse)),
                    const SizedBox(height: core.kSpaceXXL),
                    const _Messages(),
                    const Spacer(flex: 3),
                    if (_problem != _StatusProblem.none)
                      _ProblemPanel(
                        problem: _problem,
                        onBackHome: () => context.go('/'),
                      ),
                    _EmergencyCallButton(onPressed: _callEmergency),
                    const SizedBox(height: core.kSpaceLG),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingTaxi extends StatelessWidget {
  const _PulsingTaxi({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, child) => Container(
          width: 120 + (animation.value * 20),
          height: 120 + (animation.value * 20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: core.kAuthAccent
                .withValues(alpha: 0.1 + animation.value * 0.15),
          ),
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: core.kAuthAccent,
          ),
          child: const Icon(Icons.local_taxi, size: 48, color: Colors.white),
        ),
      ),
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: const Text(
            'Finding your driver...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: core.kSpaceMD),
        const Text(
          'Locating the nearest driver and the right hospital for your needs.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: core.kFontSmall,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        const SizedBox(height: core.kSpaceSM),
        const Text(
          'Please stay calm. Help is on the way.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: core.kFontSmall, color: Colors.white70),
        ),
      ],
    );
  }
}

class _ProblemPanel extends StatelessWidget {
  const _ProblemPanel({required this.problem, required this.onBackHome});

  final _StatusProblem problem;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    final message = problem == _StatusProblem.offline
        ? "Connection lost — we can't check your ride status. "
            'Check your internet, or call 1122 directly below.'
        : "We can't show this ride's status right now. "
            'Please call 1122 directly below.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(core.kSpaceMD),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.redAccent, size: 20),
                const SizedBox(width: core.kSpaceSM),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: core.kFontSmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: core.kSpaceSM),
        TextButton(
          onPressed: onBackHome,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(core.kMinTapTarget),
          ),
          child: const Text(
            'Back to home',
            style: TextStyle(color: Colors.white70, fontSize: core.kFontSmall),
          ),
        ),
        const SizedBox(height: core.kSpaceSM),
      ],
    );
  }
}

class _EmergencyCallButton extends StatelessWidget {
  const _EmergencyCallButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(core.kMinTapTarget),
      ),
      icon: const Icon(Icons.phone, color: core.kDarkAccent, size: 20),
      label: const Text(
        'Call 1122 directly',
        style: TextStyle(
          color: core.kDarkAccent,
          fontWeight: FontWeight.w600,
          fontSize: core.kFontSmall,
        ),
      ),
    );
  }
}
