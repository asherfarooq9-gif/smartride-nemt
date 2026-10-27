import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

import 'contrast_helper.dart';

void main() {
  // testWidgets (not test): the theme builds DM Sans styles, and the font
  // download that google_fonts attempts fails harmlessly in the widget zone.
  final themes = <String, ThemeData Function()>{
    'patient light': () => AppTheme.patient(),
    'patient dark': () => AppTheme.patient(dark: true),
    'driver light': () => AppTheme.driver(),
    'driver dark': () => AppTheme.driver(dark: true),
  };

  group('brand-tinted colour roles', () {
    testWidgets('light themes use the pale portal tint and iOS grays',
        (tester) async {
      final patient = AppTheme.patient().colorScheme;
      final driver = AppTheme.driver().colorScheme;

      expect(patient.primaryContainer, kTeal100);
      expect(driver.primaryContainer, kBlue100);
      expect(patient.onPrimaryContainer, kTeal800);
      expect(driver.onPrimaryContainer, kBlue800);
      expect(patient.onSurfaceVariant, kText600);
      expect(patient.surfaceContainerLow, kCanvas);
      expect(patient.outlineVariant, kBorder);
    });

    testWidgets('dark themes use dark tints and iOS dark grays',
        (tester) async {
      final patient = AppTheme.patient(dark: true).colorScheme;
      final driver = AppTheme.driver(dark: true).colorScheme;

      expect(patient.primaryContainer, isNot(kTeal100));
      expect(patient.primaryContainer, isNot(driver.primaryContainer));
      expect(patient.onSurfaceVariant, kDarkText2);
      expect(patient.surfaceContainerLow, kDarkSurface2);
      expect(patient.outlineVariant, kDarkBorder);
    });
  });

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

      testWidgets(
          'colour roles for tinted cards and secondary text are readable',
          (tester) async {
        final scheme = build().colorScheme;

        expect(
          contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: 'text on the tinted card',
        );
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: 'secondary text on cards',
        );
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(4.5),
          reason: 'secondary text on grouped rows',
        );
        expect(
          contrast(scheme.onSurface, scheme.surfaceContainerLow),
          greaterThanOrEqualTo(4.5),
          reason: 'primary text on grouped rows',
        );
        expect(scheme.surfaceContainerLow, isNot(scheme.surface));
      });

      testWidgets('bottom sheets show a drag handle', (tester) async {
        expect(build().bottomSheetTheme.showDragHandle, isTrue);
      });
    });
  });
}
