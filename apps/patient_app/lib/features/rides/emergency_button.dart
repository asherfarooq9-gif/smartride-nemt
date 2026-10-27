import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/features/rides/emergency_confirm_sheet.dart';
import 'package:patient_app/shared/press_scale.dart';

/// The round red SOS button on the home screen.
///
/// Tapping it opens a confirmation that shows the real pickup location; the
/// symptom form (which sends the request) comes after that.
///
/// The glow is drawn by a [DecoratedBox] *outside* the [Material] and [Ink]:
/// ink decorations are clipped to their own rectangle, which used to turn the
/// glow into a visible square behind the circle.
class EmergencyButton extends StatefulWidget {
  const EmergencyButton({super.key});

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
        .scale(kEmergencyButtonSize)
        .clamp(kEmergencyButtonSize, kEmergencyButtonSize * 1.5);
    final outer = diameter * 1.45;

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
                      gradient: RadialGradient(
                        center: Alignment(-0.3, -0.4),
                        radius: 1.0,
                        colors: [kEmergencyRedHighlight, kEmergencyRed],
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
        return Transform.scale(
          scale: 1.0 + 0.42 * t,
          child: Opacity(
            opacity: 0.30 * (1 - t),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kEmergencyRed, width: 3),
                color: kEmergencyRed.withValues(alpha: 0.10),
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
        padding: EdgeInsets.all(kSpaceLG),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 44),
                SizedBox(height: 4),
                Text(
                  'EMERGENCY',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap for immediate help',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: kFontSmall, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
