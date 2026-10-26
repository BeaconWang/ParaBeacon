import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vario_audio_service.dart';
import 'vario_config.dart';
import 'vario_keypoints.dart';

/// Top-level vario sound profile.
///
/// [xcTrack] is the stock, XCTrack-faithful preset: custom sound shaping
/// (pitch, waveform and keypoints) is ignored, while lift/sink thresholds still
/// apply. [custom] also applies the user's saved sound-shaping tuning.
enum VarioSoundProfile { xcTrack, custom }

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
  static const _kProfile = 'pb.vario.profile';
  static const _kLiftThreshold = 'pb.vario.liftThreshold';
  static const _kSinkThreshold = 'pb.vario.sinkThreshold';
  static const _kLiftBaseFreq = 'pb.vario.liftBaseFreq';
  static const _kLiftFreqSpan = 'pb.vario.liftFreqSpan';
  static const _kSinkBaseFreq = 'pb.vario.sinkBaseFreq';
  static const _kLiftWaveform = 'pb.vario.liftWaveform';
  static const _kSinkWaveform = 'pb.vario.sinkWaveform';
  static const _kKeypoints = 'pb.vario.keypoints';
  static const _kMasterGain = 'pb.vario.masterGain';
  static const _kSoundOnlyWhenFlying = 'pb.vario.soundOnlyWhenFlying';
  static const _kSoundOnlyWhenSensorConnected =
      'pb.vario.soundOnlyWhenSensorConnected';
  static const _kMuted = 'pb.vario.muted';
  static const _kVolume = 'pb.vario.volume';
  static const _kSinkZoneCue = 'pb.vario.sinkZoneCue';

  // ── Legacy keys (pre-"climb → lift" rename) read once for migration ───────
  static const _kLegacyClimbThreshold = 'pb.vario.climbThreshold';
  static const _kLegacyClimbBaseFreq = 'pb.vario.climbBaseFreq';
  static const _kLegacyClimbFreqSpan = 'pb.vario.climbFreqSpan';
  static const _kLegacyClimbWaveform = 'pb.vario.climbWaveform';

  static const VarioAudioConfig _base = VarioAudioConfig.xcTrack;

  // ── Current values (initialized to the XCTrack defaults) ──────────────────
  VarioSoundProfile _profile = VarioSoundProfile.xcTrack;
  double _liftThreshold = _base.liftThreshold;
  double _sinkThreshold = _base.sinkThreshold;
  double _liftBaseFreq = _base.liftBaseFreq;
  double _liftFreqSpan = _base.liftFreqSpan;
  double _sinkBaseFreq = _base.sinkBaseFreq;
  VarioWaveform _liftWaveform = _base.liftWaveform;
  VarioWaveform _sinkWaveform = _base.sinkWaveform;
  VarioKeypointCurve _keypoints = _base.keypoints;
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

  /// Sink notification zone: plays the deadband cue between the sink
  /// threshold and 0.0 m/s, a range that is otherwise silent. Applies to both
  /// profiles (it is a behaviour option, not sound shaping). Off by default.
  bool _sinkZoneCue = false;

  /// The selected top-level sound profile.
  VarioSoundProfile get profile => _profile;

  /// Whether profile-specific tuning controls are active. Threshold controls
  /// apply to both profiles.
  bool get customEnabled => _profile == VarioSoundProfile.custom;

  double get liftThreshold => _liftThreshold;
  double get sinkThreshold => _sinkThreshold;
  double get liftBaseFreq => _liftBaseFreq;
  double get liftFreqSpan => _liftFreqSpan;
  double get sinkBaseFreq => _sinkBaseFreq;
  VarioWaveform get liftWaveform => _liftWaveform;
  VarioWaveform get sinkWaveform => _sinkWaveform;

  /// The current user keypoint curve (sorted ascending by speed).
  VarioKeypointCurve get keypoints => _keypoints;

  /// Convenience view of the keypoint list (sorted ascending by speed).
  List<VarioKeypoint> get keypointList => _keypoints.anchors;

  double get masterGain => _masterGain;
  bool get soundOnlyWhenFlying => _soundOnlyWhenFlying;
  bool get soundOnlyWhenSensorConnected => _soundOnlyWhenSensorConnected;
  bool get muted => _muted;
  double get volume => _volume;
  bool get sinkZoneCue => _sinkZoneCue;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Builds the effective [VarioAudioConfig] from the current settings. Under
  /// the stock [VarioSoundProfile.xcTrack] profile custom sound shaping is
  /// ignored, while thresholds, master gain, and behavior options still apply.
  VarioAudioConfig get config {
    if (_profile == VarioSoundProfile.xcTrack) {
      return _base.copyWith(
        liftThreshold: _liftThreshold,
        sinkThreshold: _sinkThreshold,
        masterGain: _masterGain,
        sinkZoneCueEnabled: _sinkZoneCue,
      );
    }
    return _base.copyWith(
      liftThreshold: _liftThreshold,
      sinkThreshold: _sinkThreshold,
      liftBaseFreq: _liftBaseFreq,
      liftFreqSpan: _liftFreqSpan,
      sinkBaseFreq: _sinkBaseFreq,
      liftWaveform: _liftWaveform,
      sinkWaveform: _sinkWaveform,
      keypoints: _keypoints,
      masterGain: _masterGain,
      sinkZoneCueEnabled: _sinkZoneCue,
      // Custom profile pins one fixed waveform per speed: disable the XCTrack
      // periodic TICK accent so the chosen lift waveform never auto-switches.
      classicTickEnabled: false,
    );
  }

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

      _profile = _profileFromName(sp.getString(_kProfile)) ?? _profile;

      // New keys first, falling back to legacy keys for a one-time migration.
      _liftThreshold =
          sp.getDouble(_kLiftThreshold) ??
          sp.getDouble(_kLegacyClimbThreshold) ??
          _liftThreshold;
      _sinkThreshold = sp.getDouble(_kSinkThreshold) ?? _sinkThreshold;
      _liftBaseFreq =
          sp.getDouble(_kLiftBaseFreq) ??
          sp.getDouble(_kLegacyClimbBaseFreq) ??
          _liftBaseFreq;
      _liftFreqSpan =
          sp.getDouble(_kLiftFreqSpan) ??
          sp.getDouble(_kLegacyClimbFreqSpan) ??
          _liftFreqSpan;
      _sinkBaseFreq = sp.getDouble(_kSinkBaseFreq) ?? _sinkBaseFreq;
      _liftWaveform =
          _waveformFromName(sp.getString(_kLiftWaveform)) ??
          _waveformFromName(sp.getString(_kLegacyClimbWaveform)) ??
          _liftWaveform;
      _sinkWaveform =
          _waveformFromName(sp.getString(_kSinkWaveform)) ?? _sinkWaveform;
      _keypoints = _keypointsFromJson(sp.getString(_kKeypoints)) ?? _keypoints;
      _masterGain = sp.getDouble(_kMasterGain) ?? _masterGain;
      _soundOnlyWhenFlying =
          sp.getBool(_kSoundOnlyWhenFlying) ?? _soundOnlyWhenFlying;
      _soundOnlyWhenSensorConnected =
          sp.getBool(_kSoundOnlyWhenSensorConnected) ??
          _soundOnlyWhenSensorConnected;
      _muted = sp.getBool(_kMuted) ?? _muted;
      _volume = sp.getDouble(_kVolume) ?? _volume;
      _sinkZoneCue = sp.getBool(_kSinkZoneCue) ?? _sinkZoneCue;

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
    final hasLegacy =
        sp.containsKey(_kLegacyClimbThreshold) ||
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
  void setProfile(VarioSoundProfile profile) {
    if (_profile == profile) return;
    _profile = profile;
    _persistString(_kProfile, profile.name);
    _applyAndNotify();
  }

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

  // ── Vertical-speed keypoints ──────────────────────────────────────────────

  /// Inserts [kp] (or replaces an existing keypoint at the same ~0.1 m/s
  /// bucket), keeping the curve sorted, then persists + applies live.
  void upsertKeypoint(VarioKeypoint kp) {
    _keypoints = _keypoints.upsert(kp);
    _persistKeypoints();
    _applyAndNotify();
  }

  /// Removes any keypoint at [speed]'s ~0.1 m/s bucket.
  void removeKeypoint(double speed) {
    final next = _keypoints.removeAt(speed);
    if (next.length == _keypoints.length) return;
    _keypoints = next;
    _persistKeypoints();
    _applyAndNotify();
  }

  /// Removes all keypoints (reverts to the pure classic engine).
  void clearKeypoints() {
    if (_keypoints.isEmpty) return;
    _keypoints = VarioKeypointCurve.empty;
    _persistKeypoints();
    _applyAndNotify();
  }

  void _persistKeypoints() =>
      _persistString(_kKeypoints, jsonEncode(_keypointsToJson(_keypoints)));

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

  /// Enables/disables the sink notification zone (deadband cue between the
  /// sink threshold and 0.0 m/s) and applies it live.
  void setSinkZoneCue(bool v) {
    if (_sinkZoneCue == v) return;
    _sinkZoneCue = v;
    _persistBool(_kSinkZoneCue, v);
    _applyAndNotify();
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

  /// Restores all values to the XCTrack defaults and clears storage.
  Future<void> resetToDefaults() async {
    _profile = VarioSoundProfile.xcTrack;
    _liftThreshold = _base.liftThreshold;
    _sinkThreshold = _base.sinkThreshold;
    _liftBaseFreq = _base.liftBaseFreq;
    _liftFreqSpan = _base.liftFreqSpan;
    _sinkBaseFreq = _base.sinkBaseFreq;
    _liftWaveform = _base.liftWaveform;
    _sinkWaveform = _base.sinkWaveform;
    _keypoints = _base.keypoints;
    _masterGain = _base.masterGain;
    _soundOnlyWhenFlying = true;
    _soundOnlyWhenSensorConnected = true;
    _muted = false;
    _volume = 1.0;
    _sinkZoneCue = false;
    try {
      final sp = await SharedPreferences.getInstance();
      await Future.wait([
        sp.remove(_kProfile),
        sp.remove(_kLiftThreshold),
        sp.remove(_kSinkThreshold),
        sp.remove(_kLiftBaseFreq),
        sp.remove(_kLiftFreqSpan),
        sp.remove(_kSinkBaseFreq),
        sp.remove(_kLiftWaveform),
        sp.remove(_kSinkWaveform),
        sp.remove(_kKeypoints),
        sp.remove(_kMasterGain),
        sp.remove(_kSoundOnlyWhenFlying),
        sp.remove(_kSoundOnlyWhenSensorConnected),
        sp.remove(_kMuted),
        sp.remove(_kVolume),
        sp.remove(_kSinkZoneCue),
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

  static VarioSoundProfile? _profileFromName(String? name) {
    if (name == null) return null;
    for (final p in VarioSoundProfile.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  static List<Map<String, Object>> _keypointsToJson(VarioKeypointCurve curve) =>
      curve.anchors
          .map(
            (kp) => <String, Object>{
              'speed': kp.speed,
              'freqHz': kp.freqHz,
              'cycleMs': kp.cycleSeconds * 1000.0,
              'dutyPct': kp.duty * 100.0,
              'waveform': kp.waveform.name,
            },
          )
          .toList(growable: false);

  static VarioKeypointCurve? _keypointsFromJson(String? encoded) {
    if (encoded == null || encoded.length > 64 * 1024) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List || decoded.length > 128) return null;
      final keypoints = <VarioKeypoint>[];
      for (final item in decoded) {
        if (item is! Map) return null;
        final speed = item['speed'];
        final freq = item['freqHz'];
        final cycleMs = item['cycleMs'];
        final dutyPct = item['dutyPct'];
        final waveform = _waveformFromName(item['waveform'] as String?);
        if (speed is! num ||
            freq is! num ||
            cycleMs is! num ||
            dutyPct is! num ||
            waveform == null) {
          return null;
        }
        keypoints.add(
          VarioKeypoint(
            speed: speed.toDouble(),
            freqHz: freq.toDouble(),
            cycleSeconds: cycleMs.toDouble() / 1000.0,
            duty: (dutyPct.toDouble() / 100.0).clamp(0.0, 1.0),
            waveform: waveform,
          ),
        );
      }
      return VarioKeypointCurve.sorted(keypoints);
    } catch (_) {
      return null;
    }
  }
}
