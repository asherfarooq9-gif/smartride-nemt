import 'dart:async' as async show AsyncError;
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:patient_app/shared/map_style_cache.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

/// OpenFreeMap's colourful styles: cream land, green parks, light-blue water,
/// yellow main roads. Free and without an API key.
const kLightMapStyleUri = 'https://tiles.openfreemap.org/styles/liberty';
const kDarkMapStyleUri = 'https://tiles.openfreemap.org/styles/dark';

/// Shown on the map. The OpenFreeMap and OpenMapTiles terms require it.
const kVectorMapAttribution =
    'OpenFreeMap  © OpenMapTiles  Data from OpenStreetMap';

/// Every label draws the Latin name when there is one.
///
/// The styles print "Latin + local script" (for example "Jinnah Avenue" next to
/// its Urdu name) whenever a place has a non-Latin name. This swaps those label
/// expressions for English first, then the Latin name, then the local name.
/// Returns a new map; the input is left alone.
Map<String, dynamic> withEnglishLabels(Map<String, dynamic> style) {
  const english = [
    'coalesce',
    ['get', 'name:latin'],
    ['get', 'name_en'],
    ['get', 'name'],
  ];
  final layers = (style['layers'] as List).map((layer) {
    if (layer is! Map<String, dynamic>) return layer;
    final layout = layer['layout'];
    final textField = layout is Map ? layout['text-field'] : null;
    if (!jsonEncode(textField).contains('name:nonlatin')) return layer;
    return {
      ...layer,
      'layout': {...(layout as Map<String, dynamic>), 'text-field': english},
    };
  }).toList();
  return {...style, 'layers': layers};
}

/// A loaded map style: the colours (with English labels), where to fetch the
/// tiles and the icon atlas.
class EnglishMapStyle {
  const EnglishMapStyle({
    required this.theme,
    required this.providers,
    required this.sprites,
  });

  final vtr.Theme theme;
  final TileProviders providers;
  final SpriteStyle? sprites;
}

/// Waits for both futures, which run at the same time. If either fails, the
/// original error is rethrown with its own stack trace, not the
/// [ParallelWaitError] wrapper that `.wait` produces. Both futures are always
/// waited for, so neither is left to fail unobserved.
Future<(A, B)> awaitBothKeepingFirstError<A, B>(
  Future<A> first,
  Future<B> second,
) async {
  try {
    return await (first, second).wait;
  } on ParallelWaitError<dynamic, dynamic> catch (e) {
    final errors = e.errors as (async.AsyncError?, async.AsyncError?);
    final failure = errors.$1 ?? errors.$2;
    if (failure == null) rethrow;
    Error.throwWithStackTrace(failure.error, failure.stackTrace);
  }
}

/// Every download here goes through a short disk cache, so a relaunch within
/// [kMapStyleCacheTtl] does not wait for the network again.
Future<EnglishMapStyle> loadEnglishMapStyle(String uri) {
  return withMapStyleCache(() async {
    // The package resolves the tile sources and the icon sprites, but builds
    // its theme from the unpatched style, so we also fetch the same style to
    // patch. Started together: one after the other, the second download only
    // added its latency.
    final (style, response) = await awaitBothKeepingFirstError(
      StyleReader(uri: uri).read(),
      http.get(Uri.parse(uri)),
    );
    if (response.statusCode != 200) {
      throw StateError('Map style ${response.statusCode}: $uri');
    }
    final patched = withEnglishLabels(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return EnglishMapStyle(
      theme: vtr.ThemeReader().read(patched),
      providers: style.providers,
      sprites: style.sprites,
    );
  });
}

/// The style for light or dark mode, fetched once per app run.
final englishMapStyleProvider =
    FutureProvider.family<EnglishMapStyle, bool>((ref, isDark) {
  return loadEnglishMapStyle(isDark ? kDarkMapStyleUri : kLightMapStyleUri);
});
