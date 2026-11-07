import 'package:flutter_map/flutter_map.dart';

/// Esri's gray canvas: a pale street map whose labels are in English, unlike
/// the public OpenStreetMap tiles, which print the local name (Urdu script in
/// Pakistan). It needs no API key. Its streets, parks and water are all gray,
/// so only the blue location dot and the red SOS carry colour.
const _kEsriCanvas =
    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas';

/// Esri serves real tiles up to this zoom; flutter_map stretches them beyond.
const kMapNativeMaxZoom = 16;

/// Shown on the map. Esri's terms require it to stay visible.
const kMapAttribution = 'Esri, HERE, Garmin, OpenStreetMap contributors';

/// The map base plus its separate label layer, light or dark.
///
/// Esri ships the labels as their own transparent layer, so the two must be
/// drawn in this order.
List<TileLayer> englishTileLayers({bool dark = false}) {
  final style = dark ? 'Dark' : 'Light';
  TileLayer layer(String kind) => TileLayer(
        urlTemplate:
            '$_kEsriCanvas/World_${style}_Gray_$kind/MapServer/tile/{z}/{y}/{x}',
        maxNativeZoom: kMapNativeMaxZoom,
        userAgentPackageName: 'com.smartride.patient',
      );
  return [layer('Base'), layer('Reference')];
}
