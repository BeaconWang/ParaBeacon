import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Known GATT UUIDs plus the custom sensor-service UUIDs this app can decode.
///
/// Helper methods normalize the 16-bit / 128-bit forms so they compare equal
/// regardless of how the platform reports them.
class BleUuids {
  const BleUuids._();

  // Standard Bluetooth SIG services / characteristics (16-bit short form).
  static final Guid batteryService = Guid('180f');
  static final Guid batteryLevel = Guid('2a19');

  static final Guid heartRateService = Guid('180d');
  static final Guid heartRateMeasurement = Guid('2a37');

  static final Guid deviceInfoService = Guid('180a');

  // Custom serial-style vario service (streams NMEA sentences as text).
  static final Guid varioService = Guid('aba27100-143b-4b81-a444-edcd0000f010');
  static final Guid varioNotify = Guid('aba27100-143b-4b81-a444-edcd0000f022');
  static final Guid varioWrite = Guid('aba27100-143b-4b81-a444-edcd0000f023');

  // Nordic UART Service (very common for serial-passthrough BLE sensors).
  static final Guid nusService = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid nusTx = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid nusRx = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');

  /// Whether two GUIDs point at the same UUID (tolerating 16-bit vs 128-bit).
  static bool same(Guid a, Guid b) => _canon(a) == _canon(b);

  static String _canon(Guid g) {
    final s = g.str.toLowerCase().replaceAll('-', '');
    // Expand a 16-bit short form to the full 128-bit base UUID for comparison.
    if (s.length == 4) {
      return '0000${s}00001000800000805f9b34fb';
    }
    if (s.length == 8) {
      return '${s}00001000800000805f9b34fb';
    }
    return s;
  }
}
