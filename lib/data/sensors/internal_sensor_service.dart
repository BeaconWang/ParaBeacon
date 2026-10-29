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
/// - **iOS / Android**: subscribes only when the user enables the internal
///   sensor; iOS defaults to opt-in because Core Motion may show a privacy prompt.
/// - **Other platforms**: [supported] is false and every method is a no-op.
///
/// Availability is discovered at runtime: there is no synchronous "has a
/// barometer" query, so the service subscribes and flips [available] to true
/// on the first sample. If the stream errors (no sensor) it stays false.
class InternalSensorService extends ChangeNotifier {
  InternalSensorService._();
  static final InternalSensorService instance = InternalSensorService._();

  static const _spEnabled = 'pb.internal.sensor.enabled';
  static const _spReferencePressure = 'pb.internal.sensor.reference_pressure_pa';

  /// Sampling cadence for the barometer (~10 Hz) — enough to derive a usable
  /// vario without flooding the data layer.
  static const _samplingPeriod = Duration(milliseconds: 100);

  /// Vario smoothing factor for the exponential moving average applied to the
  /// instantaneous pressure-derived vertical speed (0..1; higher = snappier).
  static const _varioSmoothing = 0.2;

  /// International Standard Atmosphere mean sea-level pressure (Pa). Used as the
  /// default reference until the user calibrates the altimeter.
  static const double standardSeaLevelPa = 101325.0;

  /// Lowest / highest plausible QNH references (Pa), guarding against bogus
  /// calibration inputs (roughly 870–1085 hPa, the span of recorded surface
  /// pressures on Earth).
  static const double _minReferencePa = 87000.0;
  static const double _maxReferencePa = 108500.0;

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
  /// sensor. Persisted. iOS defaults off so Core Motion is accessed only after
  /// the user explicitly enables the feature; other mobile platforms retain the
  /// existing enabled-by-default behavior.
  bool _enabled = defaultTargetPlatform != TargetPlatform.iOS;
  bool get enabled => _enabled;

  /// Whether the internal sensor is currently the preferred, usable feed.
  bool get isActiveFeed => supported && _available && _enabled;

  /// Calibrated reference sea-level pressure (QNH) in pascals used to convert
  /// barometric pressure to altitude. Defaults to the ISA standard until the
  /// user calibrates. Persisted across launches.
  double _referencePressurePa = standardSeaLevelPa;

  /// The reference sea-level pressure (QNH) currently used for the pressure →
  /// altitude conversion, in pascals.
  double get referencePressurePa => _referencePressurePa;

  /// The reference sea-level pressure (QNH) in hectopascals (hPa / millibar) —
  /// the unit typically shown on an altimeter.
  double get referencePressureHpa => _referencePressurePa / 100.0;

  /// Whether the altimeter has been calibrated away from the ISA standard
  /// reference (1013.25 hPa).
  bool get isCalibrated =>
      (_referencePressurePa - standardSeaLevelPa).abs() > 1.0;

  /// The latest raw barometric pressure sample (Pa), or null before the first
  /// reading. Used as the basis for altitude calibration.
  double? get lastPressurePa => _lastPressurePa;

  /// The latest raw barometric pressure sample (hPa), or null before the first
  /// reading.
  double? get lastPressureHpa =>
      _lastPressurePa == null ? null : _lastPressurePa! / 100.0;

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

  /// Latest raw barometric pressure sample (Pa). Retained so calibration can
  /// derive a new reference pressure from the current conditions.
  double? _lastPressurePa;

  /// Starts the barometer subscription (idempotent). Safe on every platform.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final sp = await SharedPreferences.getInstance();
      _enabled = sp.getBool(_spEnabled) ?? _enabled;
      final ref = sp.getDouble(_spReferencePressure);
      if (ref != null && ref.isFinite && _isPlausibleReference(ref)) {
        _referencePressurePa = ref;
      }
    } catch (_) {}

    if (!supported || !_enabled) {
      notifyListeners();
      return;
    }

    _subscribe();
    notifyListeners();
  }

  void _subscribe() {
    if (!supported || !_enabled || _baroSub != null) return;
    try {
      _baroSub = barometerEventStream(samplingPeriod: _samplingPeriod).listen(
        _onBarometer,
        onError: (_) {
          // No barometer on this device (or access was denied): mark unavailable.
          _baroSub = null;
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

  void _stopSubscription() {
    _baroSub?.cancel();
    _baroSub = null;
    _available = false;
    _lastAltitude = null;
    _lastSampleAt = null;
    _lastPressurePa = null;
    _vario = 0.0;
    readings = SensorReadings.empty();
  }

  void _onBarometer(BarometerEvent event) {
    // sensors_plus reports pressure in hPa (millibar).
    final pressureHpa = event.pressure;
    if (!pressureHpa.isFinite || pressureHpa <= 0) return;
    final pressurePa = pressureHpa * 100.0;
    final altitude = _pressureToAltitude(pressurePa);
    _lastPressurePa = pressurePa;

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
    if (_initialized && supported) {
      if (value) {
        _subscribe();
      } else {
        _stopSubscription();
      }
    }
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_spEnabled, value);
    } catch (_) {}
    notifyListeners();
  }

  /// International Standard Atmosphere altitude from pressure, using the
  /// calibrated [referencePressurePa] as the sea-level reference.
  double _pressureToAltitude(double pressurePa) {
    return 44330.0 *
        (1.0 - math.pow(pressurePa / _referencePressurePa, 0.1903).toDouble());
  }

  /// Calibrates the altimeter so that the *current* barometric pressure maps to
  /// a known [altitudeM] (e.g. the elevation of your takeoff, read from a map
  /// or a GPS fix). This back-computes the reference sea-level pressure (QNH)
  /// and persists it.
  ///
  /// Returns false when there is no live pressure sample yet or the resulting
  /// reference pressure is implausible (so the caller can surface an error).
  Future<bool> calibrateToAltitude(double altitudeM) async {
    final pressurePa = _lastPressurePa;
    if (pressurePa == null || !pressurePa.isFinite || pressurePa <= 0) {
      return false;
    }
    if (!altitudeM.isFinite) return false;

    // Invert the ISA formula: solve for the sea-level reference pressure P0
    // such that _pressureToAltitude(pressurePa) == altitudeM.
    //   altitude = 44330 * (1 - (P / P0)^0.1903)
    //   => P0 = P / (1 - altitude / 44330)^(1 / 0.1903)
    final ratio = 1.0 - altitudeM / 44330.0;
    if (ratio <= 0) return false;
    final referencePa = pressurePa / math.pow(ratio, 1.0 / 0.1903).toDouble();
    return _applyReference(referencePa);
  }

  /// Sets the reference sea-level pressure (QNH) directly, in hectopascals.
  ///
  /// Returns false when the value is out of the plausible QNH range.
  Future<bool> setReferencePressureHpa(double hpa) {
    return _applyReference(hpa * 100.0);
  }

  /// Resets the altimeter to the ISA standard reference (1013.25 hPa).
  Future<void> resetCalibration() async {
    await _applyReference(standardSeaLevelPa);
  }

  /// Validates, stores and persists a new reference pressure, then recomputes
  /// the current altitude from the latest pressure sample so the change is
  /// reflected immediately without waiting for the next barometer event.
  Future<bool> _applyReference(double referencePa) async {
    if (!referencePa.isFinite || !_isPlausibleReference(referencePa)) {
      return false;
    }
    if ((referencePa - _referencePressurePa).abs() < 1e-6) return true;

    _referencePressurePa = referencePa;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setDouble(_spReferencePressure, referencePa);
    } catch (_) {}

    _recomputeFromLastPressure();
    notifyListeners();
    return true;
  }

  /// Recomputes the derived altitude from the latest pressure sample under the
  /// current reference pressure and re-emits it. The vario baseline is reset to
  /// the new altitude so recalibration doesn't produce a spurious spike.
  void _recomputeFromLastPressure() {
    final pressurePa = _lastPressurePa;
    if (pressurePa == null) return;
    final altitude = _pressureToAltitude(pressurePa);
    _lastAltitude = altitude;
    _vario = 0.0;
    final now = DateTime.now();
    _lastSampleAt = now;
    readings = SensorReadings(
      pressurePa: pressurePa,
      altitudeM: altitude,
      varioMs: _vario,
      updatedAt: now,
    );
    if (!_readingsCtrl.isClosed) _readingsCtrl.add(readings);
  }

  static bool _isPlausibleReference(double referencePa) =>
      referencePa >= _minReferencePa && referencePa <= _maxReferencePa;

  @override
  void dispose() {
    _baroSub?.cancel();
    _readingsCtrl.close();
    super.dispose();
  }
}
