import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShareCardSettings extends ChangeNotifier {
  ShareCardSettings._();

  static final ShareCardSettings instance = ShareCardSettings._();
  static const _flatDesignKey = 'pb.shareCardFlatDesign';

  bool _flatDesign = false;
  bool _loaded = false;

  bool get flatDesign => _flatDesign;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _flatDesign = preferences.getBool(_flatDesignKey) ?? false;
    } catch (_) {
      // Keep the glass-style default when storage is unavailable.
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
}
