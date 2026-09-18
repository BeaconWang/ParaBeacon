import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent aircraft configuration, modelled after XCTrack's Glider
/// preferences. Values are local device settings and contain no secrets.
class AircraftSettings extends ChangeNotifier {
  AircraftSettings._();

  static final AircraftSettings instance = AircraftSettings._();

  static const faiClasses = <String, String>{
    '3': 'Paraglider',
    '1': 'Hang glider',
    '5': 'Rigid wing',
    '2': 'Rigid wing',
    '11': 'Powered paraglider (foot launch)',
    '12': 'Powered paraglider (trike)',
    '13': 'Powered aircraft',
    '14': 'Rigid wing (powered)',
    '15': 'Rigid wing (powered)',
    '16': 'Rigid glider',
  };

  static const paragliderCategories = <String>[
    'Standard',
    'Performance',
    'Competition',
  ];

  static const hangGliderCategories = <String>[
    'Flex wing',
    'Rigid wing',
    'Class 1',
    'Class 5',
  ];

  static const engineTypes = <String, String>{
    'T': 'None',
    'E': 'Electric',
    'I': 'Internal combustion',
  };

  static const _kFaiClass = 'pb.aircraft.faiClass';
  static const _kManufacturer = 'pb.aircraft.manufacturer';
  static const _kModel = 'pb.aircraft.model';
  static const _kName = 'pb.aircraft.name';
  static const _kParagliderCategory = 'pb.aircraft.paragliderCategory';
  static const _kHangGliderCategory = 'pb.aircraft.hangGliderCategory';
  static const _kTandem = 'pb.aircraft.tandem';
  static const _kEngineType = 'pb.aircraft.engineType';
  static const _kTrimSpeed = 'pb.aircraft.trimSpeedKmh';
  static const _kGoalGlideRatio = 'pb.aircraft.goalGlideRatio';
  static const _presetsAsset = 'assets/aircraft_presets.json';

  String faiClass = '3';
  String manufacturer = '';
  String model = '';
  String name = '';
  String paragliderCategory = '';
  String hangGliderCategory = '';
  bool tandem = false;
  String engineType = 'T';
  double trimSpeedKmh = 38.0;
  double goalGlideRatio = 9.0;

  bool _loaded = false;
  bool _saving = false;
  bool _presetsLoaded = false;
  Map<String, List<String>> _presets = const {};

  bool get isLoaded => _loaded;
  bool get arePresetsLoaded => _presetsLoaded;
  List<String> get manufacturers => _presets.keys.toList(growable: false);

  List<String> modelsFor(String manufacturer) =>
      _presets[manufacturer] ?? const <String>[];
  bool get isSaving => _saving;
  bool get isParagliderClass => const {'3', '11', '12'}.contains(faiClass);
  bool get isHangGliderClass =>
      const {'1', '2', '5', '14', '15', '16'}.contains(faiClass);

  String get faiClassLabel => faiClasses[faiClass] ?? faiClass;
  String get engineTypeLabel => engineTypes[engineType] ?? engineType;

  /// The compact name used in flight metadata and IGC headers.
  String get displayName {
    final explicit = name.trim();
    if (explicit.isNotEmpty) return explicit;
    final makeAndModel = [
      manufacturer.trim(),
      model.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    return makeAndModel.isEmpty ? faiClassLabel : makeAndModel;
  }

  Future<void> loadPresets() async {
    if (_presetsLoaded) return;
    try {
      final raw = await rootBundle.loadString(_presetsAsset);
      final decoded = jsonDecode(raw.replaceFirst('\ufeff', ''));
      if (decoded is List) {
        final presets = <String, List<String>>{};
        for (final entry in decoded) {
          if (entry is! Map) continue;
          final brand = entry['name'];
          final models = entry['models'];
          if (brand is! String || models is! List) continue;
          final normalizedBrand = brand.trim();
          final normalizedModels = <String>[];
          final seen = <String>{};
          for (final model in models) {
            if (model is! String) continue;
            final normalizedModel = model.trim();
            if (normalizedModel.isNotEmpty && seen.add(normalizedModel)) {
              normalizedModels.add(normalizedModel);
            }
          }
          if (normalizedBrand.isNotEmpty) {
            presets[normalizedBrand] = List.unmodifiable(normalizedModels);
          }
        }
        _presets = Map.unmodifiable(presets);
      }
    } on FormatException {
      _presets = const {};
    } on FlutterError {
      _presets = const {};
    } finally {
      _presetsLoaded = true;
      notifyListeners();
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      faiClass = _string(sp.getString(_kFaiClass), faiClass);
      manufacturer = _string(sp.getString(_kManufacturer), manufacturer);
      model = _string(sp.getString(_kModel), model);
      name = _string(sp.getString(_kName), name);
      paragliderCategory = _string(
        sp.getString(_kParagliderCategory),
        paragliderCategory,
      );
      hangGliderCategory = _string(
        sp.getString(_kHangGliderCategory),
        hangGliderCategory,
      );
      tandem = sp.getBool(_kTandem) ?? tandem;
      engineType = _string(sp.getString(_kEngineType), engineType);
      trimSpeedKmh = sp.getDouble(_kTrimSpeed) ?? trimSpeedKmh;
      goalGlideRatio = sp.getDouble(_kGoalGlideRatio) ?? goalGlideRatio;
    } catch (_) {
      // Storage is best-effort; keep safe defaults if unavailable.
    }
    notifyListeners();
  }

  Future<void> save({
    required String faiClass,
    required String manufacturer,
    required String model,
    required String name,
    required String paragliderCategory,
    required String hangGliderCategory,
    required bool tandem,
    required String engineType,
    required double trimSpeedKmh,
    required double goalGlideRatio,
  }) async {
    this.faiClass = faiClasses.containsKey(faiClass) ? faiClass : '3';
    this.manufacturer = manufacturer.trim();
    this.model = model.trim();
    this.name = name.trim();
    this.paragliderCategory = paragliderCategory.trim();
    this.hangGliderCategory = hangGliderCategory.trim();
    this.tandem = tandem;
    this.engineType = engineTypes.containsKey(engineType) ? engineType : 'T';
    this.trimSpeedKmh = trimSpeedKmh > 0 ? trimSpeedKmh : 38.0;
    this.goalGlideRatio = goalGlideRatio > 0 ? goalGlideRatio : 9.0;
    _saving = true;
    notifyListeners();

    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kFaiClass, this.faiClass);
      await _setString(sp, _kManufacturer, this.manufacturer);
      await _setString(sp, _kModel, this.model);
      await _setString(sp, _kName, this.name);
      await _setString(sp, _kParagliderCategory, this.paragliderCategory);
      await _setString(sp, _kHangGliderCategory, this.hangGliderCategory);
      await sp.setBool(_kTandem, this.tandem);
      await sp.setString(_kEngineType, this.engineType);
      await sp.setDouble(_kTrimSpeed, this.trimSpeedKmh);
      await sp.setDouble(_kGoalGlideRatio, this.goalGlideRatio);
    } catch (_) {
      // Keep the in-memory values; persistence can be retried later.
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  static String _string(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }

  static Future<void> _setString(
    SharedPreferences sp,
    String key,
    String value,
  ) async {
    if (value.isEmpty) {
      await sp.remove(key);
    } else {
      await sp.setString(key, value);
    }
  }
}
