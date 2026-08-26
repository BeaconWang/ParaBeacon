import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vario_audio_service.dart';
import 'vario_config.dart';

/// Persisted, user-tunable Vario sound settings.
///
/// Owns the subset of [VarioAudioConfig] fields that are meaningful to expose
/// in a settings UI (thresholds, pitch, cadence, waveforms, master gain) and
/// keeps them in sync with the live [VarioAudioService] and `shared_preferences`.
///
/// The full [VarioAudioConfig] contains many low-level DSP/stream fields
/// (sample rate, buffering, envelope math). Those are left at their
/// XCTrack-faithful defaults; only the user-facing tuning knobs are persisted
/// here, layered on top of [VarioAudioConfig.xcTrack] via `copyWith`.
class VarioSoundSettings extends ChangeNotifier {
  VarioSoundSettings._();

  /// Shared singleton.
  static final VarioSoundSettings instance = VarioSoundSettings._();

  // ── Persistence keys ──────────────────────────────────────────────────────
  static const _kClimbThreshold = 'pb.vario.climbThreshold';
  static const _kSinkThreshold = 'pb.vario.sinkThreshold';
  static const _kClimbBaseFreq = 'pb.vario.climbBaseFreq';
  static const _kClimbFreqSpan = 'pb.vario.climbFreqSpan';
  static const _kSinkBaseFreq = 'pb.vario.sinkBaseFreq';
  static const _kClimbWaveform = 'pb.vario.climbWaveform';
  static const _kSinkWaveform = 'pb.vario.sinkWaveform';
  static const _kMasterGain = 'pb.vario.masterGain';

  static const VarioAudioConfig _base = VarioAudioConfig.xcTrack;

  // ── Current values (initialized to the XCTrack defaults) ──────────────────
  double _climbThreshold = _base.climbThreshold;
  double _sinkThreshold = _base.sinkThreshold;
  double _climbBaseFreq = _base.climbBaseFreq;
  double _climbFreqSpan = _base.climbFreqSpan;
  double _sinkBaseFreq = _base.sinkBaseFreq;
  VarioWaveform _climbWaveform = _base.climbWaveform;
  VarioWaveform _sinkWaveform = _base.sinkWaveform;
  double _masterGain = _base.masterGain;

  double get climbThreshold => _climbThreshold;
  double get sinkThreshold => _sinkThreshold;
  double get climbBaseFreq => _climbBaseFreq;
  double get climbFreqSpan => _climbFreqSpan;
  double get sinkBaseFreq => _sinkBaseFreq;
  VarioWaveform get climbWaveform => _climbWaveform;
  VarioWaveform get sinkWaveform => _sinkWaveform;
  double get masterGain => _masterGain;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Builds the effective [VarioAudioConfig] from the current settings.
  VarioAudioConfig get config => _base.copyWith(
        climbThreshold: _climbThreshold,
        sinkThreshold: _sinkThreshold,
        climbBaseFreq: _climbBaseFreq,
        climbFreqSpan: _climbFreqSpan,
        sinkBaseFreq: _sinkBaseFreq,
        climbWaveform: _climbWaveform,
        sinkWaveform: _sinkWaveform,
        masterGain: _masterGain,
      );

  /// Loads persisted values (if any) and applies them to the audio service.
  /// Safe to call multiple times; only the first load reads storage.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      _climbThreshold = sp.getDouble(_kClimbThreshold) ?? _climbThreshold;
      _sinkThreshold = sp.getDouble(_kSinkThreshold) ?? _sinkThreshold;
      _climbBaseFreq = sp.getDouble(_kClimbBaseFreq) ?? _climbBaseFreq;
      _climbFreqSpan = sp.getDouble(_kClimbFreqSpan) ?? _climbFreqSpan;
      _sinkBaseFreq = sp.getDouble(_kSinkBaseFreq) ?? _sinkBaseFreq;
      _climbWaveform = _waveformFromName(sp.getString(_kClimbWaveform)) ??
          _climbWaveform;
      _sinkWaveform =
          _waveformFromName(sp.getString(_kSinkWaveform)) ?? _sinkWaveform;
      _masterGain = sp.getDouble(_kMasterGain) ?? _masterGain;
    } catch (_) {
      // Storage unavailable: keep defaults.
    }
    _apply();
    notifyListeners();
  }

  // ── Mutators (each persists + applies live) ───────────────────────────────
  void setClimbThreshold(double v) {
    _climbThreshold = v.clamp(0.0, 5.0);
    _persistDouble(_kClimbThreshold, _climbThreshold);
    _applyAndNotify();
  }

  void setSinkThreshold(double v) {
    // Stored as a negative m/s value (sink).
    _sinkThreshold = v.clamp(-10.0, -0.5);
    _persistDouble(_kSinkThreshold, _sinkThreshold);
    _applyAndNotify();
  }

  void setClimbBaseFreq(double v) {
    _climbBaseFreq = v.clamp(200.0, 1500.0);
    _persistDouble(_kClimbBaseFreq, _climbBaseFreq);
    _applyAndNotify();
  }

  void setClimbFreqSpan(double v) {
    _climbFreqSpan = v.clamp(100.0, 2000.0);
    _persistDouble(_kClimbFreqSpan, _climbFreqSpan);
    _applyAndNotify();
  }

  void setSinkBaseFreq(double v) {
    _sinkBaseFreq = v.clamp(200.0, 1500.0);
    _persistDouble(_kSinkBaseFreq, _sinkBaseFreq);
    _applyAndNotify();
  }

  void setClimbWaveform(VarioWaveform w) {
    _climbWaveform = w;
    _persistString(_kClimbWaveform, w.name);
    _applyAndNotify();
  }

  void setSinkWaveform(VarioWaveform w) {
    _sinkWaveform = w;
    _persistString(_kSinkWaveform, w.name);
    _applyAndNotify();
  }

  void setMasterGain(double v) {
    _masterGain = v.clamp(0.0, 1.0);
    _persistDouble(_kMasterGain, _masterGain);
    _applyAndNotify();
  }

  /// Restores all values to the XCTrack defaults and clears storage.
  Future<void> resetToDefaults() async {
    _climbThreshold = _base.climbThreshold;
    _sinkThreshold = _base.sinkThreshold;
    _climbBaseFreq = _base.climbBaseFreq;
    _climbFreqSpan = _base.climbFreqSpan;
    _sinkBaseFreq = _base.sinkBaseFreq;
    _climbWaveform = _base.climbWaveform;
    _sinkWaveform = _base.sinkWaveform;
    _masterGain = _base.masterGain;
    try {
      final sp = await SharedPreferences.getInstance();
      await Future.wait([
        sp.remove(_kClimbThreshold),
        sp.remove(_kSinkThreshold),
        sp.remove(_kClimbBaseFreq),
        sp.remove(_kClimbFreqSpan),
        sp.remove(_kSinkBaseFreq),
        sp.remove(_kClimbWaveform),
        sp.remove(_kSinkWaveform),
        sp.remove(_kMasterGain),
      ]);
    } catch (_) {}
    _applyAndNotify();
  }

  // ── Internals ─────────────────────────────────────────────────────────────
  void _apply() => VarioAudioService.instance.setConfig(config);

  void _applyAndNotify() {
    _apply();
    notifyListeners();
  }

  void _persistDouble(String key, double value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(key, value);
    } catch (_) {}
  }

  void _persistString(String key, String value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, value);
    } catch (_) {}
  }

  static VarioWaveform? _waveformFromName(String? name) {
    if (name == null) return null;
    for (final w in VarioWaveform.values) {
      if (w.name == name) return w;
    }
    return null;
  }
}
