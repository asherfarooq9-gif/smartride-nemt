import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:url_launcher/url_launcher.dart';

class DispatchingScreen extends StatefulWidget {
  const DispatchingScreen({super.key, required this.rideId});
  final String rideId;

  @override
  State<DispatchingScreen> createState() => _DispatchingScreenState();
}

class _DispatchingScreenState extends State<DispatchingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  Timer? _pollTimer;

  // After this many consecutive failed polls (~24s) the patient is told the
  // connection is in trouble instead of staring at an endless spinner.
  static const _maxConsecutiveFailures = 6;
  int _consecutiveFailures = 0;
  bool _connectionLost = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final ride = await core.getRideDetail(widget.rideId);
        if (!mounted) return;
        if (_consecutiveFailures > 0 || _connectionLost) {
          setState(() {
            _consecutiveFailures = 0;
            _connectionLost = false;
          });
        }
        if (ride.status == core.RideStatus.driverAssigned ||
            ride.status == core.RideStatus.driverEnRoute) {
          _pollTimer?.cancel();
          context.go('/tracking/${widget.rideId}');
        } else if (ride.status == core.RideStatus.cancelled) {
          _pollTimer?.cancel();
          if (mounted) context.go('/');
        }
      } on Exception {
        if (!mounted) return;
        _consecutiveFailures++;
        if (_consecutiveFailures >= _maxConsecutiveFailures &&
            !_connectionLost) {
          setState(() => _connectionLost = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: core.kAuthDarkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(core.kSpaceXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Container(
                    width: 120 + (_pulse.value * 20),
                    height: 120 + (_pulse.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: core.kAuthTeal
                          .withValues(alpha: 0.1 + _pulse.value * 0.15),
                    ),
                    child: child,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: core.kAuthTeal,
                    ),
                    child: const Icon(
                      Icons.local_taxi,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: core.kSpaceXXL),
              const Text(
                'Finding your driver...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: core.kSpaceMD),
              const Text(
                'Locating the nearest driver and the right\nhospital for your needs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: core.kFontSM,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: core.kSpaceSM),
              const Text(
                'Please stay calm. Help is on the way.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: core.kFontSM,
                  color: Colors.white38,
                ),
              ),
              const Spacer(flex: 3),
              if (_connectionLost) ...[
                Container(
                  padding: const EdgeInsets.all(core.kSpaceMD),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.redAccent, size: 20),
                      SizedBox(width: core.kSpaceSM),
                      Expanded(
                        child: Text(
                          'Connection lost — we can\'t check your ride status. '
                          'Check your internet, or call 1122 directly below.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: core.kFontSM),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: core.kSpaceSM),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text(
                    'Back to home',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: core.kSpaceSM),
              ],
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('tel:1122');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                icon: const Icon(Icons.phone, color: core.kAuthTeal, size: 18),
                label: const Text(
                  'Call 1122 directly',
                  style: TextStyle(
                    color: core.kAuthTeal,
                    fontWeight: FontWeight.w600,
                    fontSize: core.kFontSM,
                  ),
                ),
              ),
              const SizedBox(height: core.kSpaceLG),
            ],
          ),
        ),
      ),
    );
  }
}
