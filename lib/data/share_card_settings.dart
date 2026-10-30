import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShareCardSettings extends ChangeNotifier {
  ShareCardSettings._();

  static final ShareCardSettings instance = ShareCardSettings._();
  static const _flatDesignKey = 'pb.shareCardFlatDesign';
  static const _amapSatelliteKey = 'pb.shareCardAmapSatellite';

  bool _flatDesign = false;
  bool _amapSatelliteBackground = true;
  bool _loaded = false;

  bool get flatDesign => _flatDesign;
  bool get amapSatelliteBackground => _amapSatelliteBackground;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _flatDesign = preferences.getBool(_flatDesignKey) ?? false;
      _amapSatelliteBackground = preferences.getBool(_amapSatelliteKey) ?? true;
    } catch (_) {
      // Keep the enabled satellite-map default when storage is unavailable.
    }
    notifyListeners();
  }

  Future<void> setFlatDesign(bool enabled) async {
    if (_flatDesign == enabled) return;
    _flatDesign = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_flatDesignKey, enabled);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }

  Future<void> setAmapSatelliteBackground(bool enabled) async {
    if (_amapSatelliteBackground == enabled) return;
    _amapSatelliteBackground = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_amapSatelliteKey, enabled);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
