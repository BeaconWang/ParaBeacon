import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_flight_detector.dart';

/// Global, app-wide flight session state.
///
/// This is a single shared source of truth for whether a flight is currently
/// in progress. Any number of UI controls (e.g. multiple Flight buttons placed
/// on different dashboard pages) listen to and mutate this same instance, so
/// starting a flight from one button is immediately reflected on all of them.
///
/// The active flight session is runtime-only; auto-detection preferences are
/// persisted separately so they can be restored after an app restart.
class FlightState extends ChangeNotifier {
  FlightState._();

  /// The shared singleton used by every Flight button.
  static final FlightState instance = FlightState._();

  bool _isFlying = false;

  /// Whether a flight is currently in progress.
  bool get isFlying => _isFlying;

  /// When the current flight started, or null when not flying.
  DateTime? _startedAt;
  DateTime? get startedAt => _startedAt;

  /// Elapsed time since the flight started (zero when not flying).
  Duration get elapsed {
    final start = _startedAt;
    if (!_isFlying || start == null) return Duration.zero;
    return DateTime.now().difference(start);
  }

  static const _kAutoDetect = 'pb.flight.autoDetect';
  static const _kLandingMode = 'pb.flight.landingMode';
  static const _kTakeoffSpeedKph = 'pb.flight.takeoffSpeedKph';
  static const _kMinimumLandingFlightSeconds =
      'pb.flight.minimumLandingFlightSeconds';
  static const _kLandingSpeedSensitivity = 'pb.flight.landingSpeedSensitivity';

  static const bool defaultAutoDetectEnabled = true;
  static const LandingDetectionMode defaultLandingMode =
      LandingDetectionMode.automatic;
  static const double defaultTakeoffSpeedKph = 6.0;
  static const int defaultMinimumLandingFlightSeconds = 30;
  static const double defaultLandingSpeedSensitivity = 1.0;

  bool _autoDetect = defaultAutoDetectEnabled;
  bool get autoDetect => _autoDetect;

  LandingDetectionMode _landingMode = defaultLandingMode;
  LandingDetectionMode get landingMode => _landingMode;

  double _takeoffSpeedKph = defaultTakeoffSpeedKph;
  double get takeoffSpeedKph => _takeoffSpeedKph;

  int _minimumLandingFlightSeconds = defaultMinimumLandingFlightSeconds;
  int get minimumLandingFlightSeconds => _minimumLandingFlightSeconds;

  double _landingSpeedSensitivity = defaultLandingSpeedSensitivity;
  double get landingSpeedSensitivity => _landingSpeedSensitivity;

  bool _settingsLoaded = false;

  /// Loads persisted detection preferences once; defaults remain active if
  /// storage is unavailable or contains an unknown value.
  Future<void> loadSettings() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoDetect = prefs.getBool(_kAutoDetect) ?? _autoDetect;
      _landingMode = _decodeLandingMode(prefs.getString(_kLandingMode));
      final speed = prefs.getDouble(_kTakeoffSpeedKph);
      if (speed != null && speed.isFinite) {
        _takeoffSpeedKph = speed.clamp(1.0, 20.0).toDouble();
      }
      final minimumLandingSeconds = prefs.getInt(_kMinimumLandingFlightSeconds);
      if (minimumLandingSeconds != null) {
        _minimumLandingFlightSeconds = minimumLandingSeconds.clamp(15, 120);
      }
      final landingSensitivity = prefs.getDouble(_kLandingSpeedSensitivity);
      if (landingSensitivity != null && landingSensitivity.isFinite) {
        _landingSpeedSensitivity = landingSensitivity
            .clamp(0.5, 1.5)
            .toDouble();
      }
    } catch (_) {
      // Keep defaults when preferences are unavailable.
    }
    notifyListeners();
  }

  /// Enables or disables automatic flight detection.
  void setAutoDetect(bool value) {
    if (_autoDetect == value) return;
    _autoDetect = value;
    _persistBool(_kAutoDetect, value);
    notifyListeners();
  }

  void setLandingMode(LandingDetectionMode mode) {
    if (_landingMode == mode) return;
    _landingMode = mode;
    _persistString(_kLandingMode, mode.name);
    notifyListeners();
  }

  void setTakeoffSpeedKph(double speed) {
    if (!speed.isFinite) return;
    final next = speed.clamp(1.0, 20.0).toDouble();
    if (_takeoffSpeedKph == next) return;
    _takeoffSpeedKph = next;
    _persistDouble(_kTakeoffSpeedKph, next);
    notifyListeners();
  }

  void setMinimumLandingFlightSeconds(int seconds) {
    final next = seconds.clamp(15, 120);
    if (_minimumLandingFlightSeconds == next) return;
    _minimumLandingFlightSeconds = next;
    _persistInt(_kMinimumLandingFlightSeconds, next);
    notifyListeners();
  }

  void setLandingSpeedSensitivity(double factor) {
    if (!factor.isFinite) return;
    final next = factor.clamp(0.5, 1.5).toDouble();
    if (_landingSpeedSensitivity == next) return;
    _landingSpeedSensitivity = next;
    _persistDouble(_kLandingSpeedSensitivity, next);
    notifyListeners();
  }

  /// Restores all automatic take-off and landing preferences to their defaults.
  void resetAutoDetectionSettings() {
    setAutoDetect(defaultAutoDetectEnabled);
    setLandingMode(defaultLandingMode);
    setTakeoffSpeedKph(defaultTakeoffSpeedKph);
    setMinimumLandingFlightSeconds(defaultMinimumLandingFlightSeconds);
    setLandingSpeedSensitivity(defaultLandingSpeedSensitivity);
  }

  /// Toggles automatic flight detection.
  void toggleAutoDetect() => setAutoDetect(!_autoDetect);

  static LandingDetectionMode _decodeLandingMode(String? value) {
    return LandingDetectionMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => LandingDetectionMode.automatic,
    );
  }

  void _persistBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  void _persistString(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  void _persistInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (_) {}
  }

  void _persistDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {}
  }

  /// Starts a flight at the GPS point time when available.
  void start({DateTime? at}) {
    if (_isFlying) return;
    _isFlying = true;
    _startedAt = at ?? DateTime.now();
    notifyListeners();
  }

  /// Stops the current flight. No-op if none is in progress.
  void stop() {
    if (!_isFlying) return;
    _isFlying = false;
    _startedAt = null;
    notifyListeners();
  }

  /// Toggles the flight state (start if stopped, stop if flying).
  void toggle() => _isFlying ? stop() : start();
}
