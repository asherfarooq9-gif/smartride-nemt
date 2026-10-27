import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

void main() {
  // testWidgets (not test): the theme builds DM Sans styles, and the font
  // download that google_fonts attempts fails harmlessly in the widget zone.
  final themes = <String, ThemeData Function()>{
    'patient light': () => AppTheme.patient(),
    'patient dark': () => AppTheme.patient(dark: true),
    'driver light': () => AppTheme.driver(),
    'driver dark': () => AppTheme.driver(dark: true),
  };

  themes.forEach((name, build) {
    group(name, () {
      testWidgets('has no Material surface tint washing over cards',
          (tester) async {
        expect(build().colorScheme.surfaceTint, Colors.transparent);
      });

      testWidgets(
          'app bar does not change colour when content scrolls under it',
          (tester) async {
        expect(build().appBarTheme.scrolledUnderElevation, 0);
      });

      testWidgets('pages swipe back like iOS on every platform',
          (tester) async {
        final theme = build();
        for (final platform in TargetPlatform.values) {
          expect(
            theme.pageTransitionsTheme.builders[platform],
            isA<CupertinoPageTransitionsBuilder>(),
            reason: '$platform',
          );
        }
      });

      testWidgets('sheets, dialogs and cards use the shared shape scale',
          (tester) async {
        final theme = build();
        final sheet = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
        expect(
          sheet.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
        );
        final dialog = theme.dialogTheme.shape as RoundedRectangleBorder;
        expect(dialog.borderRadius, BorderRadius.circular(kRadiusXXL));
        final card = theme.cardTheme.shape as RoundedRectangleBorder;
        expect(card.borderRadius, BorderRadius.circular(kRadiusXL));
      });

      testWidgets('bottom sheets show a drag handle', (tester) async {
        expect(build().bottomSheetTheme.showDragHandle, isTrue);
      });
    });
  });
}
