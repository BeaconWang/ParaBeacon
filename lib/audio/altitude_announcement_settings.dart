import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'altitude_announcement_speaker.dart';
import 'announcement_template.dart';

/// Which recorded altitudes a new altitude record is compared against.
enum AltitudeRecordScope {
  /// The highest altitude of the current flight.
  flight,

  /// The highest altitude of every logged flight and the current one.
  allFlights,
}

/// Persisted preferences for spoken flight announcements.
///
/// Features (each independently switchable, each with its own text):
///  * takeoff / landing / continue flight (quick relaunch),
///  * glide dead zone,
///  * new altitude record,
///  * climb (lift range) — [enabled] for backward compatibility.
class AltitudeAnnouncementSettings extends ChangeNotifier {
  AltitudeAnnouncementSettings._();

  static final AltitudeAnnouncementSettings instance =
      AltitudeAnnouncementSettings._();

  static const _prefix = 'pb.altitudeAnnouncements';
  static const _kEnabled = '$_prefix.enabled';
  static const _kMinimumLiftSpeed = '$_prefix.minimumLiftSpeed';
  static const _kMaximumLiftSpeed = '$_prefix.maximumLiftSpeed';
  static const _kTemplate = '$_prefix.template';
  static const _kDuckVario = '$_prefix.duckVario';
  static const _kDuckLevel = '$_prefix.duckLevel';
  static const _kSpeechRate = '$_prefix.speechRate';
  static const _kTakeoffLandingEnabled = '$_prefix.takeoffLanding.enabled';
  static const _kGlideEnabled = '$_prefix.glide.enabled';
  static const _kGlideMinimum = '$_prefix.glide.minimum';
  static const _kGlideMaximum = '$_prefix.glide.maximum';
  static const _kGlideDelay = '$_prefix.glide.delaySeconds';
  static const _kRecordEnabled = '$_prefix.record.enabled';
  static const _kRecordScope = '$_prefix.record.scope';

  /// Storage key of the custom text for [event]. The climb text keeps the
  /// original key so existing customizations survive the upgrade.
  static String _templateKey(AnnouncementEvent event) =>
      event == AnnouncementEvent.climb
      ? _kTemplate
      : '$_kTemplate.${event.name}';

  /// Allowed range for [speechRate] (multiple of the normal speaking speed).
  static const minSpeechRate = AltitudeAnnouncementSpeaker.minRate;
  static const maxSpeechRate = AltitudeAnnouncementSpeaker.maxRate;

  /// Allowed range for [varioDuckLevel] (fraction of normal vario volume kept
  /// while speaking). 0 silences the vario completely during speech.
  static const minDuckLevel = 0.0;
  static const maxDuckLevel = 0.9;

  /// Limits of the glide dead-zone vertical-speed range (m/s).
  static const glideRangeMin = -3.0;
  static const glideRangeMax = 1.0;
  static const defaultGlideMinimum = -0.2;
  static const defaultGlideMaximum = 0.0;

  /// Limits of the time spent in the dead zone before announcing (seconds).
  static const minGlideDelay = 0.5;
  static const maxGlideDelay = 10.0;
  static const defaultGlideDelay = 0.5;

  bool _enabled = false;
  double _minimumLiftSpeed = 0.5;
  double _maximumLiftSpeed = 2.0;
  final Map<AnnouncementEvent, String> _templates = {};
  bool _duckVario = true;
  double _varioDuckLevel = 0.3;
  double _speechRate = 1.0;
  bool _takeoffLandingEnabled = false;
  bool _glideEnabled = false;
  double _glideMinimum = defaultGlideMinimum;
  double _glideMaximum = defaultGlideMaximum;
  double _glideDelaySeconds = defaultGlideDelay;
  bool _recordEnabled = false;
  AltitudeRecordScope _recordScope = AltitudeRecordScope.flight;
  bool _loaded = false;

  /// Speaking speed as a multiple of the normal speed (1.0 = normal).
  double get speechRate => _speechRate;

  /// Climb (lift range) announcement switch.
  bool get enabled => _enabled;
  double get minimumLiftSpeed => _minimumLiftSpeed;
  double get maximumLiftSpeed => _maximumLiftSpeed;

  /// Takeoff / landing / continue-flight announcements.
  bool get takeoffLandingEnabled => _takeoffLandingEnabled;

  /// Glide dead-zone announcement and its vertical-speed range (m/s).
  bool get glideEnabled => _glideEnabled;
  double get glideMinimum => _glideMinimum;
  double get glideMaximum => _glideMaximum;

  /// Time the vertical speed must stay in the dead zone before speaking.
  double get glideDelaySeconds => _glideDelaySeconds;
  Duration get glideDelay =>
      Duration(milliseconds: (_glideDelaySeconds * 1000).round());

  /// New altitude record announcement.
  bool get recordEnabled => _recordEnabled;
  AltitudeRecordScope get recordScope => _recordScope;

  /// Whether any announcement can currently be triggered.
  bool get anyEnabled =>
      _enabled || _takeoffLandingEnabled || _glideEnabled || _recordEnabled;

  /// Whether the vario tone is lowered while an announcement is spoken.
  bool get duckVario => _duckVario;

  /// Fraction (0..0.9) of the normal vario volume kept while speaking.
  double get varioDuckLevel => _varioDuckLevel;

  /// User-defined climb announcement template, or `null` for the default.
  String? get template => templateFor(AnnouncementEvent.climb);

  /// User-defined template for [event], or `null` to use the built-in
  /// default for the current language.
  String? templateFor(AnnouncementEvent event) => _templates[event];

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _enabled = preferences.getBool(_kEnabled) ?? _enabled;
      final minimum = preferences.getDouble(_kMinimumLiftSpeed);
      final maximum = preferences.getDouble(_kMaximumLiftSpeed);
      if (minimum != null && minimum.isFinite) {
        _minimumLiftSpeed = minimum.clamp(0.1, 5.9);
      }
      if (maximum != null && maximum.isFinite) {
        _maximumLiftSpeed = maximum.clamp(_minimumLiftSpeed + 0.1, 6.0);
      }
      for (final event in AnnouncementEvent.values) {
        final value = AnnouncementTemplate.sanitize(
          preferences.getString(_templateKey(event)),
        );
        if (value == null) {
          _templates.remove(event);
        } else {
          _templates[event] = value;
        }
      }
      _duckVario = preferences.getBool(_kDuckVario) ?? _duckVario;
      final duckLevel = preferences.getDouble(_kDuckLevel);
      if (duckLevel != null && duckLevel.isFinite) {
        _varioDuckLevel = duckLevel.clamp(minDuckLevel, maxDuckLevel);
      }
      final rate = preferences.getDouble(_kSpeechRate);
      if (rate != null && rate.isFinite) {
        _speechRate = rate.clamp(minSpeechRate, maxSpeechRate);
      }
      _takeoffLandingEnabled =
          preferences.getBool(_kTakeoffLandingEnabled) ??
          _takeoffLandingEnabled;
      _glideEnabled = preferences.getBool(_kGlideEnabled) ?? _glideEnabled;
      final glideMinimum = preferences.getDouble(_kGlideMinimum);
      final glideMaximum = preferences.getDouble(_kGlideMaximum);
      if (glideMinimum != null && glideMinimum.isFinite) {
        _glideMinimum = glideMinimum.clamp(glideRangeMin, glideRangeMax - 0.1);
      }
      if (glideMaximum != null && glideMaximum.isFinite) {
        _glideMaximum = glideMaximum.clamp(_glideMinimum + 0.1, glideRangeMax);
      } else if (_glideMaximum < _glideMinimum + 0.1) {
        _glideMaximum = _glideMinimum + 0.1;
      }
      final glideDelay = preferences.getDouble(_kGlideDelay);
      if (glideDelay != null && glideDelay.isFinite) {
        _glideDelaySeconds = glideDelay.clamp(minGlideDelay, maxGlideDelay);
      }
      _recordEnabled = preferences.getBool(_kRecordEnabled) ?? _recordEnabled;
      final scope = preferences.getString(_kRecordScope);
      _recordScope = AltitudeRecordScope.values.firstWhere(
        (value) => value.name == scope,
        orElse: () => AltitudeRecordScope.flight,
      );
    } catch (_) {
      // Keep defaults if local storage is unavailable.
    }
    notifyListeners();
  }

  void setEnabled(bool enabled) {
    if (_enabled == enabled) return;
    _enabled = enabled;
    _persistBool(_kEnabled, enabled);
    notifyListeners();
  }

  void setTakeoffLandingEnabled(bool enabled) {
    if (_takeoffLandingEnabled == enabled) return;
    _takeoffLandingEnabled = enabled;
    _persistBool(_kTakeoffLandingEnabled, enabled);
    notifyListeners();
  }

  void setGlideEnabled(bool enabled) {
    if (_glideEnabled == enabled) return;
    _glideEnabled = enabled;
    _persistBool(_kGlideEnabled, enabled);
    notifyListeners();
  }

  void setRecordEnabled(bool enabled) {
    if (_recordEnabled == enabled) return;
    _recordEnabled = enabled;
    _persistBool(_kRecordEnabled, enabled);
    notifyListeners();
  }

  void setRecordScope(AltitudeRecordScope scope) {
    if (_recordScope == scope) return;
    _recordScope = scope;
    _persistString(_kRecordScope, scope.name);
    notifyListeners();
  }

  void setLiftSpeedRange(double minimum, double maximum) {
    if (!minimum.isFinite || !maximum.isFinite) return;
    final nextMinimum = minimum.clamp(0.1, 5.9);
    final nextMaximum = maximum.clamp(nextMinimum + 0.1, 6.0);
    if (_minimumLiftSpeed == nextMinimum && _maximumLiftSpeed == nextMaximum) {
      return;
    }
    _minimumLiftSpeed = nextMinimum;
    _maximumLiftSpeed = nextMaximum;
    _persistDouble(_kMinimumLiftSpeed, nextMinimum);
    _persistDouble(_kMaximumLiftSpeed, nextMaximum);
    notifyListeners();
  }

  void setGlideRange(double minimum, double maximum) {
    if (!minimum.isFinite || !maximum.isFinite) return;
    final nextMinimum = _snap(
      minimum.clamp(glideRangeMin, glideRangeMax - 0.1),
      10,
    );
    final nextMaximum = _snap(
      maximum.clamp(nextMinimum + 0.1, glideRangeMax),
      10,
    );
    if (_glideMinimum == nextMinimum && _glideMaximum == nextMaximum) return;
    _glideMinimum = nextMinimum;
    _glideMaximum = nextMaximum;
    _persistDouble(_kGlideMinimum, nextMinimum);
    _persistDouble(_kGlideMaximum, nextMaximum);
    notifyListeners();
  }

  void setGlideDelaySeconds(double seconds) {
    if (!seconds.isFinite) return;
    final next = _snap(seconds.clamp(minGlideDelay, maxGlideDelay), 2);
    if (_glideDelaySeconds == next) return;
    _glideDelaySeconds = next;
    _persistDouble(_kGlideDelay, next);
    notifyListeners();
  }

  void setDuckVario(bool value) {
    if (_duckVario == value) return;
    _duckVario = value;
    _persistBool(_kDuckVario, value);
    notifyListeners();
  }

  void setVarioDuckLevel(double level) {
    if (!level.isFinite) return;
    final next = level.clamp(minDuckLevel, maxDuckLevel);
    if (_varioDuckLevel == next) return;
    _varioDuckLevel = next;
    _persistDouble(_kDuckLevel, next);
    notifyListeners();
  }

  void setSpeechRate(double rate) {
    if (!rate.isFinite) return;
    // Snap to 0.05 steps so persisted values stay tidy.
    final next = _snap(rate.clamp(minSpeechRate, maxSpeechRate), 20);
    if (_speechRate == next) return;
    _speechRate = next;
    _persistDouble(_kSpeechRate, next);
    notifyListeners();
  }

  /// Sets the custom climb template; a blank value restores the default.
  void setTemplate(String? template) =>
      setTemplateFor(AnnouncementEvent.climb, template);

  /// Sets the custom template of [event]; a blank value restores the default.
  void setTemplateFor(AnnouncementEvent event, String? template) {
    final next = AnnouncementTemplate.sanitize(template);
    if (_templates[event] == next) return;
    if (next == null) {
      _templates.remove(event);
    } else {
      _templates[event] = next;
    }
    _persistTemplate(_templateKey(event), next);
    notifyListeners();
  }

  /// Rounds [value] to steps of `1 / stepsPerUnit`.
  static double _snap(double value, int stepsPerUnit) =>
      ((value * stepsPerUnit).round() / stepsPerUnit).toDouble();

  void _persistTemplate(String key, String? value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (value == null) {
        await preferences.remove(key);
      } else {
        await preferences.setString(key, value);
      }
    } catch (_) {}
  }

  void _persistBool(String key, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(key, value);
    } catch (_) {}
  }

  void _persistDouble(String key, double value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(key, value);
    } catch (_) {}
  }

  void _persistString(String key, String value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, value);
    } catch (_) {}
  }
}
