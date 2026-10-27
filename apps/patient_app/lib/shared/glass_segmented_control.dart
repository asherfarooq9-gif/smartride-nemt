import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/shared/glass_surface.dart';

/// One choice in a [GlassSegmentedControl].
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// A compact iOS-style segmented control on frosted glass: a raised thumb
/// slides under the chosen label.
///
/// It only reports a tap through [onChanged]; the caller decides whether the
/// choice really changes (for example, switching portal leaves the screen).
class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  }) : assert(segments.length >= 2, 'needs at least two segments');

  final List<GlassSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  static const double _segmentWidth = 84;
  static const double _inset = 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final count = segments.length;
    final index =
        segments.indexWhere((s) => s.value == selected).clamp(0, count - 1);

    return GlassSurface(
      borderRadius: BorderRadius.circular(kRadiusPill),
      padding: const EdgeInsets.all(_inset),
      child: SizedBox(
        height: kMinTapTarget - 2 * _inset,
        width: _segmentWidth * count,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment(-1 + 2 * index / (count - 1), 0),
              child: FractionallySizedBox(
                key: const ValueKey('segment-thumb'),
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                    boxShadow: kCardShadow,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final segment in segments)
                  _SegmentLabel(
                    label: segment.label,
                    isSelected: segment.value == selected,
                    onTap: () {
                      if (segment.value == selected) return;
                      HapticFeedback.selectionClick();
                      onChanged(segment.value);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpaceSM),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: kFontSmall,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
