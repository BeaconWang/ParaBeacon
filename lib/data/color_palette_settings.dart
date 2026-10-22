import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorPaletteSettings extends ChangeNotifier {
  ColorPaletteSettings._();

  static final ColorPaletteSettings instance = ColorPaletteSettings._();
  static const String _key = 'pb.colorPalette.count.v1';

  static const List<int> presetColors = [
    0xFF43A047,
    0xFFF44336,
    0xFF9C27B0,
    0xFFFFEB3B,
    0xFF009688,
    0xFFFFFFFF,
    0xFF212121,
    0xFF2196F3,
    0xFFFF9800,
    0xFFE91E63,
    0xFF795548,
  ];

  static const int minColorCount = 3;
  static final int maxColorCount = presetColors.length;
  static const int defaultColorCount = 8;

  int _colorCount = defaultColorCount;
  bool _loaded = false;
  Future<void>? _loading;

  int get colorCount => _colorCount;
  bool get isLoaded => _loaded;

  List<int> get visiblePresetColors =>
      List.unmodifiable(presetColors.take(_colorCount));

  List<int> get pickerColors => [0, ...visiblePresetColors];

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCount = prefs.getInt(_key);
      if (savedCount != null) _setCount(savedCount);
    } catch (_) {
      // Keep the built-in default if local preferences are unavailable.
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
      await prefs.setInt(_key, _colorCount);
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
}
