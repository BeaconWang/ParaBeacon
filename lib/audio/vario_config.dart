// ignore_for_file: constant_identifier_names
//
// vario_config.dart
// -----------------------------------------------------------------------------
// XCTrack-ACCURATE Vario audio parameter configuration.
//
// These values were reverse-engineered from XCTrack's decompiled native sound
// engine (org.xcontest.XCTrack.info.e1 / c1 / u7 and the mapping in
// com.android.billingclient.api.t#a). They are reproduced here so our Dart
// synth is bit-for-behaviour compatible with the original beeper.
//
// Key facts recovered from the APK:
//   * AudioTrack: sampleRate = 22050 Hz, MONO, ENCODING_PCM_16BIT, MODE_STREAM,
//     usage = USAGE_ASSISTANCE_SONIFICATION, buffer = getMinBufferSize() (raw).
//   * Oscillator u7.a(x) is a TRIANGLE wave (period 1.0, phase-shifted +0.25),
//     amplitude -1..+1 — NOT a sine or a square.
//   * Waveforms (enum b1): TICK, TACK, SQUARE, LONG. TACK is the normal climb
//     beep; it is a triangle at 20000 amplitude plus a 15000 square component.
//   * Pitch within a beep can GLIDE exponentially from f0 -> f1 over the beep;
//     the phase is the analytic integral of the instantaneous frequency so the
//     waveform is perfectly phase-continuous (no clicks).
//   * Climb: freq = 660 + (v/8)*660 ; beep period = 1/(3*(v/8)+2) - 0.1 (s).
//   * Sink : freq = 660 / 2^(floor(2*|v|)/12) ; long descending tone.
//   * Envelope: 5% fade-in + 5% fade-out via an exponential ramp (skipped for
//     the LONG waveform).
//
// All fields are immutable + copyWith-able so a settings screen can build
// custom "sound profiles" without touching the synthesis engine.
// -----------------------------------------------------------------------------

import 'dart:math' as math;

/// XCTrack waveform families (enum `b1` in the APK).
enum VarioWaveform {
  /// TICK — rich additive blend (used by some weak-lift profiles).
  tick,

  /// TACK — the normal climb beep: triangle + square component.
  tack,

  /// SQUARE — triangle + square (brighter).
  square,

  /// LONG — pure triangle, no envelope (used for the continuous sink tone).
  long,
}

/// Complete, immutable XCTrack-style vario sound profile.
class VarioAudioConfig {
  // ---------------------------------------------------------------------------
  // Audio stream format — matches XCTrack's AudioTrack exactly.
  // ---------------------------------------------------------------------------

  /// PCM sample rate in Hz. XCTrack uses 22050 (half of CD rate) — plenty for a
  /// <=2.2 kHz beeper and it halves the per-sample cost + buffer latency.
  final int sampleRate;

  /// Bits per sample. Engine emits signed 16-bit little-endian PCM.
  final int bitsPerSample;

  /// Channels (1 = mono; XCTrack is mono).
  final int channels;

  // ---------------------------------------------------------------------------
  // Latency / buffering
  // ---------------------------------------------------------------------------

  /// Hardware period / render granularity, in milliseconds. Larger => fewer,
  /// bigger writes => far more robust against Dart UI-isolate timer jitter
  /// (which is what causes underrun crackle). 20 ms is a good balance.
  final double chunkMs;

  /// How much audio we keep queued ahead of the play head (ms). This is the
  /// dominant contributor to output latency, BUT it is also the buffer that
  /// absorbs GC pauses / layout / setState stalls on the UI isolate. Too small
  /// (<40 ms) causes static & stuttering; ~80-100 ms is smooth while still
  /// low-latency enough for a vario.
  final double lookAheadMs;

  // ---------------------------------------------------------------------------
  // State thresholds (m/s) — XCTrack defaults (t0.x1 / t0.y1 config keys).
  // ---------------------------------------------------------------------------

  /// At/above this climb rate the climb beeper is active (XCTrack `f26099c`,
  /// default +0.2 m/s).
  final double climbThreshold;

  /// At/below this sink rate the sink alarm is active (XCTrack `f26100d`,
  /// default -2.0 m/s; note XCTrack stores it negated).
  final double sinkThreshold;

  // ---------------------------------------------------------------------------
  // Deadband cue — double-beep pattern played between sink and climb thresholds.
  // ---------------------------------------------------------------------------

  /// Whether the deadband double-beep cue is enabled. When true it plays for
  /// `sinkThreshold < v < climbThreshold` (i.e. the whole deadband, when there
  /// is neither a climb beep nor a sink alarm). Set false to keep the deadband
  /// silent.
  final bool nearLiftEnabled;

  /// Audible duration of each deadband beep, seconds.
  final double nearLiftToneSeconds;

  /// Silent gap between the two beeps of a pair, seconds.
  final double nearLiftBeepGapSeconds;

  /// Silent pause after a pair, before the next pair, seconds (the "[0.5s]").
  final double nearLiftPairPauseSeconds;

  /// Waveform for the deadband beeps.
  final VarioWaveform nearLiftWaveform;

  // ---------------------------------------------------------------------------
  // Climb tone (from t#a, iOrdinal == climb branch)
  // ---------------------------------------------------------------------------

  /// Base pitch at zero climb, Hz (XCTrack constant 660).
  final double climbBaseFreq;

  /// Pitch gain: freq = climbBaseFreq + (v / climbSpeedRef) * climbFreqSpan.
  final double climbFreqSpan; // 660 in XCTrack
  final double climbSpeedRef; // 8.0 m/s normaliser in XCTrack

  /// Beep cadence: period = 1/(cadenceA*(v/climbSpeedRef)+cadenceB) - cadenceC.
  /// XCTrack: cadenceA=3, cadenceB=2, cadenceC=0.1.
  final double cadenceA;
  final double cadenceB;
  final double cadenceC;

  /// Duration of the audible tone portion of each climb beep, seconds
  /// (XCTrack passes 0.1 s as the `w` command length; the remainder of the
  /// period is silence `h0`).
  final double climbToneSeconds;

  /// Waveform used for the climb beep.
  final VarioWaveform climbWaveform;

  // ---------------------------------------------------------------------------
  // Sink tone (from t#a, sink branch)
  // ---------------------------------------------------------------------------

  /// Base pitch for sink, Hz (660 in XCTrack).
  final double sinkBaseFreq;

  /// Semitone step model: freq = sinkBaseFreq / 2^(floor(2*|v|)/12).
  /// XCTrack uses 2 steps per m/s, 12 semitones/octave.
  final double sinkStepsPerMs; // 2.0
  final double sinkSemitonesPerOctave; // 12.0

  /// Sink beep cadence: like XCTrack, the sink alarm is a repeating tick rather
  /// than a continuous tone. One tick fires every [sinkPeriodSeconds] (1 s).
  final double sinkPeriodSeconds;

  /// Duration of the audible tone portion of each sink tick, seconds. The
  /// remainder of [sinkPeriodSeconds] is silence. Within the tone the pitch
  /// glides from the sink *start* frequency ([sinkBaseFreq]) down to the pitch
  /// for the current sink rate ([sinkFrequencyFor]).
  final double sinkToneSeconds;

  /// Waveform for the sink tone (LONG = pure triangle, no envelope).
  final VarioWaveform sinkWaveform;

  // ---------------------------------------------------------------------------
  // Envelope / mix
  // ---------------------------------------------------------------------------

  /// Fraction of each toned segment used for fade-in and (again) fade-out.
  /// XCTrack uses 0.05 (5%) at each edge.
  final double fadeFraction;

  /// Master output gain, 0..1. Combined with runtime volume/mute.
  final double masterGain;

  const VarioAudioConfig({
    this.sampleRate = 22050,
    this.bitsPerSample = 16,
    this.channels = 1,
    this.chunkMs = 20.0,
    this.lookAheadMs = 90.0,
    this.climbThreshold = 0.2,
    this.sinkThreshold = -2.0,
    this.nearLiftEnabled = true,
    this.nearLiftToneSeconds = 0.2,
    this.nearLiftBeepGapSeconds = 0.08,
    this.nearLiftPairPauseSeconds = 0.5,
    this.nearLiftWaveform = VarioWaveform.tack,
    this.climbBaseFreq = 660.0,
    this.climbFreqSpan = 660.0,
    this.climbSpeedRef = 8.0,
    this.cadenceA = 3.0,
    this.cadenceB = 2.0,
    this.cadenceC = 0.1,
    this.climbToneSeconds = 0.1,
    this.climbWaveform = VarioWaveform.tack,
    this.sinkBaseFreq = 660.0,
    this.sinkStepsPerMs = 2.0,
    this.sinkSemitonesPerOctave = 12.0,
    this.sinkPeriodSeconds = 1.0,
    this.sinkToneSeconds = 0.5,
    this.sinkWaveform = VarioWaveform.long,
    this.fadeFraction = 0.05,
    this.masterGain = 0.9,
  });

  /// The XCTrack-matching default profile.
  static const VarioAudioConfig xcTrack = VarioAudioConfig();

  VarioAudioConfig copyWith({
    int? sampleRate,
    int? bitsPerSample,
    int? channels,
    double? chunkMs,
    double? lookAheadMs,
    double? climbThreshold,
    double? sinkThreshold,
    bool? nearLiftEnabled,
    double? nearLiftToneSeconds,
    double? nearLiftBeepGapSeconds,
    double? nearLiftPairPauseSeconds,
    VarioWaveform? nearLiftWaveform,
    double? climbBaseFreq,
    double? climbFreqSpan,
    double? climbSpeedRef,
    double? cadenceA,
    double? cadenceB,
    double? cadenceC,
    double? climbToneSeconds,
    VarioWaveform? climbWaveform,
    double? sinkBaseFreq,
    double? sinkStepsPerMs,
    double? sinkSemitonesPerOctave,
    double? sinkPeriodSeconds,
    double? sinkToneSeconds,
    VarioWaveform? sinkWaveform,
    double? fadeFraction,
    double? masterGain,
  }) {
    return VarioAudioConfig(
      sampleRate: sampleRate ?? this.sampleRate,
      bitsPerSample: bitsPerSample ?? this.bitsPerSample,
      channels: channels ?? this.channels,
      chunkMs: chunkMs ?? this.chunkMs,
      lookAheadMs: lookAheadMs ?? this.lookAheadMs,
      climbThreshold: climbThreshold ?? this.climbThreshold,
      sinkThreshold: sinkThreshold ?? this.sinkThreshold,
      nearLiftEnabled: nearLiftEnabled ?? this.nearLiftEnabled,
      nearLiftToneSeconds: nearLiftToneSeconds ?? this.nearLiftToneSeconds,
      nearLiftBeepGapSeconds:
          nearLiftBeepGapSeconds ?? this.nearLiftBeepGapSeconds,
      nearLiftPairPauseSeconds:
          nearLiftPairPauseSeconds ?? this.nearLiftPairPauseSeconds,
      nearLiftWaveform: nearLiftWaveform ?? this.nearLiftWaveform,
      climbBaseFreq: climbBaseFreq ?? this.climbBaseFreq,
      climbFreqSpan: climbFreqSpan ?? this.climbFreqSpan,
      climbSpeedRef: climbSpeedRef ?? this.climbSpeedRef,
      cadenceA: cadenceA ?? this.cadenceA,
      cadenceB: cadenceB ?? this.cadenceB,
      cadenceC: cadenceC ?? this.cadenceC,
      climbToneSeconds: climbToneSeconds ?? this.climbToneSeconds,
      climbWaveform: climbWaveform ?? this.climbWaveform,
      sinkBaseFreq: sinkBaseFreq ?? this.sinkBaseFreq,
      sinkStepsPerMs: sinkStepsPerMs ?? this.sinkStepsPerMs,
      sinkSemitonesPerOctave:
          sinkSemitonesPerOctave ?? this.sinkSemitonesPerOctave,
      sinkPeriodSeconds: sinkPeriodSeconds ?? this.sinkPeriodSeconds,
      sinkToneSeconds: sinkToneSeconds ?? this.sinkToneSeconds,
      sinkWaveform: sinkWaveform ?? this.sinkWaveform,
      fadeFraction: fadeFraction ?? this.fadeFraction,
      masterGain: masterGain ?? this.masterGain,
    );
  }

  // ---------------------------------------------------------------------------
  // XCTrack pitch/cadence math (pure functions of the config, unit-testable).
  // ---------------------------------------------------------------------------

  /// Climb pitch (Hz) for a positive [speed]. Mirrors `t#a`:
  ///   d12 = v/8 ;  f = 660 + d12*660.
  double climbFrequencyFor(double speed) {
    final norm = speed / climbSpeedRef;
    return climbBaseFreq + norm * climbFreqSpan;
  }

  /// Total beep period (tone + trailing silence) for a positive [speed], s.
  /// Mirrors `t#a`:  period = 1/(3*(v/8)+2) - 0.1  (clamped to be > tone).
  double climbPeriodFor(double speed) {
    final norm = speed / climbSpeedRef;
    final p = (1.0 / (cadenceA * norm + cadenceB)) - cadenceC;
    // The audible tone is climbToneSeconds; ensure at least a tiny gap.
    return math.max(p, climbToneSeconds + 0.005);
  }

  /// Beep repetition rate (Hz) for a positive [speed] — convenience/telemetry.
  double climbBeepRateFor(double speed) => 1.0 / climbPeriodFor(speed);

  /// Sink pitch (Hz) for a negative [speed]. Mirrors `t#a`:
  ///   f = 660 / 2^(floor(2*|v|)/12).
  double sinkFrequencyFor(double speed) {
    final mag = -speed;
    final steps = (mag * sinkStepsPerMs).floorToDouble();
    return sinkBaseFreq / math.pow(2.0, steps / sinkSemitonesPerOctave);
  }
}
