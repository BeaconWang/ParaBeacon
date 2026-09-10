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
  static const _kFakeChinaLocation = 'pb.debug.fakeChinaLocation';

  // ── Current values (defaults) ─────────────────────────────────────────────
  bool _simulatorEnabled = false;
  bool _fakeChinaLocation = false;

  /// Whether the simulated flight-data source may run as a fallback feed.
  /// Defaults to `false` (disabled).
  ///
  /// In release builds this is **always** `false`: the app must never fabricate
  /// flight data for real users, regardless of any persisted preference or
  /// runtime toggle. The simulator is a development-only feed.
  bool get simulatorEnabled => kReleaseMode ? false : _simulatorEnabled;

  /// Whether the simulated flight data should originate from a location in
  /// China (instead of the default European start point). Only meaningful
  /// while [simulatorEnabled] is true; like the simulator it is a
  /// development-only feed and is always `false` in release builds.
  bool get fakeChinaLocation => kReleaseMode ? false : _fakeChinaLocation;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Loads persisted values (if any). Safe to call multiple times; only the
  /// first call reads storage.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    // In release builds the simulator is force-disabled, so there is nothing
    // to restore — keep the default (off) and skip reading storage.
    if (kReleaseMode) {
      _simulatorEnabled = false;
      notifyListeners();
      return;
    }
    try {
      final sp = await SharedPreferences.getInstance();
      _simulatorEnabled = sp.getBool(_kSimulatorEnabled) ?? _simulatorEnabled;
      _fakeChinaLocation =
          sp.getBool(_kFakeChinaLocation) ?? _fakeChinaLocation;
    } catch (_) {
      // Storage unavailable: keep defaults.
    }
    notifyListeners();
  }

  /// Enables or disables the simulated flight-data source and persists it.
  ///
  /// No-op in release builds — the simulator can never be enabled for real
  /// users.
  void setSimulatorEnabled(bool enabled) {
    if (kReleaseMode) return;
    if (_simulatorEnabled == enabled) return;
    _simulatorEnabled = enabled;
    _persistBool(_kSimulatorEnabled, enabled);
    notifyListeners();
  }

  /// Enables or disables the "fake China location" for the simulator and
  /// persists it.
  ///
  /// No-op in release builds — like the simulator itself this is a
  /// development-only feed.
  void setFakeChinaLocation(bool enabled) {
    if (kReleaseMode) return;
    if (_fakeChinaLocation == enabled) return;
    _fakeChinaLocation = enabled;
    _persistBool(_kFakeChinaLocation, enabled);
    notifyListeners();
  }

  void _persistBool(String key, bool value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(key, value);
    } catch (_) {}
  }
}
