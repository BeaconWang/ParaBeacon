import 'package:shared_preferences/shared_preferences.dart';

import '../controls/map_control.dart' show MapTileSources;
import 'map_source.dart' show defaultMapSourceIdForLocale;

/// Remembers the last map tile-source the user chose in the transient map
/// views that don't have their own persisted settings: the flight-replay
/// basemap and the full-screen map picker (landing-point location picking).
///
/// Each context keeps its own remembered value so, e.g., switching the replay
/// basemap doesn't change what the next landing-point picker opens with. When
/// nothing has been chosen yet (or a stale/unknown id was stored) the value
/// falls back to the locale default (AMap satellite for Chinese users, Google
/// satellite otherwise).
class MapViewSourceSettings {
  MapViewSourceSettings._();

  static final MapViewSourceSettings instance = MapViewSourceSettings._();

  static const _replayKey = 'pb.map.lastSource.replay';
  static const _pickerKey = 'pb.map.lastSource.picker';

  String? _replaySourceId;
  String? _pickerSourceId;
  bool _loaded = false;

  /// Loads the persisted choices once. Safe to call repeatedly.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      _replaySourceId = _sanitize(preferences.getString(_replayKey));
      _pickerSourceId = _sanitize(preferences.getString(_pickerKey));
    } catch (_) {
      // Fall back to the locale default when storage is unavailable.
    }
  }

  /// Only accepts ids that still exist in the catalog so a removed source can't
  /// come back as a dangling selection.
  String? _sanitize(String? id) {
    if (id == null) return null;
    return MapTileSources.all.any((s) => s.id == id) ? id : null;
  }

  /// Last replay basemap, or the locale default when none was chosen.
  String get replaySourceId => _replaySourceId ?? defaultMapSourceIdForLocale();

  /// Last map-picker basemap, or the locale default when none was chosen.
  String get pickerSourceId => _pickerSourceId ?? defaultMapSourceIdForLocale();

  Future<void> setReplaySourceId(String id) =>
      _persist(id, _replayKey, (value) => _replaySourceId = value);

  Future<void> setPickerSourceId(String id) =>
      _persist(id, _pickerKey, (value) => _pickerSourceId = value);

  Future<void> _persist(
    String id,
    String key,
    void Function(String) assign,
  ) async {
    final sanitized = _sanitize(id);
    if (sanitized == null) return;
    assign(sanitized);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, sanitized);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }
}
