import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted developer/debug preferences.
///
/// These are toggles that only matter during development or bench testing and
/// are exposed under a dedicated "Debug" section in Preferences.
///
/// Currently owns [simulatorEnabled], which controls whether the built-in
/// [SimulatedFlightDataSource] is used as a fallback feed when no real BLE
/// sensor is connected. It defaults to **off** so the app does not fabricate
/// flight data unless a developer explicitly opts in.
class DebugSettings extends ChangeNotifier {
  DebugSettings._();

  /// Shared singleton.
  static final DebugSettings instance = DebugSettings._();

  // ── Persistence keys ──────────────────────────────────────────────────────
  static const _kSimulatorEnabled = 'pb.debug.simulatorEnabled';

  // ── Current values (defaults) ─────────────────────────────────────────────
  bool _simulatorEnabled = false;

  /// Whether the simulated flight-data source may run as a fallback feed.
  /// Defaults to `false` (disabled).
  bool get simulatorEnabled => _simulatorEnabled;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Loads persisted values (if any). Safe to call multiple times; only the
  /// first call reads storage.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      _simulatorEnabled = sp.getBool(_kSimulatorEnabled) ?? _simulatorEnabled;
    } catch (_) {
      // Storage unavailable: keep defaults.
    }
    notifyListeners();
  }

  /// Enables or disables the simulated flight-data source and persists it.
  void setSimulatorEnabled(bool enabled) {
    if (_simulatorEnabled == enabled) return;
    _simulatorEnabled = enabled;
    _persistBool(_kSimulatorEnabled, enabled);
    notifyListeners();
  }

  void _persistBool(String key, bool value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(key, value);
    } catch (_) {}
  }
}
