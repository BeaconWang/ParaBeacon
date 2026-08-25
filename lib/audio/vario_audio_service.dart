// vario_audio_service.dart
// -----------------------------------------------------------------------------
// Real-time XCTrack-style vario audio engine.
//
// The engine SYNTHESIZES signed 16-bit PCM in pure Dart (no MP3/WAV assets) and
// pushes it into a low-latency native playback queue. Nothing about the sound
// is pre-baked: pitch, beep-rate and waveform are computed sample-by-sample
// from the live vertical speed, so latency is a single small buffer (~ a few
// milliseconds) and pitch/rate transitions are glitch-free.
//
// -----------------------------------------------------------------------------
// REQUIRED DEPENDENCY (add to pubspec.yaml, then `flutter pub get`):
//
//   dependencies:
//     flutter_soloud: ^4.1.7   # cross-platform low-latency audio engine
//
// Why flutter_soloud (instead of flutter_pcm_sound)?
//   * flutter_pcm_sound only ships native code for Android/iOS/macOS, so it is
//     SILENT on Windows and Linux (no platform implementation) — which is why
//     this app produced no sound on Windows.
//   * flutter_soloud supports Windows, Linux, macOS, Android, iOS and Web, and
//     exposes a push-based raw-PCM buffer stream:
//         setBufferStream(format: BufferType.s16le, ...)  -> AudioSource
//         addAudioDataStream(source, Uint8List pcmChunk)  -> queue samples
//     This matches our "synthesize 16-bit PCM in pure Dart" model exactly.
//
// SoLoud is PUSH-based (we feed it) rather than pull-based, so instead of a
// "feed me" callback we run a short periodic timer that pushes small PCM
// chunks, maintaining a small bounded look-ahead for low latency.
//
// This file is written so that the ONLY coupling to the plugin lives inside
// `_PcmSink` (see bottom). Swap that class to change backends; the DSP core
// (`_VarioSynth`) stays identical.
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'vario_config.dart';

/// Public, injectable vario audio service.
///
/// Typical lifecycle:
/// ```dart
/// final vario = VarioAudioService();      // or VarioAudioService.instance
/// await vario.init();
/// // in your 20-50 Hz sensor callback:
/// vario.updateSpeed(flightData.verticalSpeed);
/// // ...
/// vario.dispose();
/// ```
class VarioAudioService {
  /// Shared singleton for apps that want one global vario. You may also just
  /// construct instances directly (e.g. for DI / testing).
  static final VarioAudioService instance = VarioAudioService();

  VarioAudioService({VarioAudioConfig config = VarioAudioConfig.xcTrack})
      : _synth = _VarioSynth(config);

  final _VarioSynth _synth;
  final _PcmSink _sink = _PcmSink();

  bool _initialized = false;
  bool _muted = false;
  double _volume = 1.0;

  VarioAudioConfig get config => _synth.config;

  /// Replaces the active sound profile at runtime (e.g. from settings UI).
  /// Safe to call while playing; transitions are smoothed by the envelope.
  void setConfig(VarioAudioConfig config) => _synth.config = config;

  /// Initializes the native audio stream. Idempotent.
  Future<void> init() async {
    if (_initialized) return;
    await _sink.open(
      sampleRate: config.sampleRate,
      channels: config.channels,
      // The sink calls us back whenever it needs more PCM.
      onFeed: _feed,
    );
    _initialized = true;
  }

  /// Core driver. Call at 20-50 Hz with the latest vertical speed (m/s).
  ///
  /// This is intentionally cheap: it only stores the new target. The actual
  /// waveform is generated on the audio callback thread, so calling this more
  /// or less often never causes clicks and never blocks the sensor loop.
  void updateSpeed(double verticalSpeed) {
    if (verticalSpeed.isNaN || verticalSpeed.isInfinite) return;
    _synth.setTargetSpeed(verticalSpeed);
  }

  /// Mutes/unmutes without tearing down the stream. Gain is ramped by the
  /// envelope, so muting mid-beep does not click.
  void setMuted(bool isMuted) {
    _muted = isMuted;
    _applyOutputGain();
  }

  /// Sets output volume in the range 0..1.
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _applyOutputGain();
  }

  bool get isMuted => _muted;
  double get volume => _volume;

  void _applyOutputGain() {
    _synth.outputGain = _muted ? 0.0 : _volume;
  }

  /// Releases the native stream and all resources. Idempotent.
  void dispose() {
    if (!_initialized) return;
    _initialized = false;
    _sink.close();
  }

  /// Fills [frameCount] frames of PCM on demand. Called by the sink's push
  /// timer to obtain the next chunk of synthesized audio.
  Int16List _feed(int frameCount) => _synth.render(frameCount);
}

// =============================================================================
// DSP CORE — pure, backend-agnostic PCM synthesis.
// =============================================================================

/// Discrete vario states.
enum _VarioState { deadband, climb, sink }

/// The real-time synthesizer.
///
/// Design notes for a click-free result:
///  * A single phase accumulator drives the oscillator; frequency changes never
///    reset the phase, so pitch glides are continuous.
///  * Every audible edge (beep on/off, state change, mute) is multiplied by a
///    per-sample envelope that ramps over [VarioAudioConfig.fadeMs].
///  * Target speed is one-pole smoothed toward its setpoint so rapid sensor
///    jitter does not produce zipper noise.
class _VarioSynth {
  _VarioSynth(this._config);

  VarioAudioConfig _config;
  VarioAudioConfig get config => _config;
  set config(VarioAudioConfig c) {
    _config = c;
    _recomputeCoeffs();
  }

  // --- runtime setpoints (written by the UI/sensor thread) -------------------

  // Using plain doubles is fine: Dart is single-isolate and flutter_pcm_sound
  // delivers its feed callback on the platform thread within the same isolate,
  // so there is no true data race. We still keep writes trivial (store-only).
  double _targetSpeed = 0.0;
  double outputGain = 1.0; // 0..1, set by mute/volume.

  void setTargetSpeed(double v) => _targetSpeed = v;

  // --- smoothed internal state -----------------------------------------------

  double _smoothedSpeed = 0.0; // one-pole smoothed vertical speed
  double _phase = 0.0; // oscillator phase, radians [0, 2pi)
  double _beepPhase = 0.0; // beep cycle phase [0, 1)
  double _env = 0.0; // current output envelope 0..1
  double _appliedGain = 0.0; // smoothed master/volume gain 0..1
  double _lpState = 0.0; // low-pass filter memory (climb square)

  // --- cached coefficients ----------------------------------------------------

  late double _fadeSamples; // envelope ramp length in samples
  late double _speedSmoothing; // one-pole coeff for speed
  late double _gainSmoothing; // one-pole coeff for gain

  bool _coeffsReady = false;

  void _recomputeCoeffs() {
    final sr = _config.sampleRate.toDouble();
    _fadeSamples = math.max(1.0, _config.fadeMs * 0.001 * sr);
    // ~30 ms time-constant speed smoothing keeps low-speed sensitivity while
    // taming jitter. coeff = 1 - exp(-1 / (tau * sr)).
    _speedSmoothing = 1.0 - math.exp(-1.0 / (0.030 * sr));
    // Fast (~5 ms) gain smoothing for mute/volume so it is click-free but snappy.
    _gainSmoothing = 1.0 - math.exp(-1.0 / (0.005 * sr));
    _coeffsReady = true;
  }

  _VarioState _stateFor(double speed) {
    if (speed >= _config.climbThreshold) return _VarioState.climb;
    if (speed <= _config.sinkThreshold) return _VarioState.sink;
    return _VarioState.deadband;
  }

  /// Renders [frameCount] mono frames as signed-16 LE PCM.
  Int16List render(int frameCount) {
    if (!_coeffsReady) _recomputeCoeffs();

    final sr = _config.sampleRate.toDouble();
    final channels = _config.channels;
    final out = Int16List(frameCount * channels);

    final twoPi = 2 * math.pi;
    final fadeInc = 1.0 / _fadeSamples;

    for (var i = 0; i < frameCount; i++) {
      // 1) Smooth the incoming speed toward its target (one-pole).
      _smoothedSpeed += (_targetSpeed - _smoothedSpeed) * _speedSmoothing;
      final speed = _smoothedSpeed;
      final state = _stateFor(speed);

      // 2) Determine instantaneous pitch + whether this sample should sound.
      double freq;
      double sample;
      bool gateOpen; // whether the tone should be audible right now

      switch (state) {
        case _VarioState.deadband:
          // Silence. Let the envelope ramp down; keep phases coasting so a
          // re-entry into climb/sink resumes without a discontinuity.
          freq = 0.0;
          gateOpen = false;
          _advancePhase(0.0, sr, twoPi);
          sample = 0.0;
          break;

        case _VarioState.climb:
          freq = _config.climbFrequencyFor(speed);
          final rate = _config.climbBeepRateFor(speed).clamp(0.01, 60.0);
          // Advance the beep cycle; "on" for the duty-cycle fraction.
          _beepPhase += rate / sr;
          if (_beepPhase >= 1.0) _beepPhase -= _beepPhase.floorToDouble();
          gateOpen = _beepPhase < _config.climbDutyCycle;
          _advancePhase(freq, sr, twoPi);
          sample = _osc(_config.climbWaveform, _phase);
          if (_config.climbWaveform == VarioWaveform.square) {
            sample = _applyLowPass(sample, _config.climbLowPass);
          }
          break;

        case _VarioState.sink:
          // Continuous tone: no beep gating.
          freq = _config.sinkFrequencyFor(speed);
          gateOpen = true;
          _beepPhase = 0.0;
          _advancePhase(freq, sr, twoPi);
          sample = _osc(_config.sinkWaveform, _phase);
          break;
      }

      // 3) Envelope: ramp toward 1 when the gate is open, toward 0 otherwise.
      //    This single ramp removes clicks at beep edges AND state changes.
      final envTarget = gateOpen ? 1.0 : 0.0;
      if (_env < envTarget) {
        _env = math.min(envTarget, _env + fadeInc);
      } else if (_env > envTarget) {
        _env = math.max(envTarget, _env - fadeInc);
      }

      // 4) Smooth master gain (mute/volume) to avoid clicks on toggle.
      _appliedGain += (outputGain - _appliedGain) * _gainSmoothing;

      final value = sample *
          _env *
          _appliedGain *
          _config.masterGain; // final amplitude, -1..1

      final s16 = (value.clamp(-1.0, 1.0) * 32767.0).round();
      final base = i * channels;
      for (var c = 0; c < channels; c++) {
        out[base + c] = s16;
      }
    }

    return out;
  }

  /// Advances the main oscillator phase for one sample at [freq] Hz.
  void _advancePhase(double freq, double sr, double twoPi) {
    _phase += twoPi * freq / sr;
    if (_phase >= twoPi) _phase -= twoPi * (_phase / twoPi).floorToDouble();
  }

  /// Evaluates the selected waveform at [phase] radians. Range -1..1.
  double _osc(VarioWaveform w, double phase) {
    switch (w) {
      case VarioWaveform.sine:
        return math.sin(phase);
      case VarioWaveform.square:
        return math.sin(phase) >= 0.0 ? 1.0 : -1.0;
    }
  }

  /// One-pole low-pass to soften the square wave. [amount] 0..1 (0 = raw).
  double _applyLowPass(double x, double amount) {
    if (amount <= 0.0) return x;
    // Higher amount -> more smoothing. Clamp for stability.
    final a = amount.clamp(0.0, 0.99);
    _lpState = _lpState + (x - _lpState) * (1.0 - a);
    return _lpState;
  }
}

// =============================================================================
// BACKEND SINK — the ONLY place that touches flutter_soloud.
// =============================================================================

/// Thin wrapper around [SoLoud] providing a push-based PCM feed.
///
/// SoLoud is push-based: we create an s16le buffer-stream [AudioSource], start
/// playing it, then repeatedly push freshly synthesized PCM chunks with
/// [SoLoud.addAudioDataStream]. A short periodic timer keeps a small look-ahead
/// buffer full so latency stays low while never underrunning.
class _PcmSink {
  bool _open = false;
  late Int16List Function(int frameCount) _onFeed;

  int _sampleRate = 44100;

  SoLoud? _soloud;
  AudioSource? _source;
  SoundHandle? _handle;
  Timer? _pushTimer;

  /// How often we push a chunk. Small enough for low latency, large enough to
  /// keep CPU/overhead low.
  static const Duration _pushInterval = Duration(milliseconds: 20);

  /// Target look-ahead we try to keep queued (seconds). Roughly two push
  /// intervals of cushion to survive UI-thread jitter without audible gaps.
  static const double _lookAheadSeconds = 0.08;

  Future<void> open({
    required int sampleRate,
    required int channels,
    required Int16List Function(int frameCount) onFeed,
  }) async {
    _onFeed = onFeed;
    _sampleRate = sampleRate;

    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) {
      await soloud.init();
    }
    _soloud = soloud;

    // Create a raw signed-16-bit little-endian PCM buffer stream. We keep the
    // buffer "released" so old audio is discarded as it plays (this is a live
    // stream, not a seekable clip), preventing unbounded memory growth.
    _source = soloud.setBufferStream(
      sampleRate: sampleRate,
      channels: channels == 1 ? Channels.mono : Channels.stereo,
      format: BufferType.s16le,
      bufferingType: BufferingType.released,
      // Start playing as soon as a little data is queued -> low startup latency.
      bufferingTimeNeeds: _lookAheadSeconds,
    );

    _open = true;

    // Prime with an initial look-ahead so playback starts cleanly, then play.
    // SoLoud.play() returns a SoundHandle synchronously (not a Future).
    _pushChunk(seconds: _lookAheadSeconds);
    _handle = soloud.play(_source!);
    // Keep the stream topped up.
    _pushTimer = Timer.periodic(_pushInterval, (_) => _tick());
  }

  void _tick() {
    if (!_open) return;
    // Push a little more than one interval's worth each tick to maintain the
    // look-ahead cushion regardless of small timer drift.
    _pushChunk(seconds: _pushInterval.inMilliseconds / 1000.0 * 1.5);
  }

  /// Renders [seconds] of audio and pushes it into the SoLoud buffer stream.
  void _pushChunk({required double seconds}) {
    final soloud = _soloud;
    final source = _source;
    if (!_open || soloud == null || source == null) return;

    final frames = math.max(1, (seconds * _sampleRate).round());
    final Int16List pcm = _onFeed(frames);
    // View the Int16List as raw little-endian bytes (host is LE on all targets
    // Flutter supports); addAudioDataStream expects a Uint8List of s16le PCM.
    final bytes = pcm.buffer.asUint8List(
      pcm.offsetInBytes,
      pcm.lengthInBytes,
    );
    try {
      soloud.addAudioDataStream(source, bytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('VarioAudioService: addAudioDataStream failed: $e');
      }
    }
  }

  void close() {
    if (!_open) return;
    _open = false;

    _pushTimer?.cancel();
    _pushTimer = null;

    final soloud = _soloud;
    final source = _source;
    final handle = _handle;
    if (soloud != null && source != null) {
      try {
        soloud.setDataIsEnded(source);
        if (handle != null) soloud.stop(handle);
        soloud.disposeSource(source);
      } catch (e) {
        // Disposing an already-torn-down source is harmless; log in debug only.
        if (kDebugMode) {
          debugPrint('VarioAudioService: PCM sink close warning: $e');
        }
      }
    }
    _handle = null;
    _source = null;
    // Note: we intentionally do NOT call soloud.deinit() here — the SoLoud
    // engine is a shared singleton that other audio features may use. If the
    // vario is the sole audio user, call SoLoud.instance.deinit() at app exit.
  }
}
