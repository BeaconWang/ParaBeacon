import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app-wide colors for the Vario bar's vertical-speed key points.
class VarioColorSettings extends ChangeNotifier {
  VarioColorSettings._();

  static final VarioColorSettings instance = VarioColorSettings._();

  static const List<String> colorKeys = [
    'varioColorMinus10',
    'varioColorMinus7',
    'varioColorMinus3',
    'varioColorZero',
    'varioColorPlus3',
    'varioColorPlus7',
    'varioColorPlus10',
  ];

  static const List<int> defaultColors = [
    0xFF02060D, // -10 m/s  Abyssal Blue-Black
    0xFF2979FF, //  -7 m/s  Cobalt Blue
    0xFF00B0FF, //  -3 m/s  Ice Blue
    0xFFFFFFFF, //   0 m/s  Pure White
    0xFF00E676, //  +3 m/s  Vivid Lime Green
    0xFFFF3D00, //  +7 m/s  Flame Orange-Red
    0xFF2B0000, // +10 m/s  Pitch Black-Red
  ];

  static const String _preferencePrefix = 'pb.varioColors.keyPoint.v1.';

  final List<int> _colors = List<int>.of(defaultColors);
  bool _loaded = false;
  Future<void>? _loading;

  List<int> get colors => List<int>.unmodifiable(_colors);

  int colorAt(int index) => _colors[index];

  static int? indexForKey(String key) {
    final index = colorKeys.indexOf(key);
    return index < 0 ? null : index;
  }

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      for (var index = 0; index < colorKeys.length; index++) {
        final saved = preferences.getInt(
          '$_preferencePrefix${colorKeys[index]}',
        );
        if (saved != null && saved >= 0 && saved <= 0xFFFFFFFF) {
          _colors[index] = 0xFF000000 | (saved & 0x00FFFFFF);
        }
      }
    } catch (_) {
      // Keep the built-in colors when local preferences are unavailable.
    } finally {
      _loaded = true;
      _loading = null;
      notifyListeners();
    }
  }

  Future<void> setColor(int index, int argb) async {
    if (index < 0 || index >= colorKeys.length) return;
    await load();
    final color = 0xFF000000 | (argb & 0x00FFFFFF);
    if (_colors[index] == color) return;
    _colors[index] = color;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt('$_preferencePrefix${colorKeys[index]}', color);
    } catch (_) {
      // Keep the in-memory choice active when preference storage is unavailable.
    }
  }
}
