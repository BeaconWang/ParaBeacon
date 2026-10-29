import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerticalSpeedSettings extends ChangeNotifier {
  VerticalSpeedSettings._();

  static final VerticalSpeedSettings instance = VerticalSpeedSettings._();

  static const _averageWindowDecisecondsKey =
      'pb.verticalSpeed.averageWindowDeciseconds';
  static const int minimumWindowDeciseconds = 5;
  static const int maximumWindowDeciseconds = 30;
  static const int defaultWindowDeciseconds = 20;

  int _averageWindowDeciseconds = defaultWindowDeciseconds;
  bool _loaded = false;

  int get averageWindowDeciseconds => _averageWindowDeciseconds;
  double get averageWindowSeconds => _averageWindowDeciseconds / 10.0;
  Duration get verticalSpeedWindow =>
      Duration(milliseconds: _averageWindowDeciseconds * 100);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _averageWindowDeciseconds =
          (preferences.getInt(_averageWindowDecisecondsKey) ??
                  defaultWindowDeciseconds)
              .clamp(minimumWindowDeciseconds, maximumWindowDeciseconds);
    } catch (_) {
      // Keep the safe default when preference storage is unavailable.
    }
    notifyListeners();
  }

  Future<void> setAverageWindowSeconds(double seconds) async {
    if (!seconds.isFinite) return;
    final normalizedDeciseconds = (seconds * 10).round().clamp(
      minimumWindowDeciseconds,
      maximumWindowDeciseconds,
    );
    if (_averageWindowDeciseconds == normalizedDeciseconds) return;
    _averageWindowDeciseconds = normalizedDeciseconds;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(
        _averageWindowDecisecondsKey,
        normalizedDeciseconds,
      );
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
