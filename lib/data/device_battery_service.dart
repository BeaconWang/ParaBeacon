import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

/// Live device (phone/tablet) battery status — a single shared instance.
///
/// Wraps the `battery_plus` plugin behind a [ChangeNotifier] so UI controls
/// (e.g. the Status Line widget) can subscribe and rebuild when the charge
/// level or charging state changes, following the same singleton pattern used
/// by the other app-wide services ([FlightState], [BleSensorService], …).
///
/// Degrades gracefully: on platforms/environments where the battery API is
/// unavailable the values simply stay null / [BatteryState.unknown] and no
/// error is surfaced.
class DeviceBatteryService extends ChangeNotifier {
  DeviceBatteryService._();

  /// The shared singleton.
  static final DeviceBatteryService instance = DeviceBatteryService._();

  final Battery _battery = Battery();

  StreamSubscription<BatteryState>? _stateSub;
  Timer? _levelTimer;
  bool _initialized = false;

  /// Latest battery level 0..100, or null when unknown.
  int? _level;
  int? get level => _level;

  /// Latest charging state.
  BatteryState _state = BatteryState.unknown;
  BatteryState get state => _state;

  /// Whether the device is currently charging (or already full while on power).
  bool get isCharging =>
      _state == BatteryState.charging || _state == BatteryState.full;

  /// Whether we ever obtained a real level reading (so the UI can show `--`
  /// instead of a misleading value before the first poll succeeds).
  bool get hasLevel => _level != null;

  /// Starts listening. Safe to call more than once (no-op after the first).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Charging-state changes arrive via a stream on supported platforms.
    try {
      _stateSub = _battery.onBatteryStateChanged.listen((s) {
        _state = s;
        notifyListeners();
      });
    } catch (_) {
      // Unsupported platform: leave state as unknown.
    }

    // Level is polled: read once now, then refresh periodically. The plugin has
    // no level-change stream, and a coarse poll is plenty for a status readout.
    await _refreshLevel();
    _levelTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshLevel(),
    );
  }

  Future<void> _refreshLevel() async {
    try {
      final value = await _battery.batteryLevel;
      if (value != _level) {
        _level = value.clamp(0, 100);
        notifyListeners();
      }
    } catch (_) {
      // Ignore: keep the last known level (or null).
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _levelTimer?.cancel();
    super.dispose();
  }
}
