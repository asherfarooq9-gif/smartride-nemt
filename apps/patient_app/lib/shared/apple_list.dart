import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartride_core/smartride_core.dart' as core;

const double _kIconTile = 30;
const double _kRowHeight = 48;

/// An iOS "inset grouped" list: rows on one rounded surface, a thin line
/// between them, and a small header above. Rows are [AppleRow] or
/// [AppleSwitchRow].
class AppleSection extends StatelessWidget {
  const AppleSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.dividerIndent = core.kSpaceLG,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  /// Where the line between rows starts. Use [appleIconDividerIndent] when
  /// every row has an icon tile, so the line starts under the text.
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        core.kSpaceLG,
        core.kSpaceMD,
        core.kSpaceLG,
        core.kSpaceXS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: core.kSpaceLG,
                bottom: core.kSpaceSM,
              ),
              child: Text(header!, style: small),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(core.kRadiusMD),
            child: ColoredBox(
              color: scheme.surface,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: dividerIndent,
                        color: scheme.outlineVariant,
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: core.kSpaceLG,
                top: core.kSpaceSM,
              ),
              child: Text(footer!, style: small),
            ),
        ],
      ),
    );
  }
}

/// Divider indent that lines up with the text after a 30 px icon tile.
const double appleIconDividerIndent =
    core.kSpaceLG + _kIconTile + core.kSpaceMD;

/// A small coloured rounded square holding a white icon, as in iOS Settings.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('apple-row-icon-tile'),
      width: _kIconTile,
      height: _kIconTile,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

/// One row: optional icon tile, title, optional value, and a chevron when it
/// opens something. Built on [ListTile] so taps, focus and screen readers
/// behave as they do everywhere else in the app.
class AppleRow extends StatelessWidget {
  const AppleRow({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final IconData? icon;

  /// Colour of the icon tile. Defaults to the portal blue.
  final Color? iconColor;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// For sign out and delete: red text and a red icon tile.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    // iOS secondary text, and a chevron lighter still (it is only a hint).
    final hint = isDark ? core.kDarkText3 : core.kText400;
    final chevron = hint.withValues(alpha: 0.6);
    // The dark-mode red keeps 4.5:1 on dark rows; the plain red does not.
    final red = isDark ? core.kDarkRed : core.kError;
    final tileColor = destructive ? core.kError : (iconColor ?? scheme.primary);
    final end = trailing ??
        ((value != null || onTap != null)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null)
                    Text(
                      value!,
                      style: TextStyle(
                        color: hint,
                        fontSize: core.kFontBody,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, size: 22, color: chevron),
                ],
              )
            : null);
    return ListTile(
      minTileHeight: _kRowHeight,
      contentPadding: const EdgeInsets.symmetric(horizontal: core.kSpaceLG),
      horizontalTitleGap: core.kSpaceMD,
      leading: icon == null ? null : _IconTile(icon: icon!, color: tileColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: core.kFontBody,
          color: destructive ? red : scheme.onSurface,
        ),
      ),
      trailing: end,
      onTap: onTap,
    );
  }
}

/// A row with an iOS switch. Tapping the row or the switch both toggle it.
class AppleSwitchRow extends StatelessWidget {
  const AppleSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.iconColor,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final Color? iconColor;

  void _set(bool next) {
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: _kRowHeight,
      contentPadding: const EdgeInsets.symmetric(horizontal: core.kSpaceLG),
      horizontalTitleGap: core.kSpaceMD,
      leading: icon == null
          ? null
          : _IconTile(icon: icon!, color: iconColor ?? scheme.primary),
      title: Text(
        title,
        style: TextStyle(fontSize: core.kFontBody, color: scheme.onSurface),
      ),
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: core.kIosGreen,
        onChanged: _set,
      ),
      onTap: () => _set(!value),
    );
  }
}
