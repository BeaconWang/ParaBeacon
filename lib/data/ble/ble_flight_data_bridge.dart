import 'dart:async';

import '../flight_data.dart';
import '../flight_data_source.dart';
import 'ble_sensor_service.dart';
import 'sensor_readings.dart';

/// Bridges the real BLE sensor ([BleSensorService]) into the app-wide
/// [BluetoothSensorFlightDataSource].
///
/// When a physical BLE vario/baro sensor is connected, its decoded readings
/// (vertical speed, altitude, temperature) are forwarded into the flight-data
/// source's *bluetooth-sensor* tier. This makes the connected sensor the source
/// of truth for vertical speed — which in turn drives every control and the
/// vario audio — instead of the built-in development simulator.
///
/// Priority is unchanged: a debug override still wins over the sensor
/// (Debug > Bluetooth sensor). The bridge only fills the bluetooth-sensor tier.
///
/// Platform behavior: on platforms without a real BLE implementation
/// (Windows/desktop/web) the service reports `supported == false` and never
/// emits connection/readings events, so this bridge is effectively a no-op and
/// the simulator keeps running.
class BleFlightDataBridge {
  final BleSensorService service;
  final BluetoothSensorFlightDataSource source;

  StreamSubscription<SensorReadings>? _readingsSub;

  /// Tracks the last connection state so we can react to connect/disconnect
  /// transitions (the service notifies via [ChangeNotifier], not a stream).
  bool _wasConnected = false;

  BleFlightDataBridge({
    required this.source,
    BleSensorService? service,
  }) : service = service ?? BleSensorService.instance;

  bool _attached = false;

  /// Starts listening to the BLE service and forwarding readings.
  ///
  /// Safe to call on unsupported platforms; it simply never receives data.
  void attach() {
    if (_attached) return;
    _attached = true;

    _wasConnected = service.isConnected;

    // React to connect/disconnect transitions.
    service.addListener(_onServiceChanged);

    // Forward every decoded readings snapshot.
    _readingsSub = service.readingsStream.listen(_onReadings);

    // If a sensor is already connected with data, forward it immediately.
    if (service.isConnected) {
      _onReadings(service.readings);
    }
  }

  void _onServiceChanged() {
    final connected = service.isConnected;
    if (connected == _wasConnected) return;
    _wasConnected = connected;

    if (connected) {
      // A real sensor took over: suppress the simulator right away, even before
      // the first readings arrive.
      source.beginRealSensor();
    } else {
      // Sensor dropped: fall back to the simulator so the app keeps running.
      source.endRealSensor(resumeSimulator: true);
    }
  }

  void _onReadings(SensorReadings r) {
    // Only meaningful while a device is connected.
    if (!service.isConnected) return;

    // Vertical speed is the primary field the vario audio consumes.
    final vario = r.varioMs;

    // Build a snapshot preserving previously-known fields, updating only the
    // ones this sensor reports.
    final base = source.rawData;
    final next = base.copyWith(
      verticalSpeed: vario,
      altitude: r.altitudeM,
      hasFix: base.hasFix,
    );

    // ingestSnapshot marks the real sensor active (suppressing the simulator)
    // and pushes the value into the bluetooth-sensor tier.
    source.ingestSnapshot(next);
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    service.removeListener(_onServiceChanged);
    _readingsSub?.cancel();
    _readingsSub = null;
  }
}
