import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

import 'contrast_helper.dart';

void main() {
  group('light theme text contrast (WCAG AA, 4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'primary text on card': (kText900, kSurface),
      'primary text on page': (kText900, kCanvas),
      'secondary text on card': (kText600, kSurface),
      'secondary text on page': (kText600, kCanvas),
      'hint text on card': (kText400, kSurface),
      'hint text on page': (kText400, kCanvas),
      'white on patient teal': (kOnPrimary, kPatientPrimary),
      'white on driver blue': (kOnPrimary, kDriverPrimary),
      'white on emergency red': (Colors.white, kEmergencyRed),
      'white on emergency red highlight': (
        Colors.white,
        kEmergencyRedHighlight
      ),
      'teal link on card': (kTeal600, kSurface),
      'teal text on selected tint': (kTeal600, kTeal100),
      'error text on page': (kError, kCanvas),
    };
    pairs.forEach((name, pair) {
      test(name, () {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      });
    });
  });

  group('dark theme text contrast (WCAG AA, 4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'primary text on card': (kDarkText1, kDarkSurface),
      'primary text on page': (kDarkText1, kDarkBg),
      'primary text on raised card': (kDarkText1, kDarkSurface2),
      'secondary text on card': (kDarkText2, kDarkSurface),
      'secondary text on raised card': (kDarkText2, kDarkSurface2),
      'hint text on card': (kDarkText3, kDarkSurface),
      'teal on card': (kDarkTeal, kDarkSurface),
      'teal on page': (kDarkTeal, kDarkBg),
      'red on card': (kDarkRed, kDarkSurface),
      'driver blue accent on card': (kBlueAccentDark, kDarkSurface),
    };
    pairs.forEach((name, pair) {
      test(name, () {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      });
    });

    test('the page is near-black and cards step up from it', () {
      expect(luminance(kDarkBg), lessThan(0.01));
      expect(luminance(kDarkSurface), greaterThan(luminance(kDarkBg)));
      expect(luminance(kDarkSurface2), greaterThan(luminance(kDarkSurface)));
    });
  });

  group('shape scale', () {
    test('sheets, cards and controls use 28 / 20 / 12', () {
      expect(kRadiusSheet, 28);
      expect(kRadiusXL, 20);
      expect(kRadiusLG, 12);
    });
  });

  group('shadows', () {
    test('are tinted, never pure black', () {
      for (final shadow in [
        ...kCardShadow,
        ...kRaisedCardShadow,
        ...kSheetShadow,
      ]) {
        final isPureBlack =
            shadow.color.r == 0 && shadow.color.g == 0 && shadow.color.b == 0;
        expect(isPureBlack, isFalse);
      }
    });
  });
}
