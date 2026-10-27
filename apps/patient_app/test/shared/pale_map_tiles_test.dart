import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/pale_map_tiles.dart';

/// Applies the 5x4 colour matrix (rows R, G, B, A; last column is an offset in
/// 0-255) to an RGB pixel, the way ColorFilter.matrix does.
List<double> _apply(List<double> m, List<double> rgb) {
  double row(int r) => (m[r * 5] * rgb[0] +
          m[r * 5 + 1] * rgb[1] +
          m[r * 5 + 2] * rgb[2] +
          m[r * 5 + 4])
      .clamp(0, 255)
      .toDouble();
  return [row(0), row(1), row(2)];
}

double _saturation(List<double> c) => c.reduce(math.max) - c.reduce(math.min);

double _brightness(List<double> c) => (c[0] + c[1] + c[2]) / 3;

void main() {
  test('a saturated map colour comes out calmer and lighter', () {
    const parkGreen = <double>[170, 218, 170];

    final pale = _apply(paleTileMatrix, parkGreen);

    expect(_saturation(pale), lessThan(_saturation(parkGreen) * 0.6));
    expect(_brightness(pale), greaterThan(_brightness(parkGreen)));
  });

  test('white stays white, so the page edge does not turn gray', () {
    final pale = _apply(paleTileMatrix, [255, 255, 255]);

    expect(pale, everyElement(closeTo(255, 0.5)));
  });

  test('the layer keeps the OpenStreetMap user agent and uses the filter', () {
    final layer = paleTileLayer();

    expect(layer, isA<TileLayer>());
    expect(
      layer.tileProvider.headers['User-Agent'],
      contains('com.smartride.patient'),
    );
    expect(layer.tileBuilder, isNotNull);
  });
}
