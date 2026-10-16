// vario_sound_curve.dart
// -----------------------------------------------------------------------------
// Anchor-point based vario sound curve (XCTrack "Custom sound" model).
//
// The vario tone is described by a set of anchor points, each mapping a
// vertical speed (m/s) to three synthesis parameters:
//   * frequency (Hz)   — tone pitch,
//   * cycle     (ms)   — full beep+pause loop period,
//   * duty      (%)    — fraction of the cycle that is audible tone.
//
// Between anchors, all three parameters are linearly interpolated, so any
// vertical speed yields a smooth (frequency, cycle, duty) sample. Outside the
// anchor range the first/last segment is linearly extrapolated, matching
// XCTrack's mapper rather than clamping to the endpoint.
//
// Synthesis rules (see VarioSynth):
//   * duty >= 100%  -> continuous tone (LONG), no gaps.
//   * 0 < duty < 100% -> intermittent beep (TACK):
//        toneMs = cycleMs * duty/100; then the remainder is silence.
//   * duty <= 0% -> silence.
// -----------------------------------------------------------------------------

import 'dart:math' as math;

/// A single anchor point of a [VarioSoundCurve].
class VarioSoundAnchor {
  /// Vertical speed at this anchor, m/s (positive = climb/lift).
  final double lift;

  /// Tone frequency at this anchor, Hz.
  final double freqHz;

  /// Full beep+pause loop period at this anchor, milliseconds.
  final double cycleMs;

  /// Duty cycle at this anchor, percent (0..100). 100 = continuous tone.
  final double dutyPct;

  const VarioSoundAnchor({
    required this.lift,
    required this.freqHz,
    required this.cycleMs,
    required this.dutyPct,
  });

  VarioSoundAnchor copyWith({
    double? lift,
    double? freqHz,
    double? cycleMs,
    double? dutyPct,
  }) {
    return VarioSoundAnchor(
      lift: lift ?? this.lift,
      freqHz: freqHz ?? this.freqHz,
      cycleMs: cycleMs ?? this.cycleMs,
      dutyPct: dutyPct ?? this.dutyPct,
    );
  }
}

/// A sampled synthesis point produced by [VarioSoundCurve.sampleAt].
class VarioSoundPoint {
  /// Interpolated tone frequency, Hz.
  final double freqHz;

  /// Interpolated full cycle period, seconds.
  final double cycleSeconds;

  /// Interpolated duty cycle, fraction 0..1.
  final double duty;

  const VarioSoundPoint({
    required this.freqHz,
    required this.cycleSeconds,
    required this.duty,
  });

  /// Whether this point should be rendered as a continuous tone (duty >= 100%)
  /// rather than an intermittent beep.
  bool get isContinuous => duty >= 1.0;

  /// Audible tone length within the cycle, seconds (cycle * duty).
  double get toneSeconds => cycleSeconds * duty;

  /// Silent gap after the tone within the cycle, seconds.
  double get gapSeconds => math.max(0.0, cycleSeconds - toneSeconds);
}

/// A piecewise-linear vario sound curve defined by [anchors] (sorted by lift).
class VarioSoundCurve {
  /// Anchor points, ascending by [VarioSoundAnchor.lift]. Must be non-empty.
  final List<VarioSoundAnchor> anchors;

  const VarioSoundCurve._(this.anchors);

  /// Builds a curve from [anchors], sorting them ascending by lift.
  factory VarioSoundCurve(List<VarioSoundAnchor> anchors) {
    if (anchors.isEmpty) {
      throw ArgumentError.value(anchors, 'anchors', 'must not be empty');
    }
    if (anchors.length > 128) {
      throw ArgumentError.value(anchors.length, 'anchors', 'too many anchors');
    }
    for (final anchor in anchors) {
      if (!_isFinite(anchor.lift) ||
          !_isFinite(anchor.freqHz) ||
          !_isFinite(anchor.cycleMs) ||
          !_isFinite(anchor.dutyPct)) {
        throw ArgumentError.value(anchor, 'anchors', 'values must be finite');
      }
      if (anchor.freqHz <= 0 || anchor.cycleMs <= 0) {
        throw ArgumentError.value(
          anchor,
          'anchors',
          'frequency and cycle must be positive',
        );
      }
      if (anchor.dutyPct < 0 || anchor.dutyPct > 100) {
        throw ArgumentError.value(
          anchor,
          'anchors',
          'duty must be between 0 and 100',
        );
      }
    }
    final sorted = [...anchors]..sort((a, b) => a.lift.compareTo(b.lift));
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].lift == sorted[i - 1].lift) {
        throw ArgumentError.value(
          sorted[i].lift,
          'anchors',
          'lift values must be unique',
        );
      }
    }
    return VarioSoundCurve._(List.unmodifiable(sorted));
  }

  static bool _isFinite(double value) => value.isFinite;

  /// XCTrack-style default 12-anchor curve.
  ///
  /// (lift m/s, freq Hz, cycle ms, duty %):
  ///   -10  200 200 100 | -3 293 200 100 | -2 369 200 100 | -1 440 200 100
  ///   -0.5 475 600 100 |  0 493 600  50 | +0.5 550 550 50 | +1 595 500 50
  ///   +2   675 400  50 | +3 745 310  50 | +5 880 250 50 | +10 1108 200 50
  static const VarioSoundCurve defaultCurve = VarioSoundCurve._([
    VarioSoundAnchor(
      lift: -10.0,
      freqHz: 200.0,
      cycleMs: 200.0,
      dutyPct: 100.0,
    ),
    VarioSoundAnchor(lift: -3.0, freqHz: 293.0, cycleMs: 200.0, dutyPct: 100.0),
    VarioSoundAnchor(lift: -2.0, freqHz: 369.0, cycleMs: 200.0, dutyPct: 100.0),
    VarioSoundAnchor(lift: -1.0, freqHz: 440.0, cycleMs: 200.0, dutyPct: 100.0),
    VarioSoundAnchor(lift: -0.5, freqHz: 475.0, cycleMs: 600.0, dutyPct: 100.0),
    VarioSoundAnchor(lift: 0.0, freqHz: 493.0, cycleMs: 600.0, dutyPct: 50.0),
    VarioSoundAnchor(lift: 0.5, freqHz: 550.0, cycleMs: 550.0, dutyPct: 50.0),
    VarioSoundAnchor(lift: 1.0, freqHz: 595.0, cycleMs: 500.0, dutyPct: 50.0),
    VarioSoundAnchor(lift: 2.0, freqHz: 675.0, cycleMs: 400.0, dutyPct: 50.0),
    VarioSoundAnchor(lift: 3.0, freqHz: 745.0, cycleMs: 310.0, dutyPct: 50.0),
    VarioSoundAnchor(lift: 5.0, freqHz: 880.0, cycleMs: 250.0, dutyPct: 50.0),
    VarioSoundAnchor(lift: 10.0, freqHz: 1108.0, cycleMs: 200.0, dutyPct: 50.0),
  ]);

  /// Samples the curve at vertical [speed] (m/s), linearly interpolating
  /// frequency, cycle and duty between surrounding anchors. Values outside
  /// the range use the first or last segment for linear extrapolation.
  VarioSoundPoint sampleAt(double speed) {
    if (!speed.isFinite) {
      throw ArgumentError.value(speed, 'speed', 'must be finite');
    }
    if (anchors.length == 1) return _pointOf(anchors.single);

    var index = 0;
    if (speed < anchors.first.lift) {
      index = 0;
    } else if (speed > anchors.last.lift) {
      index = anchors.length - 2;
    } else {
      for (var i = 0; i < anchors.length - 1; i++) {
        if (speed <= anchors[i + 1].lift) {
          index = i;
          break;
        }
      }
    }

    final a = anchors[index];
    final b = anchors[index + 1];
    final t = (speed - a.lift) / (b.lift - a.lift);
    final freq = _lerp(a.freqHz, b.freqHz, t);
    final cycleMs = _lerp(a.cycleMs, b.cycleMs, t);
    final duty = _lerp(a.dutyPct, b.dutyPct, t);
    return VarioSoundPoint(
      freqHz: math.max(1.0, freq),
      cycleSeconds: math.max(0.001, cycleMs / 1000.0),
      duty: (duty / 100.0).clamp(0.0, 1.0),
    );
  }

  VarioSoundPoint _pointOf(VarioSoundAnchor a) => VarioSoundPoint(
    freqHz: a.freqHz,
    cycleSeconds: a.cycleMs / 1000.0,
    duty: (a.dutyPct / 100.0).clamp(0.0, 1.0),
  );

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
