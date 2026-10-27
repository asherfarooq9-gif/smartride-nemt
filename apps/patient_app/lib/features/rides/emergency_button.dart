import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/features/rides/emergency_confirm_sheet.dart';
import 'package:patient_app/shared/press_scale.dart';

/// The gradient runs from a bright red to a deep one. The label sits in the
/// deeper half, where white text keeps a readable contrast.
const _kRedLight = Color(0xFFFF4B50);
const _kRedDeep = Color(0xFFC91F2C);

/// The round red SOS button on the home screen.
///
/// Tapping it opens a confirmation that shows the real pickup location; the
/// symptom form (which sends the request) comes after that.
///
/// The glow is drawn by a [DecoratedBox] *outside* the [Material] and [Ink]:
/// ink decorations are clipped to their own rectangle, which used to turn the
/// glow into a visible square behind the circle.
class EmergencyButton extends StatefulWidget {
  const EmergencyButton({super.key, this.size = kEmergencyButtonSize});

  /// Diameter of the red circle (before the system font scaling is applied).
  final double size;

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    HapticFeedback.heavyImpact();
    showEmergencyConfirm(context);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    // Grow with the system font size so the label always fits the circle.
    final diameter = MediaQuery.textScalerOf(context)
        .scale(widget.size)
        .clamp(widget.size, widget.size * 1.5);
    final outer = diameter * 1.28;

    return Semantics(
      label: 'Request emergency ride',
      hint: 'Double tap to get immediate help',
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: outer,
        height: outer,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!disableAnimations) ...[
              _PulseRing(
                key: const ValueKey('emergency-pulse-1'),
                animation: _controller,
                size: diameter,
                delay: 0,
              ),
              _PulseRing(
                key: const ValueKey('emergency-pulse-2'),
                animation: _controller,
                size: diameter,
                delay: 0.5,
              ),
            ],
            PressScale(
              pressedScale: 0.95,
              child: DecoratedBox(
                key: const ValueKey('emergency-glow'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: kEmergencyButtonShadow,
                ),
                child: Material(
                  type: MaterialType.circle,
                  color: Colors.transparent,
                  child: Ink(
                    width: diameter,
                    height: diameter,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      // Bright red lit from the top left into a deeper red.
                      gradient: RadialGradient(
                        center: Alignment(-0.35, -0.5),
                        radius: 1.15,
                        colors: [_kRedLight, _kRedDeep],
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _open,
                      child: const _EmergencyLabel(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft ring that grows and fades out from behind the button. Two of them,
/// half a cycle apart, give the calm double pulse in the design.
class _PulseRing extends StatelessWidget {
  const _PulseRing({
    super.key,
    required this.animation,
    required this.size,
    required this.delay,
  });

  final Animation<double> animation;
  final double size;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOut.transform((animation.value + delay) % 1);
        // A soft filled halo, no outline: it reads as a glow, not a ring.
        return Transform.scale(
          scale: 1.0 + 0.24 * t,
          child: Opacity(
            opacity: 0.22 * (1 - t),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kRedLight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmergencyLabel extends StatelessWidget {
  const _EmergencyLabel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(kSpaceMD),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 108,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 34),
                SizedBox(height: 2),
                Text(
                  'EMERGENCY',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Tap for immediate help',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
