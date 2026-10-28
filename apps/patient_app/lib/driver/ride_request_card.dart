import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:smartride_core/smartride_core.dart' show kEmergencyRed;
import 'package:patient_app/driver/money_format.dart';

// Same palette as the home sheet, so the requests read as part of it.
const Color _kAccent = Color(0xFF2563FF);
const Color _kMuted = Color(0xFF637796);
const Color _kLightBlue = Color(0xFFE5F0FF);
const double _kCardRadius = 20;
const double _kRadiusPill = 99;

/// One pending ride request: pickup, destination, distance, ETA and fare, with a
/// 30 s countdown owned by this card's State.
class RideRequestCard extends StatefulWidget {
  const RideRequestCard({
    super.key,
    required this.ride,
    required this.onAccept,
    required this.onDecline,
    this.driverLat,
    this.driverLng,
  });

  final core.RideResponse ride;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final double? driverLat;
  final double? driverLng;

  @override
  State<RideRequestCard> createState() => RideRequestCardState();
}

class RideRequestCardState extends State<RideRequestCard> {
  late int _secondsLeft;
  Timer? _timer;

  // Average urban ambulance/taxi speed used to estimate pickup ETA.
  static const _avgSpeedKmh = 25.0;

  /// Haversine distance (km) from the driver to the pickup point, or null
  /// when either position is unknown — never show made-up numbers.
  double? get _distanceKm {
    final dLat = widget.driverLat, dLng = widget.driverLng;
    final pLat = widget.ride.pickupLat, pLng = widget.ride.pickupLng;
    if (dLat == null || dLng == null || pLat == null || pLng == null) {
      return null;
    }
    const earthRadiusKm = 6371.0;
    final dLatRad = _deg2rad(pLat - dLat);
    final dLngRad = _deg2rad(pLng - dLng);
    final a = math.sin(dLatRad / 2) * math.sin(dLatRad / 2) +
        math.cos(_deg2rad(dLat)) *
            math.cos(_deg2rad(pLat)) *
            math.sin(dLngRad / 2) *
            math.sin(dLngRad / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;

  String get _distanceLabel {
    final d = _distanceKm;
    return d == null ? '— km' : '~${d.toStringAsFixed(1)} km';
  }

  String get _etaLabel {
    final d = _distanceKm;
    if (d == null) return '— min';
    final minutes = (d / _avgSpeedKmh * 60).ceil().clamp(1, 999);
    return '$minutes min';
  }

  @override
  void initState() {
    super.initState();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isEmergency => widget.ride.rideType == core.RideType.emergency;
  bool get _expired => _secondsLeft == 0;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _expired ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(
            color: _isEmergency
                ? kEmergencyRed.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isEmergency)
                  Container(
                    height: 4,
                    decoration: const BoxDecoration(
                      color: kEmergencyRed,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(_kCardRadius),
                        topRight: Radius.circular(_kCardRadius),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 56, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isEmergency)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'EMERGENCY',
                            style: TextStyle(
                              color: kEmergencyRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      Text(
                        widget.ride.pickupAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF152626),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.arrow_forward,
                              size: 14, color: _kMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.ride.hospitalName ??
                                  (widget.ride.hospitalId != null
                                      ? 'Assigned hospital'
                                      : 'Destination'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: _kMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            icon: Icons.route_outlined,
                            label: _distanceLabel,
                          ),
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: _etaLabel,
                          ),
                          _InfoChip(
                            icon: Icons.payments_outlined,
                            label: widget.ride.estimatedFarePkr != null
                                ? formatPkr(widget.ride.estimatedFarePkr!)
                                : 'PKR —',
                          ),
                        ],
                      ),
                      if (_isEmergency && widget.ride.symptomText != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: widget.ride.symptomText!
                              .split(',')
                              .map((s) => _SymptomChip(label: s.trim()))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _expired ? null : widget.onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kAccent,
                            disabledBackgroundColor:
                                _kMuted.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _expired ? null : widget.onDecline,
                          style: TextButton.styleFrom(
                            foregroundColor: kEmergencyRed,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: _isEmergency ? 20 : 12,
              right: 12,
              child: _CountdownRing(secondsLeft: _secondsLeft),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kLightBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _kMuted),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _kMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SymptomChip extends StatelessWidget {
  const _SymptomChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_kRadiusPill),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: _kAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.secondsLeft});

  final int secondsLeft;

  Color get _ringColor {
    if (secondsLeft > 15) return _kAccent;
    if (secondsLeft > 8) return Colors.amber;
    return kEmergencyRed;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _RingPainter(
          progress: secondsLeft / 30.0,
          color: _ringColor,
        ),
        child: Center(
          child: Text(
            '$secondsLeft',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _ringColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
