import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/shared/glass_surface.dart';
import 'package:patient_app/shared/press_scale.dart';

/// A round frosted-glass icon button floating over the map.
///
/// The [tooltip] doubles as the screen-reader label. [hasBadge] draws a small
/// accent dot, for things like unread notifications.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.hasBadge = false,
    this.iconColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool hasBadge;

  /// Defaults to the theme's text colour; pass the accent for action buttons.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: PressScale(
          onTap: () {
            HapticFeedback.selectionClick();
            onPressed();
          },
          child: SizedBox(
            width: kMinTapTarget,
            height: kMinTapTarget,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GlassSurface(
                  borderRadius: BorderRadius.circular(kRadiusPill),
                  child: SizedBox(
                    width: kMinTapTarget,
                    height: kMinTapTarget,
                    child: Icon(icon, color: iconColor ?? scheme.onSurface),
                  ),
                ),
                if (hasBadge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      key: const ValueKey('glass-badge'),
                      decoration: BoxDecoration(
                        color: kEmergencyRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                      child: const SizedBox(width: 10, height: 10),
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
