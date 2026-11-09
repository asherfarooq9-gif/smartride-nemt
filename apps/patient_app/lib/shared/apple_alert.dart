import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const double _kAlertWidth = 300;
const double _kActionHeight = 48;

/// An iOS-style alert: rounded, a centred title and message, then a thin line
/// and the actions. Two actions sit side by side; three or more stack.
///
/// Pass [TextButton]s as [actions] exactly as for an [AlertDialog]; they keep
/// their own `onPressed` and colour (use the red for a destructive one).
class AppleAlertDialog extends StatelessWidget {
  const AppleAlertDialog({
    super.key,
    this.title,
    this.content,
    required this.actions,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.outlineVariant;
    final sideBySide = actions.length <= 2;

    Widget action(Widget a) => SizedBox(height: _kActionHeight, child: a);

    return Dialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: core.kSpaceXXL,
        vertical: core.kSpaceXL,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kAlertWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  core.kSpaceLG,
                  core.kSpaceXL,
                  core.kSpaceLG,
                  core.kSpaceLG,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      DefaultTextStyle.merge(
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                        child: title!,
                      ),
                    if (title != null && content != null)
                      const SizedBox(height: core.kSpaceSM),
                    if (content != null)
                      DefaultTextStyle.merge(
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                        child: content!,
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 0.5, thickness: 0.5, color: line),
            TextButtonTheme(
              data: TextButtonThemeData(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, _kActionHeight),
                  shape: const RoundedRectangleBorder(),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              child: sideBySide
                  ? IntrinsicHeight(
                      child: Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0)
                              VerticalDivider(
                                width: 0.5,
                                thickness: 0.5,
                                color: line,
                              ),
                            Expanded(child: action(actions[i])),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0)
                            Divider(height: 0.5, thickness: 0.5, color: line),
                          action(actions[i]),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
