import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_languages.dart';
import '../theme/locale_controller.dart';
import 'map_source.dart';

class ShareCardSettings extends ChangeNotifier {
  ShareCardSettings._() {
    LocaleController.instance.addListener(_onLanguageChanged);
  }

  static final ShareCardSettings instance = ShareCardSettings._();
  static const _flatDesignKey = 'pb.shareCardFlatDesign';
  static const _mapSourceKey = 'pb.shareCardMapSource';
  static const _mapSourceExplicitKey = 'pb.shareCardMapSourceExplicit';
  static const _legacyAmapSatelliteKey = 'pb.shareCardAmapSatellite';
  static const _compactLayoutKey = 'pb.shareCardCompactLayout';

  bool _flatDesign = false;
  bool _compactLayout = true;
  String _mapSourceId = 'none';
  bool _mapSourceExplicit = false;
  bool _loaded = false;

  bool get flatDesign => _flatDesign;
  bool get compactLayout => _compactLayout;
  String get mapSourceId => _mapSourceId;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await LocaleController.instance.load();
    _mapSourceId = _languageDefaultMapSourceId;
    try {
      final preferences = await SharedPreferences.getInstance();
      _flatDesign = preferences.getBool(_flatDesignKey) ?? false;
      _compactLayout = preferences.getBool(_compactLayoutKey) ?? true;
      final savedMapSource = preferences.getString(_mapSourceKey);
      final legacyEnabled = preferences.getBool(_legacyAmapSatelliteKey);
      final wasExplicitlySelected =
          preferences.getBool(_mapSourceExplicitKey) ?? false;
      if (savedMapSource != null &&
          !(savedMapSource == 'amap-sat' &&
              !wasExplicitlySelected &&
              legacyEnabled == null)) {
        _mapSourceId = _normalizeMapSourceId(savedMapSource);
        _mapSourceExplicit = true;
        if (_mapSourceId != savedMapSource) {
          await preferences.setString(_mapSourceKey, _mapSourceId);
        }
        await preferences.setBool(_mapSourceExplicitKey, true);
      } else if (legacyEnabled != null) {
        _mapSourceId = legacyEnabled ? 'amap-sat' : 'none';
        _mapSourceExplicit = true;
        await preferences.setString(_mapSourceKey, _mapSourceId);
        await preferences.setBool(_mapSourceExplicitKey, true);
      } else {
        _mapSourceExplicit = false;
        await preferences.remove(_mapSourceKey);
        await preferences.remove(_mapSourceExplicitKey);
      }
      await preferences.remove(_legacyAmapSatelliteKey);
    } catch (_) {
      // Keep the language-dependent default when preference storage is unavailable.
    }
    notifyListeners();
  }

  String get _languageDefaultMapSourceId {
    final language = LocaleController.instance.current;
    final isChinese =
        language == AppLanguage.chineseSimplified ||
        (language == AppLanguage.system &&
            PlatformDispatcher.instance.locale.languageCode.toLowerCase() ==
                'zh');
    return isChinese ? 'amap-sat' : 'none';
  }

  void _onLanguageChanged() {
    if (_mapSourceExplicit) return;
    final next = _languageDefaultMapSourceId;
    if (_mapSourceId == next) return;
    _mapSourceId = next;
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
    final changed = _mapSourceId != normalized;
    if (!changed && _mapSourceExplicit) return;
    _mapSourceId = normalized;
    _mapSourceExplicit = true;
    if (changed) notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_mapSourceKey, normalized);
      await preferences.setBool(_mapSourceExplicitKey, true);
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
