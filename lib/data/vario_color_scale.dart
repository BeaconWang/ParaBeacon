import 'dart:ui' show Color;

/// Threshold-aware, continuously-interpolated colour scale that maps a
/// paraglider's vertical speed (vario, m/s) to a track colour.
///
/// ## Semantics — RED → GRAY → GREEN
///
/// * **RED = sink / descent** (dark red = strong sink)
/// * **GRAY = neutral** (little or no vertical movement)
/// * **GREEN = lift / climb** (dark green = strong lift)
///
/// The neutral GRAY band is delimited by the two configurable thresholds: below
/// [sinkThreshold] the track reddens, above [liftThreshold] it greens, and in
/// between it stays close to neutral gray. Moving a threshold widens/narrows the
/// gray region — the thresholds actively shape the gradient, they are not just
/// legend markers.
///
/// ## Data range vs. visualisation range
///
/// This class only ever produces a *colour*; it never mutates or returns the
/// vertical-speed value. The original vario data must stay untouched for flight
/// analysis, statistics and export. Only the value used for colour lookup is
/// clamped to the **visualisation range** [[colorMin], [colorMax]] (default
/// -6…+6 m/s). Extreme values (e.g. -12 or +15 m/s) are preserved in the data
/// but rendered as the dark-red / dark-green endpoints, so they don't compress
/// the colour resolution of normal flight conditions.
///
/// ## Colour scale (sink → lift)
/// ```
///  colorMin (-6)    #8B0000  dark red    (strong sink)
///   -4 m/s          #D73027  red
///   sinkThreshold   #F4A6A6  light red   (dynamic — sink boundary of gray)
///    0 m/s          #BDBDBD  gray        (neutral)
///   liftThreshold   #B8E0B8  light green (dynamic — lift boundary of gray)
///   +4 m/s          #31A354  green
///  colorMax (+6)    #006D2C  dark green  (strong lift)
/// ```
///
/// Colours are linearly interpolated in RGB between stops — no hard boundaries.
///
/// The class is pure/stateless given its inputs, which makes it trivial to
/// unit-test and cheap to recreate whenever the thresholds or range change.
class VarioColorScale {
  /// Default lower/upper bounds of the visualisation range (m/s). Centralised
  /// here so the literals aren't scattered through the codebase; a future
  /// setting can override them via the constructor.
  static const double defaultColorMin = -6.0;
  static const double defaultColorMax = 6.0;

  // Fixed anchor colours (independent of thresholds), positioned as fractions
  // of the visualisation range so they scale with a custom [colorMin]/[colorMax].
  static const Color _strongSink = Color(0xFF8B0000); // min   dark red
  static const Color _sink = Color(0xFFD73027); // 2/3 sink   red
  static const Color _lightRed = Color(0xFFF4A6A6); // 1/3 sink light red
  static const Color _neutral = Color(0xFFBDBDBD); //   0      gray
  static const Color _lightGreen = Color(0xFFB8E0B8); // 1/3 lift light green
  static const Color _green = Color(0xFF31A354); // 2/3 lift   green
  static const Color _strongLift = Color(0xFF006D2C); // max   dark green

  // Dynamic threshold stop colours: the thresholds bound the neutral gray band,
  // so the sink boundary is light red and the lift boundary is light green.
  static const Color _sinkThresholdColor = _lightRed; // sink threshold
  static const Color _liftThresholdColor = _lightGreen; // lift threshold

  /// Lower / upper bounds of the visualisation range (m/s).
  final double colorMin;
  final double colorMax;

  /// The configured sink threshold (m/s, normally negative).
  final double sinkThreshold;

  /// The configured lift threshold (m/s, normally >= 0).
  final double liftThreshold;

  /// Pre-computed, strictly-increasing colour stops.
  final List<_ColorStop> _stops;

  VarioColorScale({
    required this.sinkThreshold,
    required this.liftThreshold,
    this.colorMin = defaultColorMin,
    this.colorMax = defaultColorMax,
  }) : _stops = _buildStops(
          sinkThreshold,
          liftThreshold,
          // Guard against an inverted/degenerate range so interpolation stays
          // well-defined.
          colorMin,
          colorMax > colorMin ? colorMax : colorMin + 1.0,
        );

  /// Returns the interpolated colour for a vertical speed [mps].
  ///
  /// [mps] is the *original* vario value; it is not modified. Only a local copy
  /// is clamped to [[colorMin], [colorMax]] for the colour lookup, then the two
  /// surrounding stops are linearly interpolated in RGB.
  Color colorFor(double mps) {
    if (mps.isNaN) return _neutral;
    final x = mps.clamp(_stops.first.mps, _stops.last.mps).toDouble();

    // Below/above the first/last stop → the endpoint colour (also covers the
    // clamped extremes exactly).
    if (x <= _stops.first.mps) return _stops.first.color;
    if (x >= _stops.last.mps) return _stops.last.color;

    for (int i = 0; i < _stops.length - 1; i++) {
      final a = _stops[i];
      final b = _stops[i + 1];
      if (x >= a.mps && x <= b.mps) {
        final span = b.mps - a.mps;
        // span is guaranteed > 0 by _buildStops' strict-monotonicity pass, but
        // guard anyway so a degenerate list can never divide by zero.
        final t = span <= 0 ? 0.0 : (x - a.mps) / span;
        return _lerpColor(a.color, b.color, t);
      }
    }
    return _stops.last.color;
  }

  /// Effective sink threshold used for the mapping, clamped into range.
  double get effectiveSinkThreshold =>
      sinkThreshold.clamp(_stops.first.mps, _stops.last.mps).toDouble();

  /// Effective lift threshold used for the mapping, clamped into range.
  double get effectiveLiftThreshold =>
      liftThreshold.clamp(_stops.first.mps, _stops.last.mps).toDouble();

  /// Samples the scale into [steps] evenly-spaced colours across the
  /// visualisation range — handy for painting a legend gradient bar.
  List<Color> sampleGradient(int steps) {
    final n = steps < 2 ? 2 : steps;
    final lo = _stops.first.mps;
    final hi = _stops.last.mps;
    return [
      for (int i = 0; i < n; i++) colorFor(lo + (hi - lo) * (i / (n - 1))),
    ];
  }

  /// Builds the sorted, strictly-increasing stop list from the thresholds and
  /// the visualisation range.
  ///
  /// Fixed anchors are placed at fractions of the range (min, 2/3, 1/3 sink, 0,
  /// 1/3, 2/3 lift, max) so the palette scales with a custom range. The dynamic
  /// threshold stops are then merged in; a final strict-monotonicity pass drops
  /// any duplicate/out-of-order x so interpolation can never divide by zero or
  /// jump backwards — this is what makes arbitrary threshold values (near 0,
  /// equal, both same sign, or sink >= lift) safe.
  static List<_ColorStop> _buildStops(
    double sink,
    double lift,
    double lo,
    double hi,
  ) {
    // Clamp thresholds into range so an out-of-spec value can't push a stop
    // outside the visualisation bounds.
    final s = sink.clamp(lo, hi).toDouble();
    final l = lift.clamp(lo, hi).toDouble();

    // Anchor positions as fractions of each half of the range, so a custom
    // [colorMin]/[colorMax] still yields a sensible spread. Zero is pinned at
    // the true 0 m/s (clamped into range in case the range is one-sided).
    final zero = 0.0.clamp(lo, hi).toDouble();
    final sink23 = lo + (zero - lo) * (1.0 / 3.0); // nearer min  (red)
    final sink13 = lo + (zero - lo) * (2.0 / 3.0); // nearer zero (light red)
    final lift13 = zero + (hi - zero) * (1.0 / 3.0); // nearer zero (light green)
    final lift23 = zero + (hi - zero) * (2.0 / 3.0); // nearer max  (green)

    // Insertion order encodes tie-break priority (lower index wins at an equal
    // speed): the 0 m/s neutral anchor first (0 stays gray even if a threshold
    // sits on zero), then the dynamic threshold stops (a threshold landing on a
    // fixed anchor should take that point), then the remaining fixed anchors.
    final raw = <_ColorStop>[
      _ColorStop(zero, _neutral), //  0    gray    (highest priority)
      _ColorStop(s, _sinkThresholdColor), // sinkThreshold  light red
      _ColorStop(l, _liftThresholdColor), // liftThreshold  light green
      _ColorStop(lo, _strongSink), // min   dark red
      _ColorStop(sink23, _sink), // red
      _ColorStop(sink13, _lightRed), // light red
      _ColorStop(lift13, _lightGreen), // light green
      _ColorStop(lift23, _green), // green
      _ColorStop(hi, _strongLift), // max   dark green
    ];

    // Sort by speed, breaking ties by the insertion index above (Dart's
    // List.sort is not guaranteed stable, so the index is compared explicitly).
    for (int i = 0; i < raw.length; i++) {
      raw[i] = raw[i]._withIndex(i);
    }
    raw.sort((a, b) {
      final c = a.mps.compareTo(b.mps);
      return c != 0 ? c : a.index.compareTo(b.index);
    });

    // Enforce strict monotonicity: drop any stop whose x is <= the previous
    // kept stop's x. This collapses ties (e.g. sinkThreshold == 0, or
    // sink >= lift) into a single well-defined stop and guarantees every
    // adjacent pair has a positive span for interpolation.
    final out = <_ColorStop>[];
    for (final stop in raw) {
      if (out.isEmpty || stop.mps > out.last.mps) {
        out.add(stop);
      }
    }
    // Degenerate safety net: ensure at least two distinct stops.
    if (out.length < 2) {
      out
        ..clear()
        ..add(_ColorStop(lo, _strongSink))
        ..add(_ColorStop(hi, _strongLift));
    }
    return out;
  }

  static Color _lerpColor(Color a, Color b, double t) {
    final tt = t.clamp(0.0, 1.0);
    int lerp(int x, int y) => (x + ((y - x) * tt)).round();
    return Color.fromARGB(
      lerp(_chanA(a), _chanA(b)),
      lerp(_chanR(a), _chanR(b)),
      lerp(_chanG(a), _chanG(b)),
      lerp(_chanB(a), _chanB(b)),
    );
  }

  // 8-bit channel accessors (avoids the deprecated Color.red/.green/.blue and
  // works with the wide-gamut float channels used by newer Flutter). Named
  // `_chanX` to avoid colliding with the colour constants above (e.g. _green).
  static int _chanA(Color c) => (c.a * 255.0).round() & 0xff;
  static int _chanR(Color c) => (c.r * 255.0).round() & 0xff;
  static int _chanG(Color c) => (c.g * 255.0).round() & 0xff;
  static int _chanB(Color c) => (c.b * 255.0).round() & 0xff;
}

/// A single control point on the [VarioColorScale].
class _ColorStop {
  const _ColorStop(this.mps, this.color, [this.index = 0]);

  /// Vertical speed (m/s) at which [color] applies exactly.
  final double mps;
  final Color color;

  /// Insertion index, used only as a deterministic tie-break when two stops
  /// share the same [mps] (see `_buildStops`).
  final int index;

  _ColorStop _withIndex(int i) => _ColorStop(mps, color, i);
}
