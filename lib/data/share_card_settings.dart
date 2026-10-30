import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_source.dart';

class ShareCardSettings extends ChangeNotifier {
  ShareCardSettings._();

  static final ShareCardSettings instance = ShareCardSettings._();
  static const _flatDesignKey = 'pb.shareCardFlatDesign';
  static const _mapSourceKey = 'pb.shareCardMapSource';
  static const _legacyAmapSatelliteKey = 'pb.shareCardAmapSatellite';
  static const _compactLayoutKey = 'pb.shareCardCompactLayout';

  bool _flatDesign = false;
  bool _compactLayout = true;
  String _mapSourceId = 'amap-sat';
  bool _loaded = false;

  bool get flatDesign => _flatDesign;
  bool get compactLayout => _compactLayout;
  String get mapSourceId => _mapSourceId;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _flatDesign = preferences.getBool(_flatDesignKey) ?? false;
      _compactLayout = preferences.getBool(_compactLayoutKey) ?? true;
      final savedMapSource = preferences.getString(_mapSourceKey);
      if (savedMapSource != null) {
        _mapSourceId = _normalizeMapSourceId(savedMapSource);
        if (_mapSourceId != savedMapSource) {
          await preferences.setString(_mapSourceKey, _mapSourceId);
        }
        await preferences.remove(_legacyAmapSatelliteKey);
      } else {
        final legacyEnabled =
            preferences.getBool(_legacyAmapSatelliteKey) ?? true;
        _mapSourceId = legacyEnabled ? 'amap-sat' : 'none';
        await preferences.setString(_mapSourceKey, _mapSourceId);
        await preferences.remove(_legacyAmapSatelliteKey);
      }
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

  String _normalizeMapSourceId(String id) {
    if (id == 'none' ||
        MapSourceCatalog.secureRasterSources.any((source) => source.id == id)) {
      return id;
    }
    return 'none';
  }

  Future<void> setMapSourceId(String id) async {
    final normalized = _normalizeMapSourceId(id);
    if (_mapSourceId == normalized) return;
    _mapSourceId = normalized;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_mapSourceKey, normalized);
      await preferences.remove(_legacyAmapSatelliteKey);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }

  Future<void> setCompactLayout(bool enabled) async {
    if (_compactLayout == enabled) return;
    _compactLayout = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_compactLayoutKey, enabled);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
