import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';

/// The big red SOS button on the home screen.
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
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
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
    context.push('/symptoms');
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    // Grow with the system font size so the label always fits the circle.
    final diameter = MediaQuery.textScalerOf(context)
        .scale(kEmergencyButtonSize)
        .clamp(kEmergencyButtonSize, kEmergencyButtonSize * 1.5);

    return Semantics(
      label: 'Request emergency ride',
      hint: 'Double tap to get immediate help',
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: diameter + 40,
        height: diameter + 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!disableAnimations)
              _PulseRing(
                key: const ValueKey('emergency-pulse'),
                animation: _pulse,
                size: diameter,
              ),
            DecoratedBox(
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
          ],
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({super.key, required this.animation, required this.size});
  final Animation<double> animation;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Transform.scale(
          scale: 1.0 + 0.22 * t,
          child: Opacity(
            opacity: 0.25 * (1 - t),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: kEmergencyRed,
                shape: BoxShape.circle,
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
                Icon(Icons.add, color: Colors.white, size: 40),
                SizedBox(height: 4),
                Text(
                  'EMERGENCY',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
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
