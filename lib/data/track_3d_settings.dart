import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/locale_controller.dart';
import 'map_source.dart';

class Track3DSettings extends ChangeNotifier {
  Track3DSettings._() {
    LocaleController.instance.addListener(_onLanguageChanged);
  }

  static final Track3DSettings instance = Track3DSettings._();
  static const _mapSourceKey = 'pb.track3d.mapSource';
  static const _legacyGroundMapKey = 'pb.track3d.groundMap';

  String _mapSourceId = defaultMapSourceIdForLocale();
  bool _mapSourceExplicit = false;
  bool _loaded = false;

  String get mapSourceId => _mapSourceId;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await LocaleController.instance.load();
    _mapSourceId = defaultMapSourceIdForLocale();
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedMapSource = preferences.getString(_mapSourceKey);
      if (savedMapSource != null) {
        _mapSourceId = _normalizeMapSourceId(savedMapSource);
        _mapSourceExplicit = true;
        if (_mapSourceId != savedMapSource) {
          await preferences.setString(_mapSourceKey, _mapSourceId);
        }
      } else {
        final legacyEnabled = preferences.getBool(_legacyGroundMapKey);
        if (legacyEnabled == false) {
          _mapSourceId = 'none';
          _mapSourceExplicit = true;
          await preferences.setString(_mapSourceKey, _mapSourceId);
        }
      }
      await preferences.remove(_legacyGroundMapKey);
    } catch (_) {
      // Keep the language-dependent default when preference storage is unavailable.
    }
    notifyListeners();
  }

  void _onLanguageChanged() {
    if (_mapSourceExplicit) return;
    final next = defaultMapSourceIdForLocale();
    if (_mapSourceId == next) return;
    _mapSourceId = next;
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
    final changed = _mapSourceId != normalized;
    if (!changed && _mapSourceExplicit) return;
    _mapSourceId = normalized;
    _mapSourceExplicit = true;
    if (changed) notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_mapSourceKey, normalized);
      await preferences.remove(_legacyGroundMapKey);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
