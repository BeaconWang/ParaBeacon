import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/sensor_readings.dart';

/// Internal (on-device) barometric sensor service — a single shared instance.
///
/// Many phones/tablets ship a barometric pressure sensor. When present, this
/// service subscribes to the device's barometer, derives a barometric altitude
/// (International Standard Atmosphere) and a smoothed vertical speed (vario)
/// from the pressure stream, and exposes them as [SensorReadings] — the same
/// shape the external BLE sensor produces.
///
/// This lets the app treat the device's own barometer as a first-class sensor
/// feed and, when the user prefers it, use it ahead of an external BLE sensor.
///
/// Platform behavior:
/// - **iOS / Android**: subscribes to the barometer when the hardware has one.
/// - **Other platforms**: [supported] is false and every method is a no-op.
///
/// Availability is discovered at runtime: there is no synchronous "has a
/// barometer" query, so the service subscribes and flips [available] to true
/// on the first sample. If the stream errors (no sensor) it stays false.
class InternalSensorService extends ChangeNotifier {
  InternalSensorService._();
  static final InternalSensorService instance = InternalSensorService._();

  static const _spEnabled = 'pb.internal.sensor.enabled';

  /// Sampling cadence for the barometer (~10 Hz) — enough to derive a usable
  /// vario without flooding the data layer.
  static const _samplingPeriod = Duration(milliseconds: 100);

  /// Vario smoothing factor for the exponential moving average applied to the
  /// instantaneous pressure-derived vertical speed (0..1; higher = snappier).
  static const _varioSmoothing = 0.2;

  /// Only mobile platforms expose a usable barometer stream here.
  bool get supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  /// Whether the device actually produced a barometer reading. False until the
  /// first sample arrives; stays false on hardware without a barometer.
  bool _available = false;
  bool get available => _available;

  /// User preference: prefer the internal barometer over an external BLE
  /// sensor. Persisted. Defaults to true so an available internal sensor is
  /// used first, matching the "use the internal sensor first" behavior.
  bool _enabled = true;
  bool get enabled => _enabled;

  /// Whether the internal sensor is currently the preferred, usable feed.
  bool get isActiveFeed => supported && _available && _enabled;

  /// Latest derived readings (pressure / barometric altitude / vario).
  SensorReadings readings = SensorReadings.empty();

  final StreamController<SensorReadings> _readingsCtrl =
      StreamController<SensorReadings>.broadcast();

  /// Emits whenever a new barometer-derived snapshot is produced.
  Stream<SensorReadings> get readingsStream => _readingsCtrl.stream;

  StreamSubscription<BarometerEvent>? _baroSub;
  bool _initialized = false;

  // Vario integration state.
  double? _lastAltitude;
  DateTime? _lastSampleAt;
  double _vario = 0.0;

  /// Starts the barometer subscription (idempotent). Safe on every platform.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final sp = await SharedPreferences.getInstance();
      _enabled = sp.getBool(_spEnabled) ?? true;
    } catch (_) {}

    if (!supported) {
      notifyListeners();
      return;
    }

    _subscribe();
    notifyListeners();
  }

  void _subscribe() {
    _baroSub?.cancel();
    try {
      _baroSub = barometerEventStream(samplingPeriod: _samplingPeriod).listen(
        _onBarometer,
        onError: (_) {
          // No barometer on this device (or it went away): mark unavailable.
          _available = false;
          notifyListeners();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _available = false;
      notifyListeners();
    }
  }

  void _onBarometer(BarometerEvent event) {
    // sensors_plus reports pressure in hPa (millibar).
    final pressureHpa = event.pressure;
    if (!pressureHpa.isFinite || pressureHpa <= 0) return;
    final pressurePa = pressureHpa * 100.0;
    final altitude = _pressureToAltitude(pressurePa);

    final now = DateTime.now();
    final lastAlt = _lastAltitude;
    final lastAt = _lastSampleAt;
    if (lastAlt != null && lastAt != null) {
      final dt = now.difference(lastAt).inMicroseconds / 1e6;
      if (dt > 0) {
        final instantaneous = (altitude - lastAlt) / dt;
        // Smooth out barometer noise so the vario isn't jittery.
        _vario += (instantaneous - _vario) * _varioSmoothing;
      }
    }
    _lastAltitude = altitude;
    _lastSampleAt = now;

    readings = SensorReadings(
      pressurePa: pressurePa,
      altitudeM: altitude,
      varioMs: _vario,
      updatedAt: now,
    );

    _available = true;
    if (!_readingsCtrl.isClosed) _readingsCtrl.add(readings);
    // Notify so the panel UI reflects live values and (on the first sample)
    // the newly-discovered availability.
    notifyListeners();
  }

  /// Enables/disables preferring the internal sensor. Persisted and broadcast
  /// so the bridge and UI react immediately.
  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_spEnabled, value);
    } catch (_) {}
    notifyListeners();
  }

  /// International Standard Atmosphere altitude from pressure (fixed sea level).
  static double _pressureToAltitude(double pressurePa) {
    const seaLevelPa = 101325.0;
    return 44330.0 *
        (1.0 - math.pow(pressurePa / seaLevelPa, 0.1903).toDouble());
  }

  @override
  void dispose() {
    _baroSub?.cancel();
    _readingsCtrl.close();
    super.dispose();
  }
}
