import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart';

/// A frosted-glass panel: it blurs what is behind it and tints it with a
/// see-through fill.
///
/// Blur is expensive on low-end phones, so keep it to the few surfaces that
/// need it. It falls back to a solid fill when [blur] is false or the user has
/// turned on high contrast, so text always stays readable.
///
/// [sigma], [opacity], [borderColor], [borderWidth] and [shadows] default to
/// the small-control look; text-heavy surfaces such as the home sheet raise
/// [opacity] so what is written on them stays easy to read.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(kRadiusXL)),
    this.padding = EdgeInsets.zero,
    this.blur = true,
    this.sigma = 18,
    this.opacity = 0.78,
    this.borderColor,
    this.borderWidth = 0.5,
    this.shadows,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final bool blur;

  /// How strongly the backdrop is blurred (Gaussian sigma, in logical pixels).
  final double sigma;

  /// How opaque the tint is while blurring; 1 is solid.
  final double opacity;

  /// Defaults to the theme's light or dark hairline.
  final Color? borderColor;
  final double borderWidth;

  /// Defaults to the soft card shadow.
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useBlur = blur && !MediaQuery.highContrastOf(context);
    final base = isDark ? kDarkSurface : kSurface;
    final fill = useBlur ? base.withValues(alpha: opacity) : base;
    final edge = borderColor ?? (isDark ? kDarkBorder : kBorderLight);

    final panel = DecoratedBox(
      key: const ValueKey('glass-fill'),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: edge, width: borderWidth),
      ),
      child: Padding(padding: padding, child: child),
    );

    // The shadow sits outside the clip, or the clip would cut it off.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows ?? kCardShadow,
      ),
      child: useBlur
          ? ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: panel,
              ),
            )
          : panel,
    );
  }
}
