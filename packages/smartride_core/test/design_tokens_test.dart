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
      'white on patient blue': (kOnPrimary, kPatientPrimary),
      'white on driver blue': (kOnPrimary, kDriverPrimary),
      'white on emergency red': (Colors.white, kEmergencyRed),
      'white on emergency red highlight': (
        Colors.white,
        kEmergencyRedHighlight
      ),
      'blue link on card': (kPatient600, kSurface),
      'blue link on page': (kPatient600, kCanvas),
      'blue on grouped rows': (kPatient600, kSurface2),
      'blue text on selected tint': (kPatient600, kPatient100),
      'dark blue on selected tint': (kPatient800, kPatient100),
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
      'blue on card': (kDarkAccent, kDarkSurface),
      'blue on page': (kDarkAccent, kDarkBg),
      'blue on raised card': (kDarkAccent, kDarkSurface2),
      'text on dark blue container': (
        kDarkOnPatientContainer,
        kDarkPatientContainer
      ),
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

  group('picture palette', () {
    test('the iOS blue is for icons and the dot, so it needs 3:1', () {
      expect(contrast(kBlueIos, kSurface), greaterThanOrEqualTo(3));
    });

    test('the page, card and grouped-row surfaces match the design', () {
      expect(kCanvas, const Color(0xFFF8F9FB));
      expect(kSurface, const Color(0xFFFFFFFF));
      expect(kSurface2, const Color(0xFFF2F3F5));
    });

    test('secondary text keeps 4.5:1 on the page', () {
      expect(contrast(kText400, kCanvas), greaterThanOrEqualTo(4.5));
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
