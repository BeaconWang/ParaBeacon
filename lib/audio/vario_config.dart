// ignore_for_file: constant_identifier_names
//
// vario_config.dart
// -----------------------------------------------------------------------------
// XCTrack-style Vario audio parameter configuration.
//
// Everything the [VarioAudioService] needs to shape its sound lives here, so
// the DSP/streaming code stays generic and every "sound profile" (aggressive,
// mellow, custom user profile, ...) is just a different [VarioAudioConfig].
//
// All fields are immutable and `copyWith`-able so the settings UI can build a
// new profile from an old one without touching the synthesis engine.
// -----------------------------------------------------------------------------

import 'dart:math' as math;

/// PCM waveform used by a tone.
enum VarioWaveform {
  /// Classic 8-bit buzzer. Used for the climb beeps.
  square,

  /// Smooth continuous tone. Used for the sink alarm.
  sine,
}

/// A single calibration point on the vario curve.
///
/// At vertical speed [speed] (m/s) the tone should have pitch [frequency] (Hz)
/// and, for intermittent climb tones, repeat at [beepRate] (Hz, beeps/sec).
/// [beepRate] is ignored for continuous tones (e.g. the sink alarm).
class VarioCurvePoint {
  /// Vertical speed at this calibration point, m/s.
  final double speed;

  /// Tone pitch at this point, Hz.
  final double frequency;

  /// Beep repetition rate at this point, Hz (beeps per second).
  /// Unused for continuous tones.
  final double beepRate;

  const VarioCurvePoint({
    required this.speed,
    required this.frequency,
    this.beepRate = 0.0,
  });
}

/// How the engine interpolates between [VarioCurvePoint]s.
enum VarioInterpolation {
  /// Straight line between neighbouring points.
  linear,

  /// Interpolate in log-frequency space (musically/perceptually smoother).
  /// Recommended for pitch: keeps low-speed sensitivity while staying stable
  /// at high speed, matching XCTrack's feel.
  exponential,
}

/// Complete, immutable XCTrack-style vario sound profile.
class VarioAudioConfig {
  // ---------------------------------------------------------------------------
  // Audio stream format
  // ---------------------------------------------------------------------------

  /// PCM sample rate in Hz. 44100 is universally supported and low-latency.
  final int sampleRate;

  /// Bits per sample. The engine emits signed 16-bit little-endian PCM.
  final int bitsPerSample;

  /// Number of channels (1 = mono; a vario has no reason to be stereo).
  final int channels;

  // ---------------------------------------------------------------------------
  // State thresholds (m/s)
  // ---------------------------------------------------------------------------

  /// At/above this climb rate the climb beeper is active.
  /// (XCTrack default: +0.1 m/s.)
  final double climbThreshold;

  /// At/below this sink rate the sink alarm is active.
  /// (XCTrack default: -1.5 m/s.)
  final double sinkThreshold;

  /// The dead-band is the (silent) interval `[sinkThreshold, climbThreshold]`.

  // ---------------------------------------------------------------------------
  // Climb tone
  // ---------------------------------------------------------------------------

  /// Climb waveform (classic square-wave buzzer).
  final VarioWaveform climbWaveform;

  /// Fraction of each beep period that is audible (rest is silence).
  /// XCTrack climb duty cycle is ~0.45.
  final double climbDutyCycle;

  /// Ordered (ascending speed) climb calibration points: pitch + beep-rate.
  final List<VarioCurvePoint> climbCurve;

  /// One-pole low-pass smoothing applied to the square wave, 0..1.
  /// 0 = raw square (harsh), higher = rounder/softer ("slight low-pass").
  final double climbLowPass;

  // ---------------------------------------------------------------------------
  // Sink tone
  // ---------------------------------------------------------------------------

  /// Sink waveform (deep continuous sine).
  final VarioWaveform sinkWaveform;

  /// Ordered (by speed, most-negative first) sink calibration points.
  /// Only [VarioCurvePoint.frequency] is used (continuous tone).
  final List<VarioCurvePoint> sinkCurve;

  // ---------------------------------------------------------------------------
  // Interpolation / envelope / mix
  // ---------------------------------------------------------------------------

  /// How pitch is interpolated across the curve.
  final VarioInterpolation pitchInterpolation;

  /// How beep-rate is interpolated across the curve.
  final VarioInterpolation rateInterpolation;

  /// Fade in/out ramp length in milliseconds applied to every beep edge and to
  /// pitch/state transitions. 5-10 ms removes clicks/pops entirely.
  final double fadeMs;

  /// Master output gain, 0..1. Combined with the runtime volume/mute.
  final double masterGain;

  const VarioAudioConfig({
    this.sampleRate = 44100,
    this.bitsPerSample = 16,
    this.channels = 1,
    this.climbThreshold = 0.1,
    this.sinkThreshold = -1.5,
    this.climbWaveform = VarioWaveform.square,
    this.climbDutyCycle = 0.45,
    this.climbLowPass = 0.15,
    this.sinkWaveform = VarioWaveform.sine,
    this.pitchInterpolation = VarioInterpolation.exponential,
    this.rateInterpolation = VarioInterpolation.linear,
    this.fadeMs = 7.0,
    this.masterGain = 0.85,
    this.climbCurve = const [
      VarioCurvePoint(speed: 0.1, frequency: 600, beepRate: 2.0),
      VarioCurvePoint(speed: 1.0, frequency: 900, beepRate: 3.5),
      VarioCurvePoint(speed: 3.0, frequency: 1500, beepRate: 6.5),
      VarioCurvePoint(speed: 6.0, frequency: 2200, beepRate: 10.0),
    ],
    this.sinkCurve = const [
      VarioCurvePoint(speed: -1.5, frequency: 400),
      VarioCurvePoint(speed: -5.0, frequency: 150),
    ],
  });

  /// The XCTrack-matching default profile.
  static const VarioAudioConfig xcTrack = VarioAudioConfig();

  VarioAudioConfig copyWith({
    int? sampleRate,
    int? bitsPerSample,
    int? channels,
    double? climbThreshold,
    double? sinkThreshold,
    VarioWaveform? climbWaveform,
    double? climbDutyCycle,
    double? climbLowPass,
    List<VarioCurvePoint>? climbCurve,
    VarioWaveform? sinkWaveform,
    List<VarioCurvePoint>? sinkCurve,
    VarioInterpolation? pitchInterpolation,
    VarioInterpolation? rateInterpolation,
    double? fadeMs,
    double? masterGain,
  }) {
    return VarioAudioConfig(
      sampleRate: sampleRate ?? this.sampleRate,
      bitsPerSample: bitsPerSample ?? this.bitsPerSample,
      channels: channels ?? this.channels,
      climbThreshold: climbThreshold ?? this.climbThreshold,
      sinkThreshold: sinkThreshold ?? this.sinkThreshold,
      climbWaveform: climbWaveform ?? this.climbWaveform,
      climbDutyCycle: climbDutyCycle ?? this.climbDutyCycle,
      climbLowPass: climbLowPass ?? this.climbLowPass,
      climbCurve: climbCurve ?? this.climbCurve,
      sinkWaveform: sinkWaveform ?? this.sinkWaveform,
      sinkCurve: sinkCurve ?? this.sinkCurve,
      pitchInterpolation: pitchInterpolation ?? this.pitchInterpolation,
      rateInterpolation: rateInterpolation ?? this.rateInterpolation,
      fadeMs: fadeMs ?? this.fadeMs,
      masterGain: masterGain ?? this.masterGain,
    );
  }

  // ---------------------------------------------------------------------------
  // Curve evaluation helpers
  //
  // These are pure functions of the config so they can be unit-tested and also
  // reused by any UI that wants to preview "what pitch/rate at speed X".
  // ---------------------------------------------------------------------------

  /// Interpolated climb pitch (Hz) for a positive [speed] using [climbCurve].
  double climbFrequencyFor(double speed) =>
      _interpolate(climbCurve, speed, _Field.frequency, pitchInterpolation);

  /// Interpolated climb beep-rate (Hz) for a positive [speed].
  double climbBeepRateFor(double speed) =>
      _interpolate(climbCurve, speed, _Field.beepRate, rateInterpolation);

  /// Interpolated sink pitch (Hz) for a negative [speed] using [sinkCurve].
  double sinkFrequencyFor(double speed) =>
      _interpolate(sinkCurve, speed, _Field.frequency, pitchInterpolation);

  /// Generic piecewise interpolation with clamping outside the table range.
  ///
  /// The curve must be sorted by ascending [VarioCurvePoint.speed].
  static double _interpolate(
    List<VarioCurvePoint> curve,
    double speed,
    _Field field,
    VarioInterpolation mode,
  ) {
    if (curve.isEmpty) return 0.0;
    if (curve.length == 1) return _valueOf(curve.first, field);

    // Clamp below/above the defined range (flat extrapolation).
    if (speed <= curve.first.speed) return _valueOf(curve.first, field);
    if (speed >= curve.last.speed) return _valueOf(curve.last, field);

    // Find the bracketing segment.
    for (var i = 0; i < curve.length - 1; i++) {
      final a = curve[i];
      final b = curve[i + 1];
      if (speed >= a.speed && speed <= b.speed) {
        final span = b.speed - a.speed;
        final t = span == 0 ? 0.0 : (speed - a.speed) / span;
        final va = _valueOf(a, field);
        final vb = _valueOf(b, field);
        switch (mode) {
          case VarioInterpolation.linear:
            return va + (vb - va) * t;
          case VarioInterpolation.exponential:
            // Interpolate in log space; falls back to linear if a value is
            // non-positive (log undefined).
            if (va <= 0 || vb <= 0) return va + (vb - va) * t;
            return math.exp(math.log(va) + (math.log(vb) - math.log(va)) * t);
        }
      }
    }
    return _valueOf(curve.last, field);
  }

  static double _valueOf(VarioCurvePoint p, _Field field) {
    switch (field) {
      case _Field.frequency:
        return p.frequency;
      case _Field.beepRate:
        return p.beepRate;
    }
  }
}

enum _Field { frequency, beepRate }
