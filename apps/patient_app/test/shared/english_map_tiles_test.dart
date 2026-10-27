import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/shared/english_map_tiles.dart';

void main() {
  test('draws the map base first and the English label layer on top', () {
    final layers = englishTileLayers();

    expect(layers, hasLength(2));
    expect(layers[0].urlTemplate, contains('World_Light_Gray_Base'));
    expect(layers[1].urlTemplate, contains('World_Light_Gray_Reference'));
  });

  test('the dark style uses the dark gray base and labels', () {
    final layers = englishTileLayers(dark: true);

    expect(layers[0].urlTemplate, contains('World_Dark_Gray_Base'));
    expect(layers[1].urlTemplate, contains('World_Dark_Gray_Reference'));
  });

  test('uses the {z}/{y}/{x} order Esri expects and stops at native zoom 16',
      () {
    for (final layer in englishTileLayers()) {
      expect(layer.urlTemplate, endsWith('/tile/{z}/{y}/{x}'));
      expect(layer.maxNativeZoom, 16);
      expect(layer.tileProvider.headers['User-Agent'],
          contains('com.smartride.patient'));
    }
  });
}
