import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import 'raw_flight_data_source.dart';

/// Continuously streams the device GPS into the app-wide flight-data source.
///
/// This is the counterpart of [BleFlightDataBridge] for device GPS: whenever
/// the platform has a location fix, the latitude/longitude/heading/ground
/// speed/GPS altitude/fix state are pushed into the *other* (lowest) raw tier
/// of [BluetoothSensorFlightDataSource] via
/// [BluetoothSensorFlightDataSource.ingestGpsSnapshot].
///
/// The result is that every consumer of the unified [FlightDataProvider]
/// (map, recorder, data-value controls, etc.) sees the real device position
/// without each control having to open its own geolocator stream.
///
/// Priority stays intact:
///   * `debugOverride > bluetoothSensor > other`
///   * BLE-owned fields (verticalSpeed, baro altitude, pressure, temperature,
///     battery, HR) are NEVER touched by GPS.
///   * When the built-in flight-data simulator is running, GPS is suppressed
///     so the simulated position isn't fought over (matches the map's
///     `sim > gps > flight-data` priority).
///
/// Platform behavior: on desktop/web the geolocator either isn't meaningful or
/// prompts an unwanted dialog, so the bridge no-ops on anything that isn't
/// Android or iOS.
class GpsFlightDataBridge {
  final BluetoothSensorFlightDataSource source;

  /// Minimum movement (meters) between emitted positions; 0 = every update.
  /// Kept at 0 so continuous updates flow through even while stationary —
  /// this keeps the timestamp and heading current for the map/recorder.
  final int distanceFilterMeters;

  /// Geolocator accuracy level. Defaults to the highest that phones support so
  /// the map cursor and recorded track are as tight as possible.
  final LocationAccuracy accuracy;

  StreamSubscription<Position>? _sub;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  bool _attached = false;
  bool _hadFix = false;

  GpsFlightDataBridge({
    required this.source,
    this.distanceFilterMeters = 0,
    this.accuracy = LocationAccuracy.bestForNavigation,
  });

  /// Starts requesting the location permission (once) and, on success, opens
  /// a continuous position stream.
  ///
  /// Safe to call on unsupported platforms; it simply never emits.
  Future<void> attach() async {
    if (_attached) return;
    _attached = true;

    // GPS only really exists on Android / iOS; skip on desktop/web to avoid a
    // spurious permission dialog and keep the bridge a true no-op there.
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Watch for the user turning location services back on later so we
        // can start streaming without them having to restart the app.
        _watchServiceStatus();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _startStream();
      _watchServiceStatus();
    } catch (_) {
      // Location unavailable: silently give up; the app keeps running on
      // whatever the BLE sensor / simulator is providing.
    }
  }

  void _watchServiceStatus() {
    _serviceStatusSub ??= Geolocator.getServiceStatusStream().listen(
      (status) async {
        if (status == ServiceStatus.enabled && _sub == null) {
          // User re-enabled location: (re)check permission and start streaming.
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            return;
          }
          _startStream();
        } else if (status == ServiceStatus.disabled) {
          // Services went away: mark the fix lost and stop the stream (the
          // service-status listener will restart it when they come back).
          _sub?.cancel();
          _sub = null;
          if (_hadFix) {
            _hadFix = false;
            source.reportGpsFixLost();
          }
        }
      },
      onError: (_) {},
    );
  }

  void _startStream() {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    ).listen(_onPosition, onError: (_) {
      // Transient stream error: cancel; the service-status watcher (or a
      // subsequent attach()) will restart it.
      _sub?.cancel();
      _sub = null;
      if (_hadFix) {
        _hadFix = false;
        source.reportGpsFixLost();
      }
    });
  }

  void _onPosition(Position pos) {
    _hadFix = true;
    source.ingestGpsSnapshot(
      latitude: pos.latitude,
      longitude: pos.longitude,
      // Geolocator: heading is degrees relative to true north; negative /
      // NaN when unknown (e.g. stationary). Fall back to 0 in that case so
      // downstream consumers get a valid angle.
      heading: (pos.heading.isFinite && pos.heading >= 0) ? pos.heading : 0.0,
      // Geolocator reports speed in m/s; the app-wide model uses km/h.
      groundSpeedKmh:
          (pos.speed.isFinite && pos.speed >= 0) ? pos.speed * 3.6 : 0.0,
      gpsAltitude: pos.altitude.isFinite ? pos.altitude : null,
      gpsAccuracy: pos.accuracy.isFinite ? pos.accuracy : null,
      timestamp: pos.timestamp,
    );
  }

  void dispose() {
    if (!_attached) return;
    _attached = false;
    _sub?.cancel();
    _sub = null;
    _serviceStatusSub?.cancel();
    _serviceStatusSub = null;
  }
}
