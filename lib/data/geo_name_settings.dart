import 'package:shared_preferences/shared_preferences.dart';

/// Settings for optional reverse-geocoding of takeoff/landing coordinates to
/// human place names via the AMap (AutoNavi) web service.
///
/// The web-service API key is a user secret and is only ever read from these
/// settings (never hard-coded). Reverse geocoding is opt-in and, when enabled,
/// only contacts the fixed AMap host — see [ReverseGeocoderService].
class GeoNameSettings {
  GeoNameSettings._();
  static final GeoNameSettings instance = GeoNameSettings._();

  static const _kKey = 'pb.geoname.amapKey';
  static const _kAuto = 'pb.geoname.auto';

  String? _amapKey;
  bool _autoLookup = false;
  bool _loaded = false;

  /// The AMap web-service key, or null when the user hasn't set one.
  String? get amapKey => _amapKey;

  /// Whether to automatically resolve site names after a flight is saved.
  bool get autoLookup => _autoLookup;

  /// Whether reverse geocoding is usable (a non-empty key is configured).
  bool get isConfigured => (_amapKey?.isNotEmpty ?? false);

  /// Loads persisted settings (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      _amapKey = sp.getString(_kKey);
      _autoLookup = sp.getBool(_kAuto) ?? false;
    } catch (_) {
      // Best-effort; leave defaults.
    }
    _loaded = true;
  }

  Future<void> setAmapKey(String? key) async {
    _amapKey = key;
    try {
      final sp = await SharedPreferences.getInstance();
      if (key == null || key.isEmpty) {
        await sp.remove(_kKey);
      } else {
        await sp.setString(_kKey, key);
      }
    } catch (_) {}
  }

  Future<void> setAutoLookup(bool value) async {
    _autoLookup = value;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kAuto, value);
    } catch (_) {}
  }
}
