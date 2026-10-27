import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// How much of the original colour survives (0 = gray, 1 = unchanged).
const _kKeepColour = 0.45;

/// How much of the original tone survives; the rest is pushed towards white.
const _kKeepTone = 0.88;

/// A 5x4 colour matrix that calms the busy OpenStreetMap colours: it removes
/// most of the saturation and lifts the tones towards white (white stays white),
/// so the controls and the red SOS button read clearly over the map.
final List<double> paleTileMatrix = _buildPaleMatrix();

List<double> _buildPaleMatrix() {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722; // luminance weights
  const s = _kKeepColour;
  const k = _kKeepTone;
  const lift = 255 * (1 - k);

  List<double> row(int channel) {
    final weights = [lr, lg, lb].map((w) => w * (1 - s)).toList();
    weights[channel] += s;
    return [...weights.map((w) => w * k), 0, lift];
  }

  return [...row(0), ...row(1), ...row(2), 0, 0, 0, 1, 0];
}

/// The dark-mode counterpart: it inverts the tones (light land becomes dark
/// gray, dark labels become light) and keeps only a little colour, so the map
/// sits quietly behind the controls at night.
final List<double> darkTileMatrix = _buildDarkMatrix();

List<double> _buildDarkMatrix() {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  const s = 0.25; // colour kept
  const k = 0.82; // overall strength
  const lift = 255 * (1 - k) * 0.55;

  List<double> row(int channel) {
    final weights = [lr, lg, lb].map((w) => -w * (1 - s)).toList();
    weights[channel] -= s;
    // Inverted: 255 - c, scaled, then dimmed so white lands near #2a2a2e.
    return [...weights.map((w) => w * k), 0, 255 * k * 0.9 + lift * 0.4];
  }

  return [...row(0), ...row(1), ...row(2), 0, 0, 0, 1, 0];
}

/// The OpenStreetMap tile layer used behind the app, in a pale style.
///
/// This keeps the public OSM server for the pilot. Its usage policy is for
/// light use only, so a hosted tile provider is needed before real scale.
TileLayer paleTileLayer({bool dark = false}) {
  final matrix = dark ? darkTileMatrix : paleTileMatrix;
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.smartride.patient',
    tileBuilder: (context, tileWidget, tile) => ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: tileWidget,
    ),
  );
}
