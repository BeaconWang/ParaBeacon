import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app-wide defaults for numeric display formatting.
class DisplaySettings extends ChangeNotifier {
  DisplaySettings._();

  static final DisplaySettings instance = DisplaySettings._();
  static const _defaultPrecisionKey = 'pb.display.default_precision';

  bool _defaultPrecisionEnabled = false;
  bool _loaded = false;

  bool get defaultPrecisionEnabled => _defaultPrecisionEnabled;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      _defaultPrecisionEnabled =
          preferences.getBool(_defaultPrecisionKey) ?? false;
    } catch (_) {
      // Keep the safe whole-number default if storage is unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDefaultPrecisionEnabled(bool enabled) async {
    if (_defaultPrecisionEnabled == enabled) return;
    _defaultPrecisionEnabled = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_defaultPrecisionKey, enabled);
    } catch (_) {
      // The in-memory choice remains active for this session.
    }
  }
}
