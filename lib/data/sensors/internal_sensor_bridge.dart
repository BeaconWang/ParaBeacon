import 'dart:async';

import '../raw_flight_data_source.dart';
import '../ble/sensor_readings.dart';
import 'internal_sensor_service.dart';

/// Bridges the device's built-in barometer ([InternalSensorService]) into the
/// app-wide [BluetoothSensorFlightDataSource].
///
/// When the current device has an internal barometric sensor and the user
/// prefers it, its derived readings (vertical speed, barometric altitude,
/// pressure) are forwarded into the source's *internal-sensor* tier — which
/// sits above the BLE sensor tier (Debug > Internal > Bluetooth > Other). This
/// makes the device's own barometer the source of truth for those fields,
/// while a connected BLE sensor still contributes the fields the barometer
/// does not report (temperature, battery, heart rate).
///
/// Platform behavior: on platforms/devices without a barometer the service
/// reports `available == false` and never emits, so this bridge is a no-op and
/// the BLE sensor / simulator keeps driving the feed.
class InternalSensorBridge {
  final InternalSensorService service;
  final BluetoothSensorFlightDataSource source;

  StreamSubscription<SensorReadings>? _readingsSub;

  /// Tracks whether the internal sensor was the active feed last time we
  /// checked, so we can react to it turning on/off (availability discovered or
  /// the user toggling the preference).
  bool _wasActive = false;

  InternalSensorBridge({
    required this.source,
    InternalSensorService? service,
  }) : service = service ?? InternalSensorService.instance;

  bool _attached = false;

  /// Starts listening to the internal sensor and forwarding readings.
  ///
  /// Safe to call on unsupported devices; it simply never receives data.
  void attach() {
    if (_attached) return;
    _attached = true;

    _wasActive = service.isActiveFeed;
    service.addListener(_onServiceChanged);
    _readingsSub = service.readingsStream.listen(_onReadings);

    if (service.isActiveFeed) {
      source.beginInternalSensor();
      _onReadings(service.readings);
    }
  }

  void _onServiceChanged() {
    final active = service.isActiveFeed;
    if (active == _wasActive) return;
    _wasActive = active;

    if (active) {
      // The internal barometer became the preferred, usable feed: take over
      // the vario/altitude/pressure tier immediately.
      source.beginInternalSensor();
    } else {
      // Disabled or unavailable: hand the tier back to the BLE sensor /
      // simulator.
      source.endInternalSensor(resumeSimulator: true);
    }
  }

  void _onReadings(SensorReadings r) {
    if (!service.isActiveFeed) return;
    final vario = r.varioMs;
    final altitude = r.altitudeM;
    final pressureHpa = r.pressureHpa;
    if (vario == null || altitude == null || pressureHpa == null) return;

    source.ingestInternalSnapshot(
      verticalSpeed: vario,
      baroAltitude: altitude,
      pressureHpa: pressureHpa,
      timestamp: r.updatedAt,
    );
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    service.removeListener(_onServiceChanged);
    _readingsSub?.cancel();
    _readingsSub = null;
  }
}
