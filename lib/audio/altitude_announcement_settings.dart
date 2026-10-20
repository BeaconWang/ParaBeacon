import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'altitude_announcement_speaker.dart';
import 'announcement_template.dart';

/// Persisted preferences for spoken altitude announcements.
class AltitudeAnnouncementSettings extends ChangeNotifier {
  AltitudeAnnouncementSettings._();

  static final AltitudeAnnouncementSettings instance =
      AltitudeAnnouncementSettings._();

  static const _kEnabled = 'pb.altitudeAnnouncements.enabled';
  static const _kMinimumLiftSpeed = 'pb.altitudeAnnouncements.minimumLiftSpeed';
  static const _kMaximumLiftSpeed = 'pb.altitudeAnnouncements.maximumLiftSpeed';
  static const _kTemplate = 'pb.altitudeAnnouncements.template';
  static const _kDuckVario = 'pb.altitudeAnnouncements.duckVario';
  static const _kDuckLevel = 'pb.altitudeAnnouncements.duckLevel';
  static const _kSpeechRate = 'pb.altitudeAnnouncements.speechRate';

  /// Allowed range for [speechRate] (multiple of the normal speaking speed).
  static const minSpeechRate = AltitudeAnnouncementSpeaker.minRate;
  static const maxSpeechRate = AltitudeAnnouncementSpeaker.maxRate;

  /// Allowed range for [varioDuckLevel] (fraction of normal vario volume kept
  /// while speaking). 0 silences the vario completely during speech.
  static const minDuckLevel = 0.0;
  static const maxDuckLevel = 0.9;

  bool _enabled = false;
  double _minimumLiftSpeed = 0.5;
  double _maximumLiftSpeed = 2.0;
  String? _template;
  bool _duckVario = true;
  double _varioDuckLevel = 0.3;
  double _speechRate = 1.0;
  bool _loaded = false;

  /// Speaking speed as a multiple of the normal speed (1.0 = normal).
  double get speechRate => _speechRate;

  bool get enabled => _enabled;
  double get minimumLiftSpeed => _minimumLiftSpeed;
  double get maximumLiftSpeed => _maximumLiftSpeed;

  /// Whether the vario tone is lowered while an announcement is spoken.
  bool get duckVario => _duckVario;

  /// Fraction (0..0.9) of the normal vario volume kept while speaking.
  double get varioDuckLevel => _varioDuckLevel;

  /// User-defined announcement template, or `null` to use the built-in
  /// default for the current language.
  String? get template => _template;

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
      _template = AnnouncementTemplate.sanitize(
        preferences.getString(_kTemplate),
      );
      _duckVario = preferences.getBool(_kDuckVario) ?? _duckVario;
      final duckLevel = preferences.getDouble(_kDuckLevel);
      if (duckLevel != null && duckLevel.isFinite) {
        _varioDuckLevel = duckLevel.clamp(minDuckLevel, maxDuckLevel);
      }
      final rate = preferences.getDouble(_kSpeechRate);
      if (rate != null && rate.isFinite) {
        _speechRate = rate.clamp(minSpeechRate, maxSpeechRate);
      }
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
    final next = ((rate.clamp(minSpeechRate, maxSpeechRate) * 20).round() / 20)
        .toDouble();
    if (_speechRate == next) return;
    _speechRate = next;
    _persistDouble(_kSpeechRate, next);
    notifyListeners();
  }

  /// Sets the custom template; a blank value restores the default.
  void setTemplate(String? template) {
    final next = AnnouncementTemplate.sanitize(template);
    if (_template == next) return;
    _template = next;
    _persistTemplate(next);
    notifyListeners();
  }

  void _persistTemplate(String? value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (value == null) {
        await preferences.remove(_kTemplate);
      } else {
        await preferences.setString(_kTemplate, value);
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
}
