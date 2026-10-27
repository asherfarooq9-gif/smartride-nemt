import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

/// WCAG relative luminance and contrast ratio.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

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
        final isPureBlack = shadow.color.r == 0 &&
            shadow.color.g == 0 &&
            shadow.color.b == 0;
        expect(isPureBlack, isFalse);
      }
    });
  });
}
