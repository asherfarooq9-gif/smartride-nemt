# ADR 0002: Colourful English map (OpenFreeMap) and a frosted home sheet

- Status: accepted
- Date: 2026-10-27
- Amends: ADR 0001 decisions 6 and 9

## Context

The public OpenStreetMap tiles print each place's local name, which is Urdu script
in Islamabad and Rawalpindi, and the product owner wants English labels. Changing
the app locale cannot translate text baked into raster tiles. Keyless raster
providers that are both colourful and English do not exist any more: CARTO,
Stadia and Thunderforest now answer "API key required". Esri's gray canvas is
English and free, but gray; Esri's street map is English but beige and orange.

## Decision

1. **Basemap:** OpenFreeMap's `liberty` (light) and `dark` vector styles, drawn
   on the device with `vector_map_tiles`. No API key. Cream land, green parks,
   blue water and yellow main roads, like Apple Maps.
2. **English labels:** the styles print "Latin + local script" for places with a
   non-Latin name. `withEnglishLabels` rewrites those label expressions to the
   Latin name first, then English, then the local name.
3. **Fallback:** if the style cannot be loaded (offline, service down), the map
   falls back to Esri's gray canvas, still in English (`english_map_tiles.dart`).
4. **Web:** `vector_map_tiles` 8.0.0 does not run in a browser (disk cache via
   `dart:io`, isolate pool). It is vendored in `third_party/vector_map_tiles` with
   two small patches, listed in `SMARTRIDE_PATCH.md`. Mobile and desktop behave as
   upstream. Revisit when upstream supports web.
5. **The home sheet is frosted glass** (`GlassSurface`, sigma 24, 74% opacity), and
   the tab bar is a full-width frosted panel with rounded top corners. The home
   screen now blurs five regions: the sheet, the tab bar, the two round buttons
   and the Patient | Driver switch. This replaces the "at most two" rule in
   ADR 0001. High-contrast mode still falls back to solid fills. The cards on the
   sheet are translucent fills, not extra blurs.
6. The map centres the patient in the part of the map the sheet leaves uncovered,
   not behind the sheet.

## Consequences

- OpenFreeMap is free and community run, with no uptime promise. Before real scale,
  self-host the tiles or move to a paid provider that serves the same OpenMapTiles
  schema; the style and the label patch carry over.
- Esri's public tiles (the fallback) have their own terms; check them before scale.
- A vendored package must be re-patched when upgrading `vector_map_tiles`.
- Vector rendering costs more than raster and the sheet blurs a large area; measure
  on a low-end phone (such as the Samsung A07). If it janks, turn off blur on the
  round buttons first.
- The "Safety Tips" card on the home sheet opens the Help screen (emergency
  guidance and FAQ), and "Favorites" opens saved places.
