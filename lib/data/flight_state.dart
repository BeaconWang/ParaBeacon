import 'package:flutter/foundation.dart';

/// Global, app-wide flight session state.
///
/// This is a single shared source of truth for whether a flight is currently
/// in progress. Any number of UI controls (e.g. multiple Flight buttons placed
/// on different dashboard pages) listen to and mutate this same instance, so
/// starting a flight from one button is immediately reflected on all of them.
///
/// It is intentionally a plain in-memory singleton — the flight session is a
/// runtime concept and does not need to survive an app restart.
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

  /// Whether the system should automatically detect take-off / landing and
  /// start / stop the flight on its own. This is a shared, app-wide preference
  /// (toggled from the checkbox next to any Flight button), so every button
  /// reflects the same auto-detect mode.
  bool _autoDetect = false;
  bool get autoDetect => _autoDetect;

  /// Enables or disables automatic flight detection.
  void setAutoDetect(bool value) {
    if (_autoDetect == value) return;
    _autoDetect = value;
    notifyListeners();
  }

  /// Toggles automatic flight detection.
  void toggleAutoDetect() => setAutoDetect(!_autoDetect);

  /// Starts a flight. No-op if one is already in progress.
  void start() {
    if (_isFlying) return;
    _isFlying = true;
    _startedAt = DateTime.now();
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
