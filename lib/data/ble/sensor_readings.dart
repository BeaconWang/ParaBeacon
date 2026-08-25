import 'dart:math' as math;
import 'dart:typed_data';

/// Aggregated sensor readings decoded from a connected BLE device.
///
/// Different sensors expose different fields, so every value is nullable and is
/// filled in progressively as data arrives. Adapted from the XCTrack-style
/// external vario data model.
class SensorReadings {
  /// Barometric pressure in pascals (Pa).
  final double? pressurePa;

  /// Altitude in meters (device-reported or derived from pressure).
  final double? altitudeM;

  /// Vertical speed / vario in meters per second.
  final double? varioMs;

  /// Temperature in degrees Celsius.
  final double? temperatureC;

  /// Battery level, 0-100 percent.
  final int? batteryPct;

  /// Heart rate in beats per minute.
  final int? heartRate;

  /// Time of the most recent update.
  final DateTime updatedAt;

  const SensorReadings({
    this.pressurePa,
    this.altitudeM,
    this.varioMs,
    this.temperatureC,
    this.batteryPct,
    this.heartRate,
    required this.updatedAt,
  });

  factory SensorReadings.empty() =>
      SensorReadings(updatedAt: DateTime.fromMillisecondsSinceEpoch(0));

  /// Returns a copy where the non-null fields of [other] override current
  /// values.
  SensorReadings merge(SensorReadings other) {
    return SensorReadings(
      pressurePa: other.pressurePa ?? pressurePa,
      altitudeM: other.altitudeM ?? altitudeM,
      varioMs: other.varioMs ?? varioMs,
      temperatureC: other.temperatureC ?? temperatureC,
      batteryPct: other.batteryPct ?? batteryPct,
      heartRate: other.heartRate ?? heartRate,
      updatedAt: other.updatedAt,
    );
  }

  /// Pressure in hPa, or null when there is no pressure reading.
  double? get pressureHpa => pressurePa == null ? null : pressurePa! / 100.0;

  bool get hasAny =>
      pressurePa != null ||
      altitudeM != null ||
      varioMs != null ||
      temperatureC != null ||
      batteryPct != null ||
      heartRate != null;
}

/// Parser for common sensor payloads.
///
/// Supports two families (matching real flight sensors):
///   * NMEA text sentences (e.g. `$LK8EX1,...`) streamed over a serial-style
///     BLE characteristic.
///   * Standard Bluetooth SIG GATT characteristics (battery, heart rate).
class SensorParser {
  /// Parses a single NMEA text line. Returns `null` when unrecognized.
  static SensorReadings? parseNmeaLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    // Strip leading '$' and trailing "*xx" checksum.
    var body = trimmed.startsWith(r'$') ? trimmed.substring(1) : trimmed;
    final star = body.lastIndexOf('*');
    if (star >= 0) body = body.substring(0, star);

    final parts = body.split(',');
    if (parts.isEmpty) return null;

    switch (parts[0].toUpperCase()) {
      case 'LK8EX1':
        return _parseLk8ex1(parts);
      default:
        return null;
    }
  }

  /// LK8EX1 sentence:
  /// `$LK8EX1,pressure,altitude,vario,temperature,battery,*checksum`
  ///   * pressure    : raw pressure in Pa (99999 = unavailable)
  ///   * altitude    : meters, used only when pressure is unavailable
  ///   * vario       : cm/s
  ///   * temperature : Celsius (99 = unavailable)
  ///   * battery     : 0-100 percent, or 1000+mV for raw voltage
  static SensorReadings? _parseLk8ex1(List<String> p) {
    if (p.length < 6) return null;

    double? pressure = _toDouble(p[1]);
    if (pressure == 99999) pressure = null;

    double? altitude = _toDouble(p[2]);
    if (altitude == 99999) altitude = null;

    // Prefer deriving altitude from pressure when available.
    if (pressure != null) {
      altitude = _pressureToAltitude(pressure);
    }

    double? vario = _toDouble(p[3]);
    vario = vario == null ? null : vario / 100.0; // cm/s -> m/s

    double? temp = _toDouble(p[4]);
    if (temp == 99) temp = null;

    int? battery = _toInt(p[5]);
    if (battery != null && battery >= 1000) {
      // >= 1000 encodes raw millivolts rather than a percentage.
      battery = null;
    }

    return SensorReadings(
      pressurePa: pressure,
      altitudeM: altitude,
      varioMs: vario,
      temperatureC: temp,
      batteryPct: battery,
      updatedAt: DateTime.now(),
    );
  }

  /// Standard GATT battery level (0x2A19): single uint8 percentage byte.
  static SensorReadings? parseBatteryLevel(List<int> data) {
    if (data.isEmpty) return null;
    return SensorReadings(
      batteryPct: data[0].clamp(0, 100),
      updatedAt: DateTime.now(),
    );
  }

  /// Standard GATT heart-rate measurement (0x2A37).
  static SensorReadings? parseHeartRate(List<int> data) {
    if (data.isEmpty) return null;
    final flags = data[0];
    final is16Bit = (flags & 0x01) != 0;
    int hr;
    if (is16Bit) {
      if (data.length < 3) return null;
      hr = data[1] | (data[2] << 8);
    } else {
      if (data.length < 2) return null;
      hr = data[1];
    }
    return SensorReadings(heartRate: hr, updatedAt: DateTime.now());
  }

  /// Best-effort conversion of raw bytes to printable ASCII text.
  static String bytesToText(List<int> data) {
    return String.fromCharCodes(
      data.where((b) => b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127)),
    );
  }

  /// Hex representation of a byte buffer, e.g. `A1 0F 2C`.
  static String bytesToHex(List<int> data) {
    return Uint8List.fromList(data)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  /// Whether a byte stream looks like text (mostly printable ASCII).
  static bool looksLikeText(List<int> value) {
    if (value.isEmpty) return false;
    final printable = value
        .where((b) => b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127))
        .length;
    return printable >= (value.length * 0.8);
  }

  /// International Standard Atmosphere altitude formula (fixed sea level).
  static double _pressureToAltitude(double pressurePa) {
    const seaLevelPa = 101325.0;
    return 44330.0 *
        (1.0 - math.pow(pressurePa / seaLevelPa, 0.1903).toDouble());
  }

  static double? _toDouble(String s) => double.tryParse(s.trim());
  static int? _toInt(String s) => int.tryParse(s.trim());
}
