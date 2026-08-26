// vario_audio_service.dart
// -----------------------------------------------------------------------------
// Near-zero-latency, XCTrack-faithful real-time Vario audio engine.
//
// Rewritten after analysing XCTrack's decompiled native sound engine
// (org.xcontest.XCTrack.info.e1 / c1 / u7). It reproduces XCTrack's behaviour:
//   * 22050 Hz mono 16-bit PCM (see VarioAudioConfig).
//   * Triangle oscillator u7.a(x) and its TICK/TACK/SQUARE/LONG blends.
//   * Phase-continuous EXPONENTIAL pitch glide inside a beep (phase = analytic
//     integral of instantaneous frequency) -> zero clicks on pitch change.
//   * 5%/5% exponential fade envelope on toned segments (skipped for LONG).
//   * Climb cadence + pitch and sink pitch formulas copied verbatim.
//
// LATENCY STRATEGY (goal < 20 ms):
//   XCTrack uses a blocking AudioTrack.write() loop at getMinBufferSize() with
//   usage=USAGE_ASSISTANCE_SONIFICATION (fast mixer path). We reproduce that
//   model with a PULL-friendly engine: a small hardware buffer + a lock-free
//   Int16 FIFO. A timer keeps the FIFO topped up to a tiny target latency
//   (VarioAudioConfig.lookAheadMs). The FIFO provides natural back-pressure, so
//   there is no unbounded backlog (the cause of earlier "seconds of delay") and
//   no starvation (the cause of earlier silence). End-to-end latency ~=
//   lookAheadMs + device buffer.
//
// -----------------------------------------------------------------------------
// DEPENDENCY (pubspec.yaml, then `flutter pub get`):
//
//   dependencies:
//     flutter_miniaudio:
//       git:
//         url: https://github.com/bill0015/flutter_miniaudio.git
//
// Why flutter_miniaudio?
//   * FFI wrapper around miniaudio: WASAPI (Windows), AAudio (Android),
//     CoreAudio (macOS/iOS), ALSA (Linux) -> genuinely cross-platform incl.
//     Windows (flutter_pcm_sound has no Windows/Linux native code, and the
//     flutter_soloud buffer-stream push API proved fragile / silent for a
//     continuous live synth).
//   * Exposes exactly our model: write(Pointer<Int16> data, int frames) into a
//     lock-free FIFO, with `bufferLatency` (seconds queued) and
//     `fifoAvailableFrames` for precise, non-blocking flow control.
//   * PCM format: interleaved signed 16-bit; write() arg is FRAMES; returns
//     frames actually accepted (respects remaining FIFO space).
//
// This file is written so the ONLY coupling to the plugin lives inside
// `_PcmSink`. Swap that class to change backends; `_VarioSynth` stays identical.
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_miniaudio/flutter_miniaudio.dart';

import 'vario_config.dart';

/// Public, injectable vario audio service.
///
/// ```dart
/// final vario = VarioAudioService();      // or VarioAudioService.instance
/// await vario.init();
/// vario.updateSpeed(flightData.verticalSpeed); // 20-50 Hz, cheap
/// vario.dispose();
/// ```
class VarioAudioService {
  /// Shared singleton for a single global vario.
  static final VarioAudioService instance = VarioAudioService();

  VarioAudioService({VarioAudioConfig config = VarioAudioConfig.xcTrack})
      : _synth = _VarioSynth(config);

  final _VarioSynth _synth;
  final _PcmSink _sink = _PcmSink();

  bool _initialized = false;
  bool _muted = false;
  double _volume = 1.0;

  // Preview takeover. When active, live vertical-speed updates (e.g. from the
  // flight-data bridge) are ignored and the engine is driven by the preview
  // speed instead. Used by the Vario Sound Settings panel so the user can
  // audition a chosen vertical speed without the live sensor feed fighting it.
  bool _previewActive = false;
  double _previewSpeed = 0.0;

  VarioAudioConfig get config => _synth.config;

  /// Whether preview takeover is currently engaged.
  bool get isPreviewActive => _previewActive;

  /// Begins preview takeover: subsequent [updateSpeed] calls from live sources
  /// are ignored and the engine plays [initialSpeed] until [setPreviewSpeed] is
  /// called or [endPreview] releases control back to the live feed.
  void beginPreview([double initialSpeed = 0.0]) {
    _previewActive = true;
    _previewSpeed = initialSpeed;
    _synth.setTargetSpeed(_previewSpeed);
  }

  /// Updates the audition speed while preview takeover is engaged. No-op if
  /// preview is not active.
  void setPreviewSpeed(double verticalSpeed) {
    if (!_previewActive) return;
    if (verticalSpeed.isNaN || verticalSpeed.isInfinite) return;
    _previewSpeed = verticalSpeed;
    _synth.setTargetSpeed(_previewSpeed);
  }

  /// Ends preview takeover and hands control back to the live feed. The engine
  /// is reset to silence until the next live [updateSpeed] arrives.
  void endPreview() {
    if (!_previewActive) return;
    _previewActive = false;
    _synth.setTargetSpeed(0.0);
  }

  /// Replaces the active sound profile at runtime (e.g. from settings UI).
  void setConfig(VarioAudioConfig config) => _synth.config = config;

  /// Initializes the native audio stream. Idempotent.
  Future<void> init() async {
    if (_initialized) return;
    await _sink.open(
      sampleRate: config.sampleRate,
      channels: config.channels,
      chunkMs: config.chunkMs,
      lookAheadMs: config.lookAheadMs,
      onRender: _synth.render,
    );
    _initialized = true;
  }

  /// Core driver. Call at 20-50 Hz with the latest vertical speed (m/s).
  /// Only stores the new target; the waveform is generated in small chunks by
  /// the sink, so this never blocks and never causes clicks.
  ///
  /// While preview takeover is engaged (see [beginPreview]) live updates are
  /// ignored so the settings panel's audition can't be overwritten by the
  /// sensor feed.
  void updateSpeed(double verticalSpeed) {
    if (_previewActive) return;
    if (verticalSpeed.isNaN || verticalSpeed.isInfinite) return;
    _synth.setTargetSpeed(verticalSpeed);
  }

  /// Mute/unmute (gain is ramped, so no click).
  void setMuted(bool isMuted) {
    _muted = isMuted;
    _applyOutputGain();
  }

  /// Output volume, 0..1.
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _applyOutputGain();
  }

  bool get isMuted => _muted;
  double get volume => _volume;

  void _applyOutputGain() => _synth.outputGain = _muted ? 0.0 : _volume;

  /// Releases the native stream and all resources. Idempotent.
  void dispose() {
    if (!_initialized) return;
    _initialized = false;
    _sink.close();
  }
}

// =============================================================================
// DSP CORE — pure, backend-agnostic PCM synthesis (XCTrack-faithful).
// =============================================================================

enum _VarioState { deadband, climb, sink }

/// Real-time synthesizer.
///
/// Runs a continuous "beep cycle" state machine. Within a climb beep it glides
/// pitch exponentially and applies XCTrack's 5% fades; between beeps it emits
/// silence. Sink is a continuous LONG (pure-triangle) tone. A SINGLE phase
/// accumulator is advanced every sample with
/// `phase += frequency / sampleRate` (cycles, not radians) so the waveform is
/// always continuous even when the target speed / pitch changes.
class _VarioSynth {
  _VarioSynth(this._config) {
    _recompute();
  }

  VarioAudioConfig _config;
  VarioAudioConfig get config => _config;
  set config(VarioAudioConfig c) {
    _config = c;
    _recompute();
  }

  // Setpoints written by the sensor thread (store-only; single isolate).
  double _targetSpeed = 0.0;
  double outputGain = 1.0;

  void setTargetSpeed(double v) => _targetSpeed = v;

  // Smoothed / running state.
  double _smoothedSpeed = 0.0;
  double _phase = 0.0; // oscillator phase in CYCLES [0,1)
  double _appliedGain = 0.0;

  // Beep-cycle state machine.
  bool _inTone = false; // currently emitting the toned part of a cycle
  double _segElapsed = 0.0; // seconds elapsed in current segment
  double _segDuration = 0.0; // seconds of current segment
  double _toneStartFreq = 0.0; // frequency at start of the current tone
  double _toneEndFreq = 0.0; // frequency at end of the current tone (glide)
  VarioWaveform _segWave = VarioWaveform.tack;
  // Force a fade envelope on the current tone even for the LONG waveform. Used
  // by the gated sink tick so its start/end don't click against the silence.
  bool _segForceFade = false;

  // Sink tick sub-phase. Each 1 s sink period plays TWO discrete steady tones
  // (no glide) then silence:
  //   0 -> start-frequency segment (sinkBaseFreq)
  //   1 -> current-frequency segment (sinkFrequencyFor(speed))
  //   2 -> trailing silence to complete the period
  int _sinkPhase = 0;

  // The vario state of the previous segment, so we can detect a fresh entry
  // into the sink state and (re)start its tick at phase 0.
  _VarioState _prevState = _VarioState.deadband;

  double _sr = 22050.0;
  double _dt = 1.0 / 22050.0;
  double _speedSmoothing = 0.02;
  double _gainSmoothing = 0.02;

  void _recompute() {
    _sr = _config.sampleRate.toDouble();
    _dt = 1.0 / _sr;
    // ~30 ms speed smoothing (sensitivity vs jitter) and ~5 ms gain smoothing.
    _speedSmoothing = 1.0 - math.exp(-1.0 / (0.030 * _sr));
    _gainSmoothing = 1.0 - math.exp(-1.0 / (0.005 * _sr));
  }

  _VarioState _stateFor(double speed) {
    if (speed >= _config.climbThreshold) return _VarioState.climb;
    if (speed <= _config.sinkThreshold) return _VarioState.sink;
    return _VarioState.deadband;
  }

  /// Renders [frameCount] mono frames as signed-16 LE PCM.
  Int16List render(int frameCount) {
    final channels = _config.channels;
    final out = Int16List(frameCount * channels);

    for (var i = 0; i < frameCount; i++) {
      // Smooth speed toward target (removes zipper noise).
      _smoothedSpeed += (_targetSpeed - _smoothedSpeed) * _speedSmoothing;

      // Advance the beep-cycle state machine by one sample.
      _tickCycle();

      double sample = 0.0;
      if (_inTone) {
        // Instantaneous frequency: exponential glide across the tone.
        final freq = _instantaneousFreq();
        // Phase-continuous accumulation (cycles). Never reset on freq change.
        _phase += freq * _dt;
        if (_phase >= 1.0) _phase -= _phase.floorToDouble();

        sample = _oscBlend(_segWave, _phase);
        sample *= _envelope(); // 5%/5% fade (skipped for LONG)
      }

      // Smooth master gain (mute/volume) to avoid clicks.
      _appliedGain += (outputGain - _appliedGain) * _gainSmoothing;

      final value = sample * _appliedGain * _config.masterGain;
      final s16 = (value.clamp(-1.0, 1.0) * 32767.0).round();
      final base = i * channels;
      for (var c = 0; c < channels; c++) {
        out[base + c] = s16;
      }
    }
    return out;
  }

  /// Advances the tone/silence segment machine by exactly one sample, starting
  /// new segments as needed based on the current (smoothed) speed.
  void _tickCycle() {
    _segElapsed += _dt;
    if (_segElapsed < _segDuration) return; // still inside current segment

    // Segment finished -> decide the next one from the CURRENT speed. This is
    // where a changed vertical speed takes effect, at a beep boundary, which is
    // exactly how XCTrack schedules its `w`/`h0` commands.
    final speed = _smoothedSpeed;
    final state = _stateFor(speed);
    _segElapsed = 0.0;
    switch (state) {
      case _VarioState.deadband:
        _inTone = false;
        _segForceFade = false;
        _segDuration = 0.02; // re-evaluate quickly (silence)
        break;

      case _VarioState.climb:
        if (_inTone) {
          // Just finished a tone -> emit the trailing silence gap.
          _inTone = false;
          final period = _config.climbPeriodFor(speed);
          _segDuration =
              math.max(0.001, period - _config.climbToneSeconds);
        } else {
          // Start a new climb beep (TACK). XCTrack uses a fixed 0.1 s tone.
          _inTone = true;
          _segForceFade = false;
          _segWave = _config.climbWaveform;
          _segDuration = _config.climbToneSeconds;
          // No pitch glide inside the climb beep (XCTrack passes f0==f1 there),
          // but we keep the glide machinery general.
          final f = _config.climbFrequencyFor(speed);
          _toneStartFreq = f;
          _toneEndFreq = f;
        }
        break;

      case _VarioState.sink:
        // XCTrack-style gated sink alarm: one tick per second, made of TWO
        // discrete steady tones (NO glide), then silence:
        //   phase 0 -> the sink START frequency (sinkBaseFreq, i.e. the pitch
        //              at the sink threshold),
        //   phase 1 -> the CURRENT sink-rate frequency (sinkFrequencyFor),
        //   phase 2 -> silence for the remainder of the period.
        // So each tick you hear the start pitch first, then the current pitch.
        final toneEach = math.min(
          _config.sinkToneSeconds * 0.5,
          _config.sinkPeriodSeconds * 0.5,
        );
        if (_prevState != _VarioState.sink) {
          // Fresh entry into sink -> (re)start the tick at phase 0.
          _sinkPhase = 0;
        } else {
          _sinkPhase = (_sinkPhase + 1) % 3;
        }

        if (_sinkPhase == 0) {
          // Segment 1: sink start frequency (steady, no glide).
          _inTone = true;
          _segForceFade = true;
          _segWave = _config.sinkWaveform;
          _segDuration = toneEach;
          _toneStartFreq = _config.sinkBaseFreq;
          _toneEndFreq = _config.sinkBaseFreq;
        } else if (_sinkPhase == 1) {
          // Segment 2: current sink-rate frequency (steady, no glide).
          _inTone = true;
          _segForceFade = true;
          _segWave = _config.sinkWaveform;
          _segDuration = toneEach;
          final f = _config.sinkFrequencyFor(speed);
          _toneStartFreq = f;
          _toneEndFreq = f;
        } else {
          // Trailing silence to complete the 1 s period.
          _inTone = false;
          _segForceFade = false;
          _segDuration = math.max(
            0.001,
            _config.sinkPeriodSeconds - 2 * toneEach,
          );
        }
        break;
    }

    _prevState = state;
  }

  /// Instantaneous frequency within the current tone segment.
  ///
  /// Exponential glide f(t) = f0 * (f1/f0)^(t/T). When f0==f1 this is just f0.
  double _instantaneousFreq() {
    if (_toneStartFreq == _toneEndFreq || _segDuration <= 0) {
      return _toneStartFreq;
    }
    final t = (_segElapsed / _segDuration).clamp(0.0, 1.0);
    return _toneStartFreq *
        math.pow(_toneEndFreq / _toneStartFreq, t).toDouble();
  }

  /// XCTrack oscillator blends. Base `u7.a` is a triangle in [-1,1].
  ///
  /// Verbatim amplitude ratios from c1.a (normalised to +-1 here):
  ///   TACK/LONG : tri(p)                     (single triangle)
  ///   SQUARE    : tri(p)*20000 + square*10000
  ///   TICK      : tri(p)*5000 + square*10000 + tri(p/2)*7500
  ///             + tri(2p)*3000 + tri(p/4)*3000
  double _oscBlend(VarioWaveform w, double p) {
    switch (w) {
      case VarioWaveform.tack:
      case VarioWaveform.long:
        return _tri(p);
      case VarioWaveform.square:
        final sq = (p % 1.0) < 0.5 ? 1.0 : -1.0;
        // (20000*tri + 10000*square) / 30000
        return (_tri(p) * 20000.0 + sq * 10000.0) / 30000.0;
      case VarioWaveform.tick:
        final sq = (p % 1.0) < 0.5 ? 1.0 : -1.0;
        final v = _tri(p) * 5000.0 +
            sq * 10000.0 +
            _tri(p / 2.0) * 7500.0 +
            _tri(p * 2.0) * 3000.0 +
            _tri(p / 4.0) * 3000.0;
        return v / 28500.0; // normalise to ~[-1,1]
    }
  }

  /// Triangle wave, XCTrack `u7.a`: period 1.0, phase-shifted +0.25, range -1..1.
  double _tri(double x) {
    final d = (x + 0.25) % 1.0;
    final dd = d < 0 ? d + 1.0 : d;
    return dd < 0.5 ? (4.0 * dd - 1.0) : (-(dd - 0.5) * 4.0 + 1.0);
  }

  /// XCTrack 5%/5% exponential fade envelope (skipped for LONG).
  ///
  /// XCTrack: for x in first 5% -> ramp = exp((x/0.05)*ln2) - 1  (0->1),
  /// for x in last 5% -> exp((|1-x|/0.05)*ln2) - 1. `ln2` makes exp() span 1..2
  /// so the multiplier spans 0..1.
  double _envelope() {
    // LONG normally has no envelope, but a gated tone (e.g. the sink tick) sets
    // _segForceFade so its edges still fade against the surrounding silence.
    if (_segWave == VarioWaveform.long && !_segForceFade) return 1.0;
    if (_segDuration <= 0) return 1.0;
    final x = (_segElapsed / _segDuration).clamp(0.0, 1.0);
    final f = _config.fadeFraction;
    double r;
    if (x < f) {
      r = x / f;
    } else if (x > 1.0 - f) {
      r = (1.0 - x) / f;
    } else {
      return 1.0;
    }
    // exp(r*ln2) - 1  == 2^r - 1, in [0,1].
    return math.pow(2.0, r).toDouble() - 1.0;
  }
}

// =============================================================================
// BACKEND SINK — the ONLY place that touches flutter_miniaudio.
// =============================================================================

/// Low-latency PCM sink over miniaudio's lock-free Int16 FIFO.
///
/// Flow control is FIFO-based (not open-loop): a timer wakes frequently and,
/// whenever the queued audio (`bufferLatency`) drops below the target
/// look-ahead, synthesizes and writes just enough frames to refill it —
/// clamped to the FIFO's currently available space. `write()` accepts at most
/// the free space, so we can never overflow (no backlog / delayed sound) and,
/// by always refilling to the target, we never underrun (no silence).
class _PcmSink {
  bool _open = false;
  late Int16List Function(int frameCount) _onRender;

  int _sampleRate = 22050;
  int _channels = 1;
  double _targetLatencySeconds = 0.02;
  int _fifoCapacityFrames = 0;

  MiniaudioPlayer? _player;

  /// Reusable native buffer for the largest chunk we ever write (interleaved
  /// Int16). Allocated once to avoid per-tick malloc/free.
  Pointer<Int16>? _native;
  int _nativeCapacityFrames = 0;

  Timer? _timer;

  Future<void> open({
    required int sampleRate,
    required int channels,
    required double chunkMs,
    required double lookAheadMs,
    required Int16List Function(int frameCount) onRender,
  }) async {
    _onRender = onRender;
    _sampleRate = sampleRate;
    _channels = channels;
    _targetLatencySeconds = (lookAheadMs * 0.001).clamp(0.008, 0.5);

    // Hardware period. A larger period means fewer, bigger device callbacks and
    // is much more tolerant of UI-isolate timer jitter (the cause of crackle).
    final bufferFrames =
        math.max(256, (chunkMs * 0.001 * sampleRate).round());
    // FIFO must comfortably hold several look-aheads so a stalled timer cannot
    // drain it before the next refill. Size it to >= 3x target look-ahead.
    final fifoCapacityFrames = math.max(
      bufferFrames * 4,
      (_targetLatencySeconds * 3.0 * sampleRate).round(),
    );
    _fifoCapacityFrames = fifoCapacityFrames;

    final player = MiniaudioPlayer(
      sampleRate: sampleRate,
      channels: channels,
      bufferFrames: bufferFrames,
      fifoCapacityFrames: fifoCapacityFrames,
    );
    _player = player;

    // Native scratch buffer sized to a full target look-ahead (worst-case fill).
    _nativeCapacityFrames =
        math.max(bufferFrames, (_targetLatencySeconds * sampleRate).ceil());
    _native = malloc<Int16>(_nativeCapacityFrames * channels);

    _open = true;

    player.start();
    // Prime the FIFO with a full look-ahead so playback starts with a cushion.
    _refill();

    // Poll several times per look-ahead period so a single missed tick never
    // empties the buffer. Bounded to a sane range.
    final tickUs = (lookAheadMs * 1000 / 4).round().clamp(2000, 15000);
    _timer = Timer.periodic(Duration(microseconds: tickUs), (_) => _refill());
  }

  /// Refills the FIFO up to the target look-ahead, bounded by free space.
  ///
  /// IMPORTANT plugin semantics: MiniaudioPlayer.fifoAvailableFrames returns the
  /// number of frames CURRENTLY QUEUED (data waiting to be played), NOT the free
  /// space. bufferLatency == fifoAvailableFrames / sampleRate. Free space is
  /// therefore (fifoCapacityFrames - queuedFrames). (Getting this backwards
  /// clamps writes to 0 at startup -> total silence.)
  void _refill() {
    final player = _player;
    final native = _native;
    if (!_open || player == null || native == null) return;

    // Frames currently queued in the FIFO (waiting to play).
    final queuedFrames = player.fifoAvailableFrames;
    final targetFrames = (_targetLatencySeconds * _sampleRate).round();

    // How many more frames we want queued to reach the target look-ahead.
    var wantFrames = targetFrames - queuedFrames;
    if (wantFrames <= 0) return; // enough queued -> don't overfill

    // Never exceed real free space in the FIFO (leave 1 frame headroom).
    final freeFrames =
        math.max(0, _fifoCapacityFrames - queuedFrames - 1);
    wantFrames = math.min(wantFrames, freeFrames);
    // Bound by our native scratch capacity.
    wantFrames = math.min(wantFrames, _nativeCapacityFrames);
    if (wantFrames <= 0) return;

    // Synthesize into the native buffer (interleaved Int16) and write frames.
    final Int16List pcm = _onRender(wantFrames);
    final needed = wantFrames * _channels;
    final n = math.min(needed, pcm.length);
    final dst = native.asTypedList(_nativeCapacityFrames * _channels);
    dst.setRange(0, n, pcm);
    // Zero-pad any shortfall so we never write stale native memory (which would
    // play back as a burst of noise / click).
    for (var k = n; k < needed; k++) {
      dst[k] = 0;
    }
    try {
      player.write(native, wantFrames);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VarioAudioService: miniaudio write failed: $e');
      }
    }
  }

  void close() {
    if (!_open) return;
    _open = false;
    _timer?.cancel();
    _timer = null;

    final player = _player;
    if (player != null) {
      try {
        player.stop();
        player.dispose();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('VarioAudioService: miniaudio close warning: $e');
        }
      }
    }
    _player = null;

    final native = _native;
    if (native != null) {
      malloc.free(native);
      _native = null;
    }
  }

  /// Applies output volume to the native mixer (0..1). Optional fast path so
  /// mute/volume can bypass the per-sample gain if desired.
  set hardwareVolume(double v) => _player?.setVolume(v.clamp(0.0, 1.0));
}
