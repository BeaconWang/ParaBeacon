import 'package:flutter/material.dart';

import 'vario_color_settings.dart';

const double varioColorMinSpeed = -10.0;
const double varioColorMaxSpeed = 10.0;

const List<double> _varioColorSpeeds = [
  varioColorMinSpeed,
  -7.0,
  -3.0,
  0.0,
  3.0,
  7.0,
  varioColorMaxSpeed,
];

List<(double, Color)> get varioColorStops =>
    varioColorStopsFor(VarioColorSettings.instance.colors);

List<(double, Color)> varioColorStopsFor(List<int> colors) => [
  for (var i = 0; i < _varioColorSpeeds.length; i++)
    (_varioColorSpeeds[i], Color(colors[i])),
];

/// Maps vertical speed (m/s) to an interpolated color from the shared palette.
Color varioColorFor(double v, {List<int>? colors}) {
  final stops = varioColorStopsFor(
    colors ?? VarioColorSettings.instance.colors,
  );
  if (v.isNaN) return stops[3].$2;
  if (v <= stops.first.$1) return stops.first.$2;
  if (v >= stops.last.$1) return stops.last.$2;

  for (int i = 0; i < stops.length - 1; i++) {
    final lower = stops[i];
    final upper = stops[i + 1];
    if (v == lower.$1) return lower.$2;
    if (v <= upper.$1) {
      final t = (v - lower.$1) / (upper.$1 - lower.$1);
      return Color.lerp(lower.$2, upper.$2, t)!;
    }
  }
  return stops.last.$2;
}

/// Samples the shared palette from its minimum to maximum speed.
List<Color> sampleVarioColorGradient(int steps) {
  final count = steps < 2 ? 2 : steps;
  final colors = VarioColorSettings.instance.colors;
  return List.generate(count, (i) {
    final fraction = i / (count - 1);
    final speed =
        varioColorMinSpeed +
        (varioColorMaxSpeed - varioColorMinSpeed) * fraction;
    return varioColorFor(speed, colors: colors);
  });
}
