import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart';

/// A frosted-glass panel: it blurs what is behind it and tints it with a
/// see-through fill.
///
/// Blur is expensive on low-end phones, so use it on at most two surfaces per
/// screen. It falls back to a solid fill when [blur] is false or the user has
/// turned on high contrast, so text always stays readable.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(kRadiusXL)),
    this.padding = EdgeInsets.zero,
    this.blur = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useBlur = blur && !MediaQuery.highContrastOf(context);
    final base = isDark ? kDarkSurface : kSurface;
    final fill = useBlur ? base.withValues(alpha: 0.78) : base;
    final edge = isDark ? kDarkBorder : kBorderLight;

    final panel = DecoratedBox(
      key: const ValueKey('glass-fill'),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: edge, width: 0.5),
      ),
      child: Padding(padding: padding, child: child),
    );

    // The shadow sits outside the clip, or the clip would cut it off.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: kCardShadow,
      ),
      child: useBlur
          ? ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: panel,
              ),
            )
          : panel,
    );
  }
}
