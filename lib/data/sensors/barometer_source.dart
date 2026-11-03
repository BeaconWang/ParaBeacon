import 'package:flutter/foundation.dart';

import '../ble/ble_sensor_service.dart';
import 'internal_sensor_service.dart';

/// Which barometer is currently feeding the altimeter.
enum BarometerSourceKind { none, internal, bluetooth }

/// Unifies the device's internal barometer and an external BLE barometer into a
/// single "which barometer is giving us pressure right now" view, used by the
/// Altimeter/QNH settings.
///
/// The QNH reference pressure itself lives in [InternalSensorService] and is a
/// shared, source-independent atmospheric reference, so altitudes derived from
/// either source stay consistent.
@immutable
class BarometerSource {
  const BarometerSource({
    required this.kind,
    required this.pressurePa,
    required this.deviceName,
  });

  final BarometerSourceKind kind;
  final double? pressurePa;

  /// Display name of the external device when [kind] is bluetooth.
  final String? deviceName;

  double? get pressureHpa => pressurePa == null ? null : pressurePa! / 100.0;

  bool get hasPressure =>
      pressurePa != null && pressurePa!.isFinite && pressurePa! > 0;

  bool get isNone => kind == BarometerSourceKind.none;

  /// Combines both backing services so UIs repaint when either changes.
  static Listenable get listenable => Listenable.merge([
    InternalSensorService.instance,
    BleSensorService.instance,
  ]);

  static bool _validPressure(double? p) =>
      p != null && p.isFinite && p > 0;

  /// Whether any barometric source exists right now: the device barometer has
  /// been detected (sticky), or a BLE sensor is connected and reporting
  /// pressure. Used to decide whether to show the altimeter settings at all.
  static bool get isAvailable {
    final internal = InternalSensorService.instance;
    if (internal.hasBarometer) return true;
    final ble = BleSensorService.instance;
    return ble.isConnected && _validPressure(ble.readings.pressurePa);
  }

  /// Picks the active source: the device barometer when it is the preferred
  /// active feed, otherwise a connected BLE sensor reporting pressure,
  /// otherwise the device barometer if it has produced a reading, otherwise
  /// none.
  static BarometerSource resolve() {
    final internal = InternalSensorService.instance;
    final ble = BleSensorService.instance;

    final internalPressure = internal.lastPressurePa;
    final internalHasPressure =
        internal.available && _validPressure(internalPressure);

    final blePressure =
        ble.isConnected ? ble.readings.pressurePa : null;
    final bleHasPressure = _validPressure(blePressure);

    // Prefer the device barometer when the user has it as the active feed.
    if (internal.isActiveFeed && internalHasPressure) {
      return BarometerSource(
        kind: BarometerSourceKind.internal,
        pressurePa: internalPressure,
        deviceName: null,
      );
    }
    if (bleHasPressure) {
      return BarometerSource(
        kind: BarometerSourceKind.bluetooth,
        pressurePa: blePressure,
        deviceName: ble.selectedName,
      );
    }
    if (internalHasPressure) {
      return BarometerSource(
        kind: BarometerSourceKind.internal,
        pressurePa: internalPressure,
        deviceName: null,
      );
    }
    // No live pressure. Still report the kind of hardware that exists so the
    // UI can show a meaningful "waiting for data" state.
    if (internal.hasBarometer) {
      return const BarometerSource(
        kind: BarometerSourceKind.internal,
        pressurePa: null,
        deviceName: null,
      );
    }
    if (ble.isConnected) {
      return BarometerSource(
        kind: BarometerSourceKind.bluetooth,
        pressurePa: null,
        deviceName: ble.selectedName,
      );
    }
    return const BarometerSource(
      kind: BarometerSourceKind.none,
      pressurePa: null,
      deviceName: null,
    );
  }
}
