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
  static const _kSimStartLat = 'pb.debug.simStartLat';
  static const _kSimStartLon = 'pb.debug.simStartLon';
  static const _kSimTaskRoute = 'pb.debug.simTaskRoute';

  /// Default simulated-flight start point (lat, lon). Near Huizhou/Shenzhen,
  /// Guangdong - over Chinese territory so it aligns with the AMap/GCJ-02 tile
  /// sources. Used until the user enters their own coordinates.
  static const double defaultSimStartLat = 22.821567;
  static const double defaultSimStartLon = 114.700167;

  // ── Current values (defaults) ─────────────────────────────────────────────
  bool _simulatorEnabled = false;
  double _simStartLat = defaultSimStartLat;
  double _simStartLon = defaultSimStartLon;
  bool _simulateTaskRoute = false;

  /// Whether the simulated flight-data source may run as a fallback feed.
  /// Defaults to `false` (disabled).
  ///
  /// In release builds this is **always** `false`: the app must never fabricate
  /// flight data for real users, regardless of any persisted preference or
  /// runtime toggle. The simulator is a development-only feed.
  bool get simulatorEnabled => kReleaseMode ? false : _simulatorEnabled;

  /// Latitude of the simulated-flight start point. Defaults to
  /// [defaultSimStartLat].
  double get simStartLat => _simStartLat;

  /// Longitude of the simulated-flight start point. Defaults to
  /// [defaultSimStartLon].
  double get simStartLon => _simStartLon;

  /// When true (and a competition task exists), the simulator flies along the
  /// active task path — takeoff through the turnpoints to goal — instead of a
  /// random drift. Defaults to `false`. Always `false` in release builds.
  bool get simulateTaskRoute => kReleaseMode ? false : _simulateTaskRoute;

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
      _simStartLat = sp.getDouble(_kSimStartLat) ?? _simStartLat;
      _simStartLon = sp.getDouble(_kSimStartLon) ?? _simStartLon;
      _simulateTaskRoute = sp.getBool(_kSimTaskRoute) ?? _simulateTaskRoute;
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

  /// Enables or disables flying the simulator along the active competition
  /// task path, and persists it. No-op in release builds.
  void setSimulateTaskRoute(bool enabled) {
    if (kReleaseMode) return;
    if (_simulateTaskRoute == enabled) return;
    _simulateTaskRoute = enabled;
    _persistBool(_kSimTaskRoute, enabled);
    notifyListeners();
  }

  void _persistBool(String key, bool value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(key, value);
    } catch (_) {}
  }

  /// Sets the custom simulated-flight start point and persists it. Invalid
  /// (out-of-range / non-finite) coordinates are ignored. No-op in release.
  void setSimStartLocation(double lat, double lon) {
    if (kReleaseMode) return;
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return;
    }
    if (_simStartLat == lat && _simStartLon == lon) return;
    _simStartLat = lat;
    _simStartLon = lon;
    _persistDouble(_kSimStartLat, lat);
    _persistDouble(_kSimStartLon, lon);
    notifyListeners();
  }

  void _persistDouble(String key, double value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(key, value);
    } catch (_) {}
  }
}
