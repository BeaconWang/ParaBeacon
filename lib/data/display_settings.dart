import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app-wide defaults for numeric display formatting.
class DisplaySettings extends ChangeNotifier {
  DisplaySettings._();

  static final DisplaySettings instance = DisplaySettings._();
  static const _defaultPrecisionKey = 'pb.display.default_precision';
  static const _largerFontKey = 'pb.display.larger_font';

  bool _defaultPrecisionEnabled = true;
  bool _largerFontEnabled = true;
  bool _loaded = false;

  bool get defaultPrecisionEnabled => _defaultPrecisionEnabled;
  bool get largerFontEnabled => _largerFontEnabled;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      _defaultPrecisionEnabled =
          preferences.getBool(_defaultPrecisionKey) ?? true;
      _largerFontEnabled = preferences.getBool(_largerFontKey) ?? true;
    } catch (_) {
      // Keep the enabled defaults if storage is unavailable.
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

  Future<void> setLargerFontEnabled(bool enabled) async {
    if (_largerFontEnabled == enabled) return;
    _largerFontEnabled = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_largerFontKey, enabled);
    } catch (_) {
      // The in-memory choice remains active for this session.
    }
  }
}
