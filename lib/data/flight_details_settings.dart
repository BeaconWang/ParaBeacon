import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlightDetailsSettings extends ChangeNotifier {
  FlightDetailsSettings._();

  static final FlightDetailsSettings instance = FlightDetailsSettings._();

  static const _filterOutliersKey = 'pb.flightDetails.filterVarioOutliers';
  static const _madMultiplierKey = 'pb.flightDetails.outlierMadMultiplier';
  static const _windowSecondsKey = 'pb.flightDetails.outlierWindowSeconds';
  static const _maximumRateKey = 'pb.flightDetails.maximumVerticalSpeed';

  bool _filterVarioOutliers = true;
  double _madMultiplier = 4.0;
  int _windowSeconds = 30;
  double _maximumVerticalSpeedMs = 20.0;
  bool _loaded = false;

  bool get filterVarioOutliers => _filterVarioOutliers;
  double get madMultiplier => _madMultiplier;
  int get windowSeconds => _windowSeconds;
  double get maximumVerticalSpeedMs => _maximumVerticalSpeedMs;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _filterVarioOutliers = preferences.getBool(_filterOutliersKey) ?? true;
      _madMultiplier = (preferences.getDouble(_madMultiplierKey) ?? 4.0).clamp(
        2.0,
        8.0,
      );
      _windowSeconds = (preferences.getInt(_windowSecondsKey) ?? 30).clamp(
        10,
        120,
      );
      _maximumVerticalSpeedMs = (preferences.getDouble(_maximumRateKey) ?? 20.0)
          .clamp(5.0, 40.0);
    } catch (_) {
      // Keep the safe defaults when preference storage is unavailable.
    }
    notifyListeners();
  }

  Future<void> setFilterVarioOutliers(bool enabled) async {
    if (_filterVarioOutliers == enabled) return;
    _filterVarioOutliers = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_filterOutliersKey, enabled);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }

  Future<void> setMadMultiplier(double value) async {
    final normalized = value.clamp(2.0, 8.0).toDouble();
    if (_madMultiplier == normalized) return;
    _madMultiplier = normalized;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_madMultiplierKey, normalized);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }

  Future<void> setWindowSeconds(double value) async {
    final normalized = value.round().clamp(10, 120);
    if (_windowSeconds == normalized) return;
    _windowSeconds = normalized;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_windowSecondsKey, normalized);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }

  Future<void> setMaximumVerticalSpeedMs(double value) async {
    final normalized = value.clamp(5.0, 40.0).toDouble();
    if (_maximumVerticalSpeedMs == normalized) return;
    _maximumVerticalSpeedMs = normalized;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_maximumRateKey, normalized);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
