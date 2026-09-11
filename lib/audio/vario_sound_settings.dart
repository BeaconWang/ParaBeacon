import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vario_audio_service.dart';
import 'vario_config.dart';
import 'vario_sound_curve.dart';

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
  static const _kLiftThreshold = 'pb.vario.liftThreshold';
  static const _kSinkThreshold = 'pb.vario.sinkThreshold';
  static const _kLiftBaseFreq = 'pb.vario.liftBaseFreq';
  static const _kLiftFreqSpan = 'pb.vario.liftFreqSpan';
  static const _kSinkBaseFreq = 'pb.vario.sinkBaseFreq';
  static const _kLiftWaveform = 'pb.vario.liftWaveform';
  static const _kSinkWaveform = 'pb.vario.sinkWaveform';
  static const _kMasterGain = 'pb.vario.masterGain';
  static const _kSoundOnlyWhenFlying = 'pb.vario.soundOnlyWhenFlying';
  static const _kSoundOnlyWhenSensorConnected =
      'pb.vario.soundOnlyWhenSensorConnected';
  static const _kMuted = 'pb.vario.muted';
  static const _kVolume = 'pb.vario.volume';
  static const _kCustomSoundEnabled = 'pb.vario.customSoundEnabled';
  static const _kCustomSoundFreqs = 'pb.vario.customSound.freqHz';
  static const _kCustomSoundCycles = 'pb.vario.customSound.cycleMs';
  static const _kCustomSoundDuties = 'pb.vario.customSound.dutyPct';

  // ── Legacy keys (pre-"climb → lift" rename) read once for migration ───────
  static const _kLegacyClimbThreshold = 'pb.vario.climbThreshold';
  static const _kLegacyClimbBaseFreq = 'pb.vario.climbBaseFreq';
  static const _kLegacyClimbFreqSpan = 'pb.vario.climbFreqSpan';
  static const _kLegacyClimbWaveform = 'pb.vario.climbWaveform';

  static const VarioAudioConfig _base = VarioAudioConfig.xcTrack;

  /// Fixed speed anchors used by the Sound customization editor.
  static const List<double> customSoundSpeeds = <double>[
    -7.0,
    -5.0,
    -4.0,
    -3.0,
    -2.0,
    -1.0,
    0.0,
    0.25,
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    4.0,
    5.0,
    7.0,
  ];

  // ── Current values (initialized to the XCTrack defaults) ──────────────────
  double _liftThreshold = _base.liftThreshold;
  double _sinkThreshold = _base.sinkThreshold;
  double _liftBaseFreq = _base.liftBaseFreq;
  double _liftFreqSpan = _base.liftFreqSpan;
  double _sinkBaseFreq = _base.sinkBaseFreq;
  VarioWaveform _liftWaveform = _base.liftWaveform;
  VarioWaveform _sinkWaveform = _base.sinkWaveform;
  double _masterGain = _base.masterGain;

  /// When true, the live vario beeper is silenced until a flight has started
  /// (see [FlightState.isFlying]). Preview/audition and flight replay are not
  /// affected — this only gates the live sensor feed. Defaults to true so the
  /// vario stays quiet on the ground until the user starts a flight.
  bool _soundOnlyWhenFlying = true;

  /// When true, the live vario beeper is silenced unless a Bluetooth sensor
  /// feed is connected. Preview/audition and flight replay are not affected —
  /// this only gates the live sensor feed (see [VarioAudioBridge]). Defaults to
  /// true so no sound is produced with no sensor attached.
  bool _soundOnlyWhenSensorConnected = true;

  /// Master on/off for the vario beeper (mute). Mirrors
  /// [VarioAudioService.isMuted] but is persisted here so the choice survives
  /// an app restart.
  bool _muted = false;

  /// Output volume, 0..1. Mirrors [VarioAudioService.volume] and is persisted.
  double _volume = 1.0;

  /// Whether the Sound customization curve is active.
  bool _customSoundEnabled = false;

  /// Anchor values for Sound customization.
  late List<double> _customFreqHz = _defaultCustomFreqHz();
  late List<double> _customCycleMs = _defaultCustomCycleMs();
  late List<double> _customDutyPct = _defaultCustomDutyPct();

  double get liftThreshold => _liftThreshold;
  double get sinkThreshold => _sinkThreshold;
  double get liftBaseFreq => _liftBaseFreq;
  double get liftFreqSpan => _liftFreqSpan;
  double get sinkBaseFreq => _sinkBaseFreq;
  VarioWaveform get liftWaveform => _liftWaveform;
  VarioWaveform get sinkWaveform => _sinkWaveform;
  double get masterGain => _masterGain;
  bool get soundOnlyWhenFlying => _soundOnlyWhenFlying;
  bool get soundOnlyWhenSensorConnected => _soundOnlyWhenSensorConnected;
  bool get muted => _muted;
  double get volume => _volume;
  bool get customSoundEnabled => _customSoundEnabled;
  List<double> get customFreqHz => List.unmodifiable(_customFreqHz);
  List<double> get customCycleMs => List.unmodifiable(_customCycleMs);
  List<double> get customDutyPct => List.unmodifiable(_customDutyPct);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Builds the effective [VarioAudioConfig] from the current settings.
  VarioAudioConfig get config => _base.copyWith(
        liftThreshold: _liftThreshold,
        sinkThreshold: _sinkThreshold,
        liftBaseFreq: _liftBaseFreq,
        liftFreqSpan: _liftFreqSpan,
        sinkBaseFreq: _sinkBaseFreq,
        liftWaveform: _liftWaveform,
        sinkWaveform: _sinkWaveform,
        masterGain: _masterGain,
        customSoundEnabled: _customSoundEnabled,
        customSoundCurve: _buildCustomCurve(),
      );

  /// Loads persisted values (if any) and applies them to the audio service.
  /// Safe to call multiple times; only the first load reads storage.
  ///
  /// Migration: values saved under the old `pb.vario.climb*` keys (before the
  /// "climb → lift" rename) are read as a fallback and re-persisted under the
  /// new `pb.vario.lift*` keys, after which the legacy keys are removed.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();

      // New keys first, falling back to legacy keys for a one-time migration.
      _liftThreshold = sp.getDouble(_kLiftThreshold) ??
          sp.getDouble(_kLegacyClimbThreshold) ??
          _liftThreshold;
      _sinkThreshold = sp.getDouble(_kSinkThreshold) ?? _sinkThreshold;
      _liftBaseFreq = sp.getDouble(_kLiftBaseFreq) ??
          sp.getDouble(_kLegacyClimbBaseFreq) ??
          _liftBaseFreq;
      _liftFreqSpan = sp.getDouble(_kLiftFreqSpan) ??
          sp.getDouble(_kLegacyClimbFreqSpan) ??
          _liftFreqSpan;
      _sinkBaseFreq = sp.getDouble(_kSinkBaseFreq) ?? _sinkBaseFreq;
      _liftWaveform = _waveformFromName(sp.getString(_kLiftWaveform)) ??
          _waveformFromName(sp.getString(_kLegacyClimbWaveform)) ??
          _liftWaveform;
      _sinkWaveform =
          _waveformFromName(sp.getString(_kSinkWaveform)) ?? _sinkWaveform;
      _masterGain = sp.getDouble(_kMasterGain) ?? _masterGain;
      _soundOnlyWhenFlying =
          sp.getBool(_kSoundOnlyWhenFlying) ?? _soundOnlyWhenFlying;
      _soundOnlyWhenSensorConnected =
          sp.getBool(_kSoundOnlyWhenSensorConnected) ??
              _soundOnlyWhenSensorConnected;
      _muted = sp.getBool(_kMuted) ?? _muted;
      _volume = sp.getDouble(_kVolume) ?? _volume;
      _customSoundEnabled =
          sp.getBool(_kCustomSoundEnabled) ?? _customSoundEnabled;
      _customFreqHz = _readDoubleList(
        sp,
        _kCustomSoundFreqs,
        fallback: _customFreqHz,
      );
      _customCycleMs = _readDoubleList(
        sp,
        _kCustomSoundCycles,
        fallback: _customCycleMs,
      );
      _customDutyPct = _readDoubleList(
        sp,
        _kCustomSoundDuties,
        fallback: _customDutyPct,
      );

      await _migrateLegacyKeys(sp);
    } catch (_) {
      // Storage unavailable: keep defaults.
    }
    _apply();
    notifyListeners();
  }

  /// If any legacy `climb*` key is present, re-persist the (now resolved)
  /// values under the new keys and delete the legacy ones. Best-effort.
  Future<void> _migrateLegacyKeys(SharedPreferences sp) async {
    final hasLegacy = sp.containsKey(_kLegacyClimbThreshold) ||
        sp.containsKey(_kLegacyClimbBaseFreq) ||
        sp.containsKey(_kLegacyClimbFreqSpan) ||
        sp.containsKey(_kLegacyClimbWaveform);
    if (!hasLegacy) return;
    try {
      await Future.wait([
        sp.setDouble(_kLiftThreshold, _liftThreshold),
        sp.setDouble(_kLiftBaseFreq, _liftBaseFreq),
        sp.setDouble(_kLiftFreqSpan, _liftFreqSpan),
        sp.setString(_kLiftWaveform, _liftWaveform.name),
        sp.remove(_kLegacyClimbThreshold),
        sp.remove(_kLegacyClimbBaseFreq),
        sp.remove(_kLegacyClimbFreqSpan),
        sp.remove(_kLegacyClimbWaveform),
      ]);
    } catch (_) {}
  }

  // ── Mutators (each persists + applies live) ───────────────────────────────
  void setLiftThreshold(double v) {
    _liftThreshold = v.clamp(0.0, 5.0);
    _persistDouble(_kLiftThreshold, _liftThreshold);
    _applyAndNotify();
  }

  void setSinkThreshold(double v) {
    // Stored as a negative m/s value (sink).
    _sinkThreshold = v.clamp(-10.0, -0.5);
    _persistDouble(_kSinkThreshold, _sinkThreshold);
    _applyAndNotify();
  }

  void setLiftBaseFreq(double v) {
    _liftBaseFreq = v.clamp(200.0, 1500.0);
    _persistDouble(_kLiftBaseFreq, _liftBaseFreq);
    _applyAndNotify();
  }

  void setLiftFreqSpan(double v) {
    _liftFreqSpan = v.clamp(100.0, 2000.0);
    _persistDouble(_kLiftFreqSpan, _liftFreqSpan);
    _applyAndNotify();
  }

  void setSinkBaseFreq(double v) {
    _sinkBaseFreq = v.clamp(200.0, 1500.0);
    _persistDouble(_kSinkBaseFreq, _sinkBaseFreq);
    _applyAndNotify();
  }

  void setLiftWaveform(VarioWaveform w) {
    _liftWaveform = w;
    _persistString(_kLiftWaveform, w.name);
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

  /// Enables/disables gating the live vario beeper on an in-progress flight.
  /// Only affects the live sensor feed (see [VarioAudioBridge]); it does not
  /// change the [VarioAudioConfig], so no need to re-apply the audio config.
  void setSoundOnlyWhenFlying(bool v) {
    if (_soundOnlyWhenFlying == v) return;
    _soundOnlyWhenFlying = v;
    _persistBool(_kSoundOnlyWhenFlying, v);
    notifyListeners();
  }

  /// Enables/disables gating the live vario beeper on a connected Bluetooth
  /// sensor. Only affects the live sensor feed (see [VarioAudioBridge]); it
  /// does not change the [VarioAudioConfig], so no need to re-apply it.
  void setSoundOnlyWhenSensorConnected(bool v) {
    if (_soundOnlyWhenSensorConnected == v) return;
    _soundOnlyWhenSensorConnected = v;
    _persistBool(_kSoundOnlyWhenSensorConnected, v);
    notifyListeners();
  }

  /// Mutes/unmutes the vario beeper and applies it live.
  void setMuted(bool v) {
    if (_muted == v) return;
    _muted = v;
    _persistBool(_kMuted, v);
    _applyAndNotify();
  }

  /// Sets the output volume (0..1) and applies it live.
  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _persistDouble(_kVolume, _volume);
    _applyAndNotify();
  }

  void setCustomSoundEnabled(bool v) {
    if (_customSoundEnabled == v) return;
    _customSoundEnabled = v;
    _persistBool(_kCustomSoundEnabled, v);
    _applyAndNotify();
  }

  void setCustomFrequencyAt(int index, double valueHz) {
    if (index < 0 || index >= _customFreqHz.length) return;
    _customFreqHz[index] = valueHz.clamp(100.0, 2000.0);
    _persistDoubleList(_kCustomSoundFreqs, _customFreqHz);
    _applyAndNotify();
  }

  void setCustomCycleAt(int index, double valueMs) {
    if (index < 0 || index >= _customCycleMs.length) return;
    _customCycleMs[index] = valueMs.clamp(100.0, 1200.0);
    _persistDoubleList(_kCustomSoundCycles, _customCycleMs);
    _applyAndNotify();
  }

  void setCustomDutyAt(int index, double valuePct) {
    if (index < 0 || index >= _customDutyPct.length) return;
    _customDutyPct[index] = valuePct.clamp(10.0, 100.0);
    _persistDoubleList(_kCustomSoundDuties, _customDutyPct);
    _applyAndNotify();
  }

  /// Restores all values to the XCTrack defaults and clears storage.
  Future<void> resetToDefaults() async {
    _liftThreshold = _base.liftThreshold;
    _sinkThreshold = _base.sinkThreshold;
    _liftBaseFreq = _base.liftBaseFreq;
    _liftFreqSpan = _base.liftFreqSpan;
    _sinkBaseFreq = _base.sinkBaseFreq;
    _liftWaveform = _base.liftWaveform;
    _sinkWaveform = _base.sinkWaveform;
    _masterGain = _base.masterGain;
    _soundOnlyWhenFlying = true;
    _soundOnlyWhenSensorConnected = true;
    _muted = false;
    _volume = 1.0;
    _customSoundEnabled = false;
    _customFreqHz = _defaultCustomFreqHz();
    _customCycleMs = _defaultCustomCycleMs();
    _customDutyPct = _defaultCustomDutyPct();
    try {
      final sp = await SharedPreferences.getInstance();
      await Future.wait([
        sp.remove(_kLiftThreshold),
        sp.remove(_kSinkThreshold),
        sp.remove(_kLiftBaseFreq),
        sp.remove(_kLiftFreqSpan),
        sp.remove(_kSinkBaseFreq),
        sp.remove(_kLiftWaveform),
        sp.remove(_kSinkWaveform),
        sp.remove(_kMasterGain),
        sp.remove(_kSoundOnlyWhenFlying),
        sp.remove(_kSoundOnlyWhenSensorConnected),
        sp.remove(_kMuted),
        sp.remove(_kVolume),
        sp.remove(_kCustomSoundEnabled),
        sp.remove(_kCustomSoundFreqs),
        sp.remove(_kCustomSoundCycles),
        sp.remove(_kCustomSoundDuties),
        // Also clear any leftover legacy keys.
        sp.remove(_kLegacyClimbThreshold),
        sp.remove(_kLegacyClimbBaseFreq),
        sp.remove(_kLegacyClimbFreqSpan),
        sp.remove(_kLegacyClimbWaveform),
      ]);
    } catch (_) {}
    _applyAndNotify();
  }

  // ── Internals ─────────────────────────────────────────────────────────────
  void _apply() {
    final service = VarioAudioService.instance;
    service.setConfig(config);
    service.setVolume(_volume);
    service.setMuted(_muted);
  }

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

  void _persistDoubleList(String key, List<double> values) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, jsonEncode(values));
    } catch (_) {}
  }

  List<double> _readDoubleList(
    SharedPreferences sp,
    String key, {
    required List<double> fallback,
  }) {
    final encoded = sp.getString(key);
    if (encoded == null || encoded.isEmpty) return List<double>.from(fallback);
    try {
      final raw = jsonDecode(encoded);
      if (raw is List) {
        final parsed = raw
            .map((e) => (e as num?)?.toDouble())
            .whereType<double>()
            .toList();
        if (parsed.length == customSoundSpeeds.length) {
          return parsed;
        }
      }
    } catch (_) {}
    return List<double>.from(fallback);
  }

  VarioSoundCurve _buildCustomCurve() {
    final anchors = <VarioSoundAnchor>[];
    for (var i = 0; i < customSoundSpeeds.length; i++) {
      anchors.add(
        VarioSoundAnchor(
          lift: customSoundSpeeds[i],
          freqHz: _customFreqHz[i],
          cycleMs: _customCycleMs[i],
          dutyPct: _customDutyPct[i],
        ),
      );
    }
    return VarioSoundCurve(anchors);
  }

  static List<double> _defaultCustomFreqHz() => customSoundSpeeds
      .map((v) => VarioSoundCurve.defaultCurve.sampleAt(v).freqHz)
      .toList(growable: false);

  static List<double> _defaultCustomCycleMs() => customSoundSpeeds
      .map((v) => VarioSoundCurve.defaultCurve.sampleAt(v).cycleSeconds * 1000.0)
      .toList(growable: false);

  static List<double> _defaultCustomDutyPct() => customSoundSpeeds
      .map((v) => VarioSoundCurve.defaultCurve.sampleAt(v).duty * 100.0)
      .toList(growable: false);

  void _persistString(String key, String value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, value);
    } catch (_) {}
  }

  void _persistBool(String key, bool value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(key, value);
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
