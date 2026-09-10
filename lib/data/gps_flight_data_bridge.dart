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

  /// Desired interval between GPS updates. The platform is asked to deliver
  /// fixes at this cadence (Android), and an app-level time gate enforces it
  /// uniformly across platforms so at most one snapshot is ingested per period.
  final Duration updateInterval;

  StreamSubscription<Position>? _sub;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  bool _attached = false;
  bool _hadFix = false;

  /// Timestamp of the last position we forwarded downstream, used by the
  /// app-level throttle to enforce [updateInterval] on every platform.
  DateTime? _lastEmit;

  GpsFlightDataBridge({
    required this.source,
    this.distanceFilterMeters = 0,
    this.accuracy = LocationAccuracy.bestForNavigation,
    this.updateInterval = const Duration(seconds: 1),
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
    _lastEmit = null;
    _sub = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
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

  /// Builds platform-specific location settings so the OS delivers fixes at the
  /// requested [updateInterval] where it can (Android's `intervalDuration`).
  /// The app-level time gate in [_onPosition] enforces the same cadence on
  /// platforms (e.g. iOS) whose native stream is distance-driven rather than
  /// time-driven.
  LocationSettings _buildLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
        intervalDuration: updateInterval,
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );
  }

  void _onPosition(Position pos) {
    // App-level throttle: forward at most one fix per [updateInterval] so the
    // "once per second" cadence holds regardless of how fast the platform
    // stream emits. Fix-lost transitions are unaffected (handled elsewhere).
    final now = DateTime.now();
    final last = _lastEmit;
    if (last != null && now.difference(last) < updateInterval) {
      return;
    }
    _lastEmit = now;

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
