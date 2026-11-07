import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG relative luminance.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two colours (1 to 21).
double contrast(Color a, Color b) {
  final l1 = luminance(a);
  final l2 = luminance(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}
