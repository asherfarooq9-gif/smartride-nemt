import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/shared/press_scale.dart';

/// Text and tint colours for the home sheet: deep navy on a light sheet, the
/// theme's own colours on a dark one.
class HomePalette {
  const HomePalette._({
    required this.heading,
    required this.muted,
    required this.iconTint,
    required this.iconColor,
    required this.cardFill,
    required this.cardEdge,
  });

  factory HomePalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (scheme.brightness == Brightness.dark) {
      return HomePalette._(
        heading: scheme.onSurface,
        muted: scheme.onSurfaceVariant,
        iconTint: scheme.primaryContainer,
        iconColor: scheme.onPrimaryContainer,
        cardFill: Colors.white.withValues(alpha: 0.08),
        cardEdge: Colors.white.withValues(alpha: 0.12),
      );
    }
    return HomePalette._(
      heading: _kNavy,
      muted: _kMutedBlueGray,
      iconTint: _kLightBlue,
      iconColor: _kNavy,
      cardFill: Colors.white.withValues(alpha: 0.72),
      cardEdge: Colors.white.withValues(alpha: 0.9),
    );
  }

  final Color heading;
  final Color muted;
  final Color iconTint;
  final Color iconColor;
  final Color cardFill;
  final Color cardEdge;
}

const _kNavy = Color(0xFF101F3D);
const _kMutedBlueGray = Color(0xFF55678A); // 5.5:1 on white
const _kLightBlue = Color(0xFFE5F0FF);

/// A translucent white card on the home sheet.
///
/// It is a tinted fill with a hairline edge and a soft shadow, not another
/// blur: the sheet behind it is already blurred, and a second backdrop filter
/// per card would cost frames for no visible gain.
class HomeGlassCard extends StatelessWidget {
  const HomeGlassCard({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 20,
  });

  final Widget child;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    final shape = BorderRadius.circular(radius);
    return PressScale(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: kShadowInk.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: palette.cardFill,
          shape: RoundedRectangleBorder(
            borderRadius: shape,
            side: BorderSide(color: palette.cardEdge),
          ),
          child: InkWell(
            borderRadius: shape,
            onTap: onTap,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A small round icon on a light-blue disc.
class HomeIconDisc extends StatelessWidget {
  const HomeIconDisc({super.key, required this.icon, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    return DecoratedBox(
      decoration:
          BoxDecoration(color: palette.iconTint, shape: BoxShape.circle),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size * 0.5, color: palette.iconColor),
      ),
    );
  }
}
