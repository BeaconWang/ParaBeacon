import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the pilot's most-recently-used equipment names so the flight
/// metadata editor can prefill them for the next flight.
///
/// This is deliberately tiny — a set of free-text strings persisted via
/// [SharedPreferences]. Equipment is stored per-flight on the [FlightTrack]
/// itself; this store only provides sensible defaults for the editor.
class EquipmentStore {
  EquipmentStore._();
  static final EquipmentStore instance = EquipmentStore._();

  static const _kGlider = 'pb.equip.glider';
  static const _kHarness = 'pb.equip.harness';
  static const _kHelmet = 'pb.equip.helmet';

  String? glider;
  String? harness;
  String? helmet;

  bool _loaded = false;

  /// Loads the remembered defaults (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      glider = sp.getString(_kGlider);
      harness = sp.getString(_kHarness);
      helmet = sp.getString(_kHelmet);
    } catch (_) {
      // Best-effort; leave defaults null.
    }
    _loaded = true;
  }

  /// Remembers [glider]/[harness]/[helmet] as the new defaults.
  Future<void> remember({
    String? glider,
    String? harness,
    String? helmet,
  }) async {
    this.glider = glider;
    this.harness = harness;
    this.helmet = helmet;
    try {
      final sp = await SharedPreferences.getInstance();
      await _set(sp, _kGlider, glider);
      await _set(sp, _kHarness, harness);
      await _set(sp, _kHelmet, helmet);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<void> _set(SharedPreferences sp, String key, String? value) async {
    if (value == null || value.isEmpty) {
      await sp.remove(key);
    } else {
      await sp.setString(key, value);
    }
  }
}
