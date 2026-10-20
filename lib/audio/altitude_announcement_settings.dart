import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted preferences for spoken altitude announcements.
class AltitudeAnnouncementSettings extends ChangeNotifier {
  AltitudeAnnouncementSettings._();

  static final AltitudeAnnouncementSettings instance =
      AltitudeAnnouncementSettings._();

  static const _kEnabled = 'pb.altitudeAnnouncements.enabled';
  static const _kMinimumLiftSpeed = 'pb.altitudeAnnouncements.minimumLiftSpeed';
  static const _kMaximumLiftSpeed = 'pb.altitudeAnnouncements.maximumLiftSpeed';

  bool _enabled = false;
  double _minimumLiftSpeed = 0.5;
  double _maximumLiftSpeed = 2.0;
  bool _loaded = false;

  bool get enabled => _enabled;
  double get minimumLiftSpeed => _minimumLiftSpeed;
  double get maximumLiftSpeed => _maximumLiftSpeed;

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
