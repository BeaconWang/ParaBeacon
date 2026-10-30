import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Track3DSettings extends ChangeNotifier {
  Track3DSettings._();

  static final Track3DSettings instance = Track3DSettings._();
  static const _groundMapKey = 'pb.track3d.groundMap';

  bool _showGroundMap = false;
  bool _loaded = false;

  bool get showGroundMap => _showGroundMap;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _showGroundMap = preferences.getBool(_groundMapKey) ?? false;
    } catch (_) {
      // Keep map downloads disabled when preference storage is unavailable.
    }
    notifyListeners();
  }

  Future<void> setShowGroundMap(bool enabled) async {
    if (_showGroundMap == enabled) return;
    _showGroundMap = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_groundMapKey, enabled);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
