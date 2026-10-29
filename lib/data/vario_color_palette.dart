import 'package:flutter/material.dart';

const double varioColorMinSpeed = -10.0;
const double varioColorMaxSpeed = 10.0;

const varioColorStops = <(double, Color)>[
  (varioColorMinSpeed, Color(0xFF000B1E)),
  (-7.0, Color(0xFF0D47A1)),
  (-3.0, Color(0xFF00BCD4)),
  (0.0, Color(0xFF9E9E9E)),
  (3.0, Color(0xFF4CAF50)),
  (7.0, Color(0xFFF44336)),
  (varioColorMaxSpeed, Color(0xFF4A0033)),
];

/// Maps vertical speed (m/s) to the Vario bar's interpolated color.
Color varioColorFor(double v) {
  if (v.isNaN) return varioColorStops[3].$2;
  if (v <= varioColorStops.first.$1) return varioColorStops.first.$2;
  if (v >= varioColorStops.last.$1) return varioColorStops.last.$2;

  for (int i = 0; i < varioColorStops.length - 1; i++) {
    final lower = varioColorStops[i];
    final upper = varioColorStops[i + 1];
    if (v == lower.$1) return lower.$2;
    if (v <= upper.$1) {
      final t = (v - lower.$1) / (upper.$1 - lower.$1);
      return Color.lerp(lower.$2, upper.$2, t)!;
    }
  }
  return varioColorStops.last.$2;
}

/// Samples the Vario palette from its minimum to maximum speed.
List<Color> sampleVarioColorGradient(int steps) {
  final count = steps < 2 ? 2 : steps;
  return List.generate(count, (i) {
    final fraction = i / (count - 1);
    final speed =
        varioColorMinSpeed +
        (varioColorMaxSpeed - varioColorMinSpeed) * fraction;
    return varioColorFor(speed);
  });
}
