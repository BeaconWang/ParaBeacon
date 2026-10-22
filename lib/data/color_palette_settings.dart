import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ColorPalettePreset {
  const ColorPalettePreset({
    required this.id,
    required this.hueOffset,
    required this.saturation,
    required this.lightness,
  });

  final String id;
  final double hueOffset;
  final double saturation;
  final double lightness;

  static const List<int> neutralColors = [0xFF000000, 0xFFFFFFFF, 0xFF808080];

  List<int> colorsForCount(int count) {
    final safeCount = count
        .clamp(1, ColorPaletteSettings.maxColorCount)
        .toInt();

    List<int> hues(int hueCount) => List<int>.generate(hueCount, (index) {
      final hue = (hueOffset + 360 * index / hueCount) % 360;
      return _hslColor(hue, saturation, lightness);
    }, growable: false);

    if (safeCount <= 3) return hues(safeCount);
    if (safeCount <= 14) {
      return [...hues(safeCount - neutralColors.length), ...neutralColors];
    }

    final extraToneCount = safeCount - 14;
    return [
      ...hues(11),
      ...neutralColors,
      if (extraToneCount >= 1) _hslColor(hueOffset, saturation, 0.50),
      if (extraToneCount >= 2) _hslColor(hueOffset, saturation, 0.75),
    ];
  }

  int _hslColor(double hue, double saturation, double lightness) =>
      HSLColor.fromAHSL(1, hue, saturation, lightness).toColor().toARGB32();
}

class ColorPaletteSettings extends ChangeNotifier {
  ColorPaletteSettings._();

  static final ColorPaletteSettings instance = ColorPaletteSettings._();
  static const String _countKey = 'pb.colorPalette.count.v1';
  static const String _schemeKey = 'pb.colorPalette.scheme.v1';

  static const List<ColorPalettePreset> presets = [
    ColorPalettePreset(
      id: 'high-saturation',
      hueOffset: 0,
      saturation: 0.75,
      lightness: 0.60,
    ),
    ColorPalettePreset(
      id: 'macaron',
      hueOffset: 0,
      saturation: 0.48,
      lightness: 0.70,
    ),
    ColorPalettePreset(
      id: 'morandi',
      hueOffset: 18,
      saturation: 0.42,
      lightness: 0.64,
    ),
    ColorPalettePreset(
      id: 'earth',
      hueOffset: 36,
      saturation: 0.55,
      lightness: 0.58,
    ),
    ColorPalettePreset(
      id: 'dark-tech',
      hueOffset: 54,
      saturation: 0.62,
      lightness: 0.53,
    ),
    ColorPalettePreset(
      id: 'maldives-ocean',
      hueOffset: 72,
      saturation: 0.60,
      lightness: 0.66,
    ),
    ColorPalettePreset(
      id: 'forest',
      hueOffset: 90,
      saturation: 0.52,
      lightness: 0.56,
    ),
    ColorPalettePreset(
      id: 'sunset',
      hueOffset: 108,
      saturation: 0.65,
      lightness: 0.62,
    ),
    ColorPalettePreset(
      id: 'lavender',
      hueOffset: 126,
      saturation: 0.45,
      lightness: 0.73,
    ),
    ColorPalettePreset(
      id: 'nordic',
      hueOffset: 144,
      saturation: 0.42,
      lightness: 0.72,
    ),
    ColorPalettePreset(
      id: 'desert',
      hueOffset: 162,
      saturation: 0.55,
      lightness: 0.60,
    ),
    ColorPalettePreset(
      id: 'sakura',
      hueOffset: 180,
      saturation: 0.50,
      lightness: 0.68,
    ),
    ColorPalettePreset(
      id: 'glacier',
      hueOffset: 198,
      saturation: 0.52,
      lightness: 0.65,
    ),
  ];

  static const int minColorCount = 3;
  static const int maxColorCount = 16;
  static const int defaultColorCount = 6;
  static const String defaultSchemeId = 'high-saturation';

  int _colorCount = defaultColorCount;
  String _schemeId = defaultSchemeId;
  bool _loaded = false;
  Future<void>? _loading;

  int get colorCount => _colorCount;
  String get schemeId => _schemeId;
  bool get isLoaded => _loaded;

  ColorPalettePreset get selectedPreset =>
      presets.firstWhere((preset) => preset.id == _schemeId);

  List<int> get visiblePresetColors =>
      List.unmodifiable(selectedPreset.colorsForCount(_colorCount));

  List<int> get pickerColors => [0, ...visiblePresetColors];

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCount = prefs.getInt(_countKey);
      final savedSchemeId = prefs.getString(_schemeKey);
      if (savedCount != null) _setCount(savedCount);
      if (savedSchemeId != null) _setScheme(savedSchemeId);
    } catch (_) {
      // Keep the built-in defaults if local preferences are unavailable.
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  void previewColorCount(int count) => _setCount(count);

  Future<void> setColorCount(int count) async {
    _setCount(count);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_countKey, _colorCount);
    } catch (_) {
      // Keep the selected value in memory if persistence is unavailable.
    }
  }

  void previewScheme(String id) => _setScheme(id);

  Future<void> setScheme(String id) async {
    _setScheme(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_schemeKey, _schemeId);
    } catch (_) {
      // Keep the selected value in memory if persistence is unavailable.
    }
  }

  void _setCount(int count) {
    final normalized = count.clamp(minColorCount, maxColorCount).toInt();
    if (_colorCount == normalized) return;
    _colorCount = normalized;
    notifyListeners();
  }

  void _setScheme(String id) {
    if (!presets.any((preset) => preset.id == id) || _schemeId == id) return;
    _schemeId = id;
    notifyListeners();
  }
}
