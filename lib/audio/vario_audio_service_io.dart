// vario_audio_service_io.dart
// -----------------------------------------------------------------------------
// Native (dart:ffi) implementation of the vario audio engine. Used on all
// non-web platforms via conditional import from `vario_audio_service.dart`.
//
// This is the full XCTrack-faithful engine backed by flutter_miniaudio. Do not
// import this file directly; import `vario_audio_service.dart` instead so the
// web build can substitute its FFI-free stub.
// -----------------------------------------------------------------------------
//
// See the original header in this project's history for the design notes. The
// public API (VarioAudioService with the same members) is intentionally kept
// identical to the web stub in `vario_audio_service_web.dart`.
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

  // Independent "gate" applied on top of mute/volume. When closed, the engine
  // output is ramped to silence regardless of the driven speed. Used by the
  // flight-data bridge to enforce "sound only when flying" — feeding 0 m/s is
  // not enough because the deadband near-lift cue would still beep.
  //
  // Starts CLOSED so the engine is silent from the very first rendered sample.
  // init() begins rendering immediately, and the live feed defaults to 0 m/s
  // which maps to the audible near-lift cue; if the gate defaulted open the
  // vario would beep for a moment on app launch before the bridge applies its
  // real "sound only when flying/connected" decision. The bridge opens the
  // gate explicitly once sound is actually warranted.
  bool _gateOpen = false;

  // Preview takeover. When active, live vertical-speed updates (e.g. from the
  // flight-data bridge) are ignored and the engine is driven by the preview
  // speed instead. Used by the Vario Sound Settings panel so the user can
  // audition a chosen vertical speed without the live sensor feed fighting it.
  //
  // While previewing, [_previewMuted] decides whether the audition is heard.
  // When the preview is muted the engine falls back to the *live* vario feed,
  // still subject to the flight gate (so "sound only when flying" applies).
  bool _previewActive = false;
  bool _previewMuted = false;
  double _previewSpeed = 0.0;
  // The most recent live speed, retained so that muting the preview can hand
  // control back to the live feed without waiting for the next sensor tick.
  double _liveSpeed = 0.0;

  VarioAudioConfig get config => _synth.config;

  /// Whether preview takeover is currently engaged.
  bool get isPreviewActive => _previewActive;

  /// Begins preview takeover: subsequent [updateSpeed] calls from live sources
  /// are ignored (but retained) and the engine plays [initialSpeed] until
  /// [setPreviewSpeed]/[setPreviewMuted] change it or [endPreview] releases
  /// control back to the live feed.
  void beginPreview([double initialSpeed = 0.0]) {
    _previewActive = true;
    _previewMuted = false;
    _previewSpeed = initialSpeed;
    _refreshDrive();
  }

  /// Updates the audition speed while preview takeover is engaged. No-op if
  /// preview is not active.
  void setPreviewSpeed(double verticalSpeed) {
    if (!_previewActive) return;
    if (verticalSpeed.isNaN || verticalSpeed.isInfinite) return;
    _previewSpeed = verticalSpeed;
    _refreshDrive();
  }

  /// Mutes/unmutes the preview audition. While muted, the engine follows the
  /// live vario feed instead (still subject to the flight gate), so the
  /// combination of a muted preview + not flying + "sound only when flying"
  /// results in silence.
  void setPreviewMuted(bool muted) {
    if (_previewMuted == muted) return;
    _previewMuted = muted;
    _refreshDrive();
  }

  bool get isPreviewMuted => _previewMuted;

  /// Ends preview takeover and hands control back to the live feed.
  void endPreview() {
    if (!_previewActive) return;
    _previewActive = false;
    _previewMuted = false;
    _refreshDrive();
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
  /// The value is always retained as the live feed. It drives the engine unless
  /// an *unmuted* preview takeover is engaged, in which case the audition takes
  /// precedence (see [beginPreview] / [setPreviewMuted]).
  void updateSpeed(double verticalSpeed) {
    if (verticalSpeed.isNaN || verticalSpeed.isInfinite) return;
    _liveSpeed = verticalSpeed;
    if (_previewActive && !_previewMuted) return; // preview owns the engine
    _refreshDrive();
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

  /// Temporarily lowers the output to [level] (0..1) of the current volume,
  /// independent of the user volume (which is left untouched). 1.0 = normal.
  void setDuckLevel(double level) {
    _synth.duckGain = level.isFinite ? level.clamp(0.0, 1.0) : 1.0;
  }

  double get duckLevel => _synth.duckGain;

  /// Opens/closes the independent output gate (used to enforce "sound only when
  /// flying"). When closed, the *live* feed is ramped to silence even if a
  /// non-zero speed is driven. Does not affect an unmuted preview audition.
  void setGateOpen(bool open) {
    if (_gateOpen == open) return;
    _gateOpen = open;
    _refreshDrive();
  }

  bool get isGateOpen => _gateOpen;

  /// Plays a short XCTrack-style notification "ding" mixed over the vario
  /// output. It is independent of the vario mute/volume/gate and ducking, so
  /// it is heard before a voice announcement even while the vario is silent.
  /// Completes once the ding has mostly decayed; no-op until [init] ran.
  Future<void> playChime() async {
    if (!_initialized) return;
    _synth.startChime();
    await Future<void>.delayed(
      Duration(milliseconds: 420 + config.lookAheadMs.round()),
    );
  }

  /// Central decision point for what the engine plays and whether it is heard.
  ///
  /// Logic:
  ///  * If a preview is active and NOT muted → play the audition speed,
  ///    audible regardless of the flight gate.
  ///  * Otherwise → follow the live feed, audible only when the gate is open.
  /// The user mute always wins.
  void _refreshDrive() {
    final previewAudible = _previewActive && !_previewMuted;
    _synth.setTargetSpeed(previewAudible ? _previewSpeed : _liveSpeed);
    _applyOutputGain(previewAudible: previewAudible);
  }

  void _applyOutputGain({bool? previewAudible}) {
    final pa = previewAudible ?? (_previewActive && !_previewMuted);
    // Preview audition ignores the flight gate; the live feed obeys it.
    final gateAllows = pa || _gateOpen;
    final audible = gateAllows && !_muted;
    _synth.outputGain = audible ? _volume : 0.0;
  }

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

enum _VarioState { deadband, nearLift, lift, sink, keypoint }

/// Renders [frames] PCM frames of the vario engine held at [verticalSpeed]
/// with full output gain, without opening an audio device. Test-only.
@visibleForTesting
Int16List debugRenderVario(
  VarioAudioConfig config,
  double verticalSpeed,
  int frames,
) {
  final synth = _VarioSynth(config)
    ..outputGain = 1.0
    ..setTargetSpeed(verticalSpeed);
  return synth.render(frames);
}

/// Renders [frames] PCM frames of the notification ding with the vario
/// output silenced, without opening an audio device. Test-only.
@visibleForTesting
Int16List debugRenderChime(VarioAudioConfig config, int frames) {
  final synth = _VarioSynth(config)..startChime();
  return synth.render(frames);
}

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

  // Normalized soft-clip drive used as a fixed loudness boost. The output is
  // normalized back to unity at full scale, so this cannot exceed PCM limits.
  static const double _loudnessDrive = 2.0;
  static final double _loudnessNormalizer =
      (math.exp(2.0 * _loudnessDrive) - 1.0) /
      (math.exp(2.0 * _loudnessDrive) + 1.0);

  double _targetSpeed = 0.0;
  // Starts at 0.0 so the engine is silent from the very first rendered sample.
  // The sink begins rendering during init() before any mute/volume/gate setter
  // runs; defaulting this to 1.0 made the vario audible for that first buffer
  // on app launch (the 0 m/s live feed maps to the near-lift cue). The service
  // raises this to the real volume only once sound is actually warranted.
  double outputGain = 0.0;

  void setTargetSpeed(double v) => _targetSpeed = v;

  double _smoothedSpeed = 0.0;
  double _phase = 0.0;
  double _appliedGain = 0.0;

  bool _inTone = false;
  double _segElapsed = 0.0;
  double _segDuration = 0.0;
  double _toneStartFreq = 0.0;
  double _toneEndFreq = 0.0;
  VarioWaveform _segWave = VarioWaveform.tack;
  bool _segForceFade = false;
  // Per-segment amplitude multiplier (used for softened near-lift cue).
  double _segGain = 1.0;

  int _sinkPhase = 0;
  int _nearLiftPhase = 0;
  bool _keypointTone = true;

  // XCTrack TICK accent: an exponentially-averaged climb value and a per-beep
  // counter. One TICK is emitted every `round(avgLiftSpeed)` lift beeps while
  // the average is at/above the threshold.
  double _avgLiftSpeed = 0.0;
  int _liftTickCounter = 0;

  _VarioState _prevState = _VarioState.deadband;

  double _sr = 22050.0;
  double _dt = 1.0 / 22050.0;
  double _speedSmoothing = 0.02;
  double _gainSmoothing = 0.02;
  double _duckSmoothing = 0.001;

  /// Temporary attenuation (0..1) applied on top of the volume, e.g. while a
  /// voice announcement is playing. Faded smoothly (~120 ms) to avoid clicks.
  double duckGain = 1.0;
  double _appliedDuck = 1.0;

  void _recompute() {
    _sr = _config.sampleRate.toDouble();
    _dt = 1.0 / _sr;
    _speedSmoothing = 1.0 - math.exp(-1.0 / (0.030 * _sr));
    _gainSmoothing = 1.0 - math.exp(-1.0 / (0.005 * _sr));
    _duckSmoothing = 1.0 - math.exp(-1.0 / (0.040 * _sr));
  }

  _VarioState _stateFor(double speed) {
    // User keypoints take over whenever the speed falls inside their range.
    if (_config.keypoints.covers(speed)) return _VarioState.keypoint;
    if (speed >= _config.liftThreshold) return _VarioState.lift;
    if (speed <= _config.sinkThreshold) return _VarioState.sink;

    // Custom deadband split:
    //   * sinkThreshold < v < 0.0      -> silent, or the deadband cue when the
    //                                     sink notification zone is enabled
    //   * 0.0 <= v < liftThreshold     -> near-lift cue (softened)
    // Both cue zones share one state so the beep pattern continues seamlessly
    // when the speed crosses 0.0 m/s.
    if (speed < 0.0) {
      return _config.sinkZoneCueEnabled
          ? _VarioState.nearLift
          : _VarioState.deadband;
    }
    if (_config.nearLiftEnabled) return _VarioState.nearLift;
    return _VarioState.deadband;
  }

  Int16List render(int frameCount) {
    final channels = _config.channels;
    final out = Int16List(frameCount * channels);

    for (var i = 0; i < frameCount; i++) {
      _smoothedSpeed += (_targetSpeed - _smoothedSpeed) * _speedSmoothing;
      final avgWindow = math.max(0.05, _config.classicTickAverageSeconds);
      final avgAlpha = 1.0 - math.exp(-_dt / avgWindow);
      _avgLiftSpeed += (_smoothedSpeed - _avgLiftSpeed) * avgAlpha;
      _tickCycle();

      double sample = 0.0;
      if (_inTone) {
        final freq = _instantaneousFreq();
        _phase += freq * _dt;
        if (_phase >= 1.0) _phase -= _phase.floorToDouble();
        sample = _oscBlend(_segWave, _phase);
        sample *= _envelope();
      }

      _appliedGain += (outputGain - _appliedGain) * _gainSmoothing;

      final value = sample * _segGain * _appliedGain * _config.masterGain;
      // Apply gentle normalized saturation before PCM conversion. This uses the
      // available digital headroom more effectively than hard clipping, making
      // the vario noticeably louder at the same system volume while keeping
      // peaks bounded to the signed 16-bit range.
      // Ducking is applied after saturation so the requested level is the
      // real output attenuation (before the soft clip it would be compressed).
      _appliedDuck += (duckGain - _appliedDuck) * _duckSmoothing;
      // The notification ding is mixed last: it ignores the vario gate,
      // volume and ducking.
      final shaped = _softClip(value) * _appliedDuck + _chimeSample();
      final s16 = (shaped.clamp(-1.0, 1.0) * 32767.0).round();
      final base = i * channels;
      for (var c = 0; c < channels; c++) {
        out[base + c] = s16;
      }
    }
    return out;
  }

  // ── Notification ding ───────────────────────────────────────────────────
  // A bell-like "ding" in the spirit of XCTrack's notification sound: a high
  // sine partial with a quick attack and exponential decay, plus an octave
  // and an inharmonic (x2.76) partial that die away faster for the metallic
  // strike. Total length ~0.9 s with a short fade so it never clicks.
  static const double _chimeSeconds = 0.9;
  static const double _chimeFreq = 1568.0; // G6
  static const double _chimeLevel = 0.7;
  double _chimeTime = -1.0; // < 0 = inactive
  double _chimePhase1 = 0.0;
  double _chimePhase2 = 0.0;
  double _chimePhase3 = 0.0;

  void startChime() {
    _chimeTime = 0.0;
    _chimePhase1 = 0.0;
    _chimePhase2 = 0.0;
    _chimePhase3 = 0.0;
  }

  double _chimeSample() {
    final t = _chimeTime;
    if (t < 0.0) return 0.0;
    if (t >= _chimeSeconds) {
      _chimeTime = -1.0;
      return 0.0;
    }
    _chimeTime = t + _dt;
    _chimePhase1 = (_chimePhase1 + _chimeFreq * _dt) % 1.0;
    _chimePhase2 = (_chimePhase2 + _chimeFreq * 2.0 * _dt) % 1.0;
    _chimePhase3 = (_chimePhase3 + _chimeFreq * 2.76 * _dt) % 1.0;
    const twoPi = 2.0 * math.pi;
    final strike =
        math.sin(twoPi * _chimePhase1) * math.exp(-t / 0.22) +
        0.35 * math.sin(twoPi * _chimePhase2) * math.exp(-t / 0.12) +
        0.15 * math.sin(twoPi * _chimePhase3) * math.exp(-t / 0.05);
    final attack = t < 0.004 ? t / 0.004 : 1.0;
    const fade = 0.06;
    final release = t > _chimeSeconds - fade ? (_chimeSeconds - t) / fade : 1.0;
    return strike / 1.5 * attack * release * _chimeLevel;
  }

  double _softClip(double value) {
    final drive = value * _loudnessDrive;
    final e = math.exp(2.0 * drive);
    final driven = (e - 1.0) / (e + 1.0);
    return driven / _loudnessNormalizer;
  }

  void _tickCycle() {
    _segElapsed += _dt;
    if (_segElapsed < _segDuration) return;

    final speed = _smoothedSpeed;
    final state = _stateFor(speed);
    _segElapsed = 0.0;
    switch (state) {
      case _VarioState.keypoint:
        final point = _config.keypoints.sampleAt(speed);
        if (point.duty <= 0.0) {
          _keypointTone = false;
        } else if (_prevState != _VarioState.keypoint) {
          _keypointTone = true;
        } else if (point.isContinuous) {
          _keypointTone = true;
        } else {
          _keypointTone = !_keypointTone;
        }
        _segGain = 1.0;
        if (_keypointTone) {
          _inTone = true;
          _segWave = point.waveform;
          // Short intermittent beeps always get an envelope (even LONG) to
          // avoid clicks; a continuous tone is left un-faded.
          _segForceFade = !point.isContinuous;
          _segDuration = math.max(
            _dt,
            point.isContinuous ? point.cycleSeconds : point.toneSeconds,
          );
          _toneStartFreq = point.freqHz;
          _toneEndFreq = point.freqHz;
        } else {
          _inTone = false;
          _segForceFade = false;
          _segDuration = math.max(_dt, point.gapSeconds);
        }
        break;

      case _VarioState.deadband:
        _inTone = false;
        _segForceFade = false;
        _segGain = 1.0;
        _segDuration = 0.02;
        break;

      case _VarioState.nearLift:
        if (_prevState != _VarioState.nearLift) {
          _nearLiftPhase = 0;
        } else {
          _nearLiftPhase = (_nearLiftPhase + 1) % 4;
        }

        if (_nearLiftPhase == 0 || _nearLiftPhase == 2) {
          _inTone = true;
          _segForceFade = true;
          _segWave = _config.nearLiftWaveform;
          _segDuration = math.max(0.001, _config.nearLiftToneSeconds);
          final f = _config.nearLiftFreq;
          _toneStartFreq = f;
          _toneEndFreq = f;
          _segGain = 0.5;
        } else if (_nearLiftPhase == 1) {
          _inTone = false;
          _segForceFade = false;
          _segGain = 1.0;
          _segDuration = math.max(0.001, _config.nearLiftBeepGapSeconds);
        } else {
          _inTone = false;
          _segForceFade = false;
          _segGain = 1.0;
          _segDuration = math.max(0.001, _config.nearLiftPairPauseSeconds);
        }
        break;

      case _VarioState.lift:
        _segGain = 1.0;
        // Reset the TICK accent counter on each fresh entry into lift so a new
        // climb can start with a TICK accent immediately.
        if (_prevState != _VarioState.lift) _liftTickCounter = 0;
        if (_inTone) {
          _inTone = false;
          final period = _config.liftPeriodFor(speed);
          _segDuration = math.max(0.001, period - _config.liftToneSeconds);
        } else {
          _inTone = true;
          _segForceFade = false;
          _segWave = _liftBeepWaveform();
          _segDuration = _config.liftToneSeconds;
          final f = _config.liftFrequencyFor(speed);
          _toneStartFreq = f;
          _toneEndFreq = f;
        }
        break;

      case _VarioState.sink:
        _segGain = 1.0;
        final toneEach = math.min(
          _config.sinkToneSeconds * 0.5,
          _config.sinkPeriodSeconds * 0.5,
        );
        if (_prevState != _VarioState.sink) {
          _sinkPhase = 0;
        } else {
          _sinkPhase = (_sinkPhase + 1) % 3;
        }

        if (_sinkPhase == 0) {
          _inTone = true;
          _segForceFade = true;
          _segWave = _config.sinkWaveform;
          _segDuration = toneEach;
          _toneStartFreq = _config.sinkBaseFreq;
          _toneEndFreq = _config.sinkBaseFreq;
        } else if (_sinkPhase == 1) {
          _inTone = true;
          _segForceFade = true;
          _segWave = _config.sinkWaveform;
          _segDuration = toneEach;
          final f = _config.sinkFrequencyFor(speed);
          _toneStartFreq = f;
          _toneEndFreq = f;
        } else {
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

  /// Chooses the waveform for the next lift beep. Reproduces XCTrack's TICK
  /// accent: when the chosen lift waveform is TACK and the TICK option is on,
  /// one TICK is emitted every `round(avgLiftSpeed)` beeps while the averaged
  /// climb is at/above [VarioAudioConfig.classicTickThreshold]; all other beeps
  /// (and any non-TACK chosen waveform) use the chosen waveform unchanged.
  VarioWaveform _liftBeepWaveform() {
    final base = _config.liftWaveform;
    if (!_config.classicTickEnabled || base != VarioWaveform.tack) {
      return base;
    }
    if (_liftTickCounter > 0) {
      _liftTickCounter--;
      return VarioWaveform.tack;
    }
    if (_avgLiftSpeed >= _config.classicTickThreshold) {
      // Emit a TICK accent now, then TACK for the next round(avg) - 1 beeps.
      final n = _avgLiftSpeed.round();
      _liftTickCounter = math.max(0, n - 1);
      return VarioWaveform.tick;
    }
    return VarioWaveform.tack;
  }

  double _instantaneousFreq() {
    if (_toneStartFreq == _toneEndFreq || _segDuration <= 0) {
      return _toneStartFreq;
    }
    final t = (_segElapsed / _segDuration).clamp(0.0, 1.0);
    return _toneStartFreq *
        math.pow(_toneEndFreq / _toneStartFreq, t).toDouble();
  }

  double _oscBlend(VarioWaveform w, double p) {
    switch (w) {
      case VarioWaveform.tack:
      case VarioWaveform.long:
        return _tri(p);
      case VarioWaveform.square:
        final sq = (p % 1.0) < 0.5 ? 1.0 : -1.0;
        return (_tri(p) * 20000.0 + sq * 10000.0) / 30000.0;
      case VarioWaveform.tick:
        final sq = (p % 1.0) < 0.5 ? 1.0 : -1.0;
        final v =
            _tri(p) * 5000.0 +
            sq * 10000.0 +
            _tri(p / 2.0) * 7500.0 +
            _tri(p * 2.0) * 3000.0 +
            _tri(p / 4.0) * 3000.0;
        return v / 28500.0;
    }
  }

  double _tri(double x) {
    final d = (x + 0.25) % 1.0;
    final dd = d < 0 ? d + 1.0 : d;
    return dd < 0.5 ? (4.0 * dd - 1.0) : (-(dd - 0.5) * 4.0 + 1.0);
  }

  double _envelope() {
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
    return math.pow(2.0, r).toDouble() - 1.0;
  }
}

// =============================================================================
// BACKEND SINK — the ONLY place that touches flutter_miniaudio.
// =============================================================================

class _PcmSink {
  bool _open = false;
  late Int16List Function(int frameCount) _onRender;

  int _sampleRate = 22050;
  int _channels = 1;
  double _targetLatencySeconds = 0.02;
  int _fifoCapacityFrames = 0;
  // Retained so the device can be rebuilt with the same geometry after the OS
  // stops/reroutes it (see the watchdog below).
  int _bufferFrames = 0;

  MiniaudioPlayer? _player;

  Pointer<Int16>? _native;
  int _nativeCapacityFrames = 0;

  Timer? _timer;

  // ── Device watchdog ────────────────────────────────────────────────────────
  // The OS can silently stop or reroute the native playback device during a
  // flight: an incoming VoIP / video call (e.g. WeChat), the camera grabbing
  // the microphone, voice recognition, or a Bluetooth route switch. miniaudio
  // is opened without a notification callback, so such a stop is invisible —
  // its data callback simply stops draining the FIFO and the vario goes quiet
  // for the rest of the flight, while voice announcements keep working because
  // flutter_tts re-activates its audio session on every utterance.
  //
  // This watchdog notices the dead device by checking whether it is still
  // consuming frames while the FIFO holds audio, and rebuilds it in place.
  static const Duration _stallTimeout = Duration(milliseconds: 600);
  int _lastConsumed = 0;
  DateTime? _progressAt;
  DateTime? _lastTickAt;
  bool _rebuilding = false;

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

    _bufferFrames = math.max(256, (chunkMs * 0.001 * sampleRate).round());
    _fifoCapacityFrames = math.max(
      _bufferFrames * 4,
      (_targetLatencySeconds * 3.0 * sampleRate).round(),
    );

    _nativeCapacityFrames = math.max(
      _bufferFrames,
      (_targetLatencySeconds * sampleRate).ceil(),
    );
    _native = malloc<Int16>(_nativeCapacityFrames * channels);

    _open = true;

    _createPlayer();

    final tickUs = (lookAheadMs * 1000 / 4).round().clamp(2000, 15000);
    _timer = Timer.periodic(Duration(microseconds: tickUs), (_) => _refill());
  }

  /// Creates and starts the native playback device with the stored geometry
  /// and installs a fresh watchdog baseline. Assumes any previous player has
  /// already been disposed (the native backend uses a single shared device).
  /// Returns whether a device is now running.
  bool _createPlayer() {
    try {
      final player = MiniaudioPlayer(
        sampleRate: _sampleRate,
        channels: _channels,
        bufferFrames: _bufferFrames,
        fifoCapacityFrames: _fifoCapacityFrames,
      );
      _player = player;
      player.start();
      // Give the fresh device a full timeout before it can be judged stalled.
      _lastConsumed = player.framesConsumed;
      _progressAt = DateTime.now();
      _refill();
      return true;
    } catch (e) {
      _player = null;
      if (kDebugMode) {
        debugPrint('VarioAudioService: miniaudio device create failed: $e');
      }
      return false;
    }
  }

  /// Tears down the (presumed dead) device and brings up a fresh one. The old
  /// player is disposed *before* the new one is created because the native
  /// backend manages a single global device; creating first would make the new
  /// device be torn down by the old player's dispose.
  void _rebuild() {
    if (_rebuilding || !_open) return;
    _rebuilding = true;
    try {
      final old = _player;
      _player = null;
      if (old != null) {
        try {
          old.stop();
          old.dispose();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('VarioAudioService: miniaudio rebuild dispose: $e');
          }
        }
      }
      _createPlayer();
    } finally {
      _rebuilding = false;
    }
  }

  void _refill() {
    final native = _native;
    if (!_open || native == null) return;

    final now = DateTime.now();
    final lastTick = _lastTickAt;
    _lastTickAt = now;

    // No device yet (initial create failed, or a rebuild is mid-flight): try to
    // bring one up and leave stall detection for later ticks.
    final player = _player;
    if (player == null) {
      _rebuild();
      return;
    }

    // ── Watchdog ──────────────────────────────────────────────────────────────
    // If the periodic tick itself paused for a long time, the OS most likely
    // suspended the whole app (and the device with it); that is not a device
    // stall, so just re-baseline instead of needlessly rebuilding.
    if (lastTick != null && now.difference(lastTick) > _stallTimeout) {
      _lastConsumed = player.framesConsumed;
      _progressAt = now;
    } else {
      final consumed = player.framesConsumed;
      final queued = player.fifoAvailableFrames;
      if (consumed != _lastConsumed || queued <= 0) {
        // Device is still draining (or there is simply nothing to drain):
        // healthy, keep the progress timer fresh.
        _lastConsumed = consumed;
        _progressAt = now;
      } else {
        // Audio is queued but the device consumed nothing: it has been stopped
        // or rerouted by the OS. Rebuild it once the stall persists.
        final since = _progressAt;
        if (since != null && now.difference(since) > _stallTimeout) {
          _rebuild();
          return;
        }
      }
    }

    final queuedFrames = player.fifoAvailableFrames;
    final targetFrames = (_targetLatencySeconds * _sampleRate).round();

    var wantFrames = targetFrames - queuedFrames;
    if (wantFrames <= 0) return;

    final freeFrames = math.max(0, _fifoCapacityFrames - queuedFrames - 1);
    wantFrames = math.min(wantFrames, freeFrames);
    wantFrames = math.min(wantFrames, _nativeCapacityFrames);
    if (wantFrames <= 0) return;

    final Int16List pcm = _onRender(wantFrames);
    final needed = wantFrames * _channels;
    final n = math.min(needed, pcm.length);
    final dst = native.asTypedList(_nativeCapacityFrames * _channels);
    dst.setRange(0, n, pcm);
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

  set hardwareVolume(double v) => _player?.setVolume(v.clamp(0.0, 1.0));
}
