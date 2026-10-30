import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_source.dart';

class Track3DSettings extends ChangeNotifier {
  Track3DSettings._();

  static final Track3DSettings instance = Track3DSettings._();
  static const _mapSourceKey = 'pb.track3d.mapSource';
  static const _legacyGroundMapKey = 'pb.track3d.groundMap';

  String _mapSourceId = 'none';
  bool _loaded = false;

  String get mapSourceId => _mapSourceId;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedMapSource = preferences.getString(_mapSourceKey);
      if (savedMapSource != null) {
        _mapSourceId = _normalizeMapSourceId(savedMapSource);
        if (_mapSourceId != savedMapSource) {
          await preferences.setString(_mapSourceKey, _mapSourceId);
        }
      } else {
        final legacyEnabled = preferences.getBool(_legacyGroundMapKey);
        _mapSourceId = legacyEnabled == true ? 'osm' : 'none';
        if (legacyEnabled != null) {
          await preferences.setString(_mapSourceKey, _mapSourceId);
        }
      }
      await preferences.remove(_legacyGroundMapKey);
    } catch (_) {
      // Keep the map layer disabled when preference storage is unavailable.
    }
    notifyListeners();
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
      await preferences.remove(_legacyGroundMapKey);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
