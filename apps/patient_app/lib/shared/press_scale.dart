import 'package:flutter/material.dart';

/// Shrinks its child slightly while it is pressed, like a native control.
///
/// It only watches the pointer; the child keeps its own tap handling, or pass
/// [onTap] for a plain tappable area. The shrink is skipped when the user has
/// turned animations off.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = _isPressed && !reduceMotion ? widget.pressedScale : 1.0;

    Widget content = AnimatedScale(
      scale: scale,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (widget.onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: content,
      );
    }
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: content,
    );
  }
}
