// vario_keypoints.dart
// -----------------------------------------------------------------------------
// User-defined vertical-speed keypoints for the vario beeper.
//
// A keypoint pins a custom sound (pitch, beep cycle, duty and waveform) to a
// specific vertical speed (m/s). The synth linearly interpolates the numeric
// parameters between adjacent keypoints and uses the lower keypoint's waveform
// for the segment. Speeds outside the keypoint range fall back to the classic
// XCTrack formula (see `VarioAudioConfig` / `_VarioSynth`).
// -----------------------------------------------------------------------------

import 'vario_config.dart';

/// A single user keypoint: a custom sound pinned to a vertical speed.
class VarioKeypoint {
  const VarioKeypoint({
    required this.speed,
    required this.freqHz,
    required this.cycleSeconds,
    required this.duty,
    required this.waveform,
  });

  /// Vertical speed this keypoint applies to, m/s (positive = lift).
  final double speed;

  /// Beep pitch at this speed, Hz.
  final double freqHz;

  /// Beep repetition period (audible tone + trailing gap), seconds.
  final double cycleSeconds;

  /// Fraction of [cycleSeconds] that is audible tone, 0..1. `1.0` == a
  /// continuous tone (no gap).
  final double duty;

  /// Waveform used for the beep at this speed.
  final VarioWaveform waveform;

  VarioKeypoint copyWith({
    double? speed,
    double? freqHz,
    double? cycleSeconds,
    double? duty,
    VarioWaveform? waveform,
  }) {
    return VarioKeypoint(
      speed: speed ?? this.speed,
      freqHz: freqHz ?? this.freqHz,
      cycleSeconds: cycleSeconds ?? this.cycleSeconds,
      duty: duty ?? this.duty,
      waveform: waveform ?? this.waveform,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VarioKeypoint &&
      other.speed == speed &&
      other.freqHz == freqHz &&
      other.cycleSeconds == cycleSeconds &&
      other.duty == duty &&
      other.waveform == waveform;

  @override
  int get hashCode =>
      Object.hash(speed, freqHz, cycleSeconds, duty, waveform);
}

/// The interpolated sound parameters sampled from a [VarioKeypointCurve] at a
/// given vertical speed.
class VarioKeypointSample {
  const VarioKeypointSample({
    required this.freqHz,
    required this.cycleSeconds,
    required this.duty,
    required this.waveform,
  });

  final double freqHz;
  final double cycleSeconds;
  final double duty;
  final VarioWaveform waveform;

  /// A duty of 1.0 (or above) means a continuous tone with no gap.
  bool get isContinuous => duty >= 1.0;

  /// Audible tone portion of the cycle, seconds.
  double get toneSeconds => cycleSeconds * duty.clamp(0.0, 1.0);

  /// Silent gap portion of the cycle, seconds.
  double get gapSeconds => cycleSeconds * (1.0 - duty.clamp(0.0, 1.0));
}

/// An ordered set of [VarioKeypoint]s, sorted ascending by speed.
///
/// Construct via [VarioKeypointCurve.sorted] (which sorts + de-duplicates by
/// speed) so [sampleAt] can assume ascending order.
class VarioKeypointCurve {
  /// Low-level constructor. [anchors] MUST already be sorted ascending by
  /// speed with no duplicate speeds. Prefer [VarioKeypointCurve.sorted].
  const VarioKeypointCurve(this.anchors);

  /// Builds a curve from an arbitrary list: sorts ascending by speed and keeps
  /// the last keypoint when two share the (rounded) same speed.
  factory VarioKeypointCurve.sorted(Iterable<VarioKeypoint> input) {
    final byKey = <int, VarioKeypoint>{};
    for (final kp in input) {
      byKey[_speedKey(kp.speed)] = kp;
    }
    final list = byKey.values.toList()
      ..sort((a, b) => a.speed.compareTo(b.speed));
    return VarioKeypointCurve(List.unmodifiable(list));
  }

  /// Shared empty curve (classic engine everywhere).
  static const VarioKeypointCurve empty = VarioKeypointCurve(
    <VarioKeypoint>[],
  );

  final List<VarioKeypoint> anchors;

  bool get isEmpty => anchors.isEmpty;
  bool get isNotEmpty => anchors.isNotEmpty;
  int get length => anchors.length;

  /// Discretises a speed to a 0.1 m/s bucket so near-identical speeds collapse
  /// onto a single keypoint.
  static int _speedKey(double speed) => (speed * 10).round();

  /// Whether [speed] lies within the covered range (so the keypoint curve —
  /// not the classic formula — should drive the sound). Requires at least two
  /// keypoints to form a usable range.
  bool covers(double speed) {
    if (anchors.length < 2) return false;
    return speed >= anchors.first.speed && speed <= anchors.last.speed;
  }

  /// Returns a copy with [kp] inserted (or replacing an existing keypoint at
  /// the same rounded speed), kept sorted.
  VarioKeypointCurve upsert(VarioKeypoint kp) =>
      VarioKeypointCurve.sorted([...anchors, kp]);

  /// Returns a copy with any keypoint at [speed]'s rounded bucket removed.
  VarioKeypointCurve removeAt(double speed) {
    final key = _speedKey(speed);
    return VarioKeypointCurve(
      List.unmodifiable(
        anchors.where((a) => _speedKey(a.speed) != key),
      ),
    );
  }

  /// Linearly interpolates the sound parameters at [speed]. Numeric fields are
  /// lerped between the two bracketing keypoints; the (categorical) waveform is
  /// taken from the lower keypoint of the segment. Clamps to the end keypoints
  /// outside the covered range.
  VarioKeypointSample sampleAt(double speed) {
    assert(anchors.isNotEmpty, 'sampleAt on an empty curve');
    if (speed <= anchors.first.speed) return _sampleOf(anchors.first);
    if (speed >= anchors.last.speed) return _sampleOf(anchors.last);
    for (var i = 0; i < anchors.length - 1; i++) {
      final a = anchors[i];
      final b = anchors[i + 1];
      if (speed >= a.speed && speed <= b.speed) {
        final span = b.speed - a.speed;
        final t = span <= 0 ? 0.0 : (speed - a.speed) / span;
        return VarioKeypointSample(
          freqHz: _lerp(a.freqHz, b.freqHz, t),
          cycleSeconds: _lerp(a.cycleSeconds, b.cycleSeconds, t),
          duty: _lerp(a.duty, b.duty, t),
          waveform: a.waveform,
        );
      }
    }
    return _sampleOf(anchors.last);
  }

  static VarioKeypointSample _sampleOf(VarioKeypoint kp) => VarioKeypointSample(
    freqHz: kp.freqHz,
    cycleSeconds: kp.cycleSeconds,
    duty: kp.duty,
    waveform: kp.waveform,
  );

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) {
    if (other is! VarioKeypointCurve) return false;
    if (other.anchors.length != anchors.length) return false;
    for (var i = 0; i < anchors.length; i++) {
      if (other.anchors[i] != anchors[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(anchors);
}
