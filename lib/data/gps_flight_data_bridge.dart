import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import 'flight_state.dart';
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

  /// The shared flight-session state. While a flight is in progress the GPS
  /// stream is (re)opened in a *background-resilient* configuration so the
  /// track keeps recording with the screen off or the app backgrounded:
  ///   * Android — a location foreground service with a persistent
  ///     notification (holding a wake lock), which is what actually keeps GPS
  ///     and the recording loop alive once the activity is no longer in the
  ///     foreground.
  ///   * iOS — background location updates (`allowBackgroundLocationUpdates`,
  ///     never auto-paused), backed by the `location` UIBackgroundMode and, if
  ///     the user granted it, "Always" authorization.
  /// When no flight is in progress the stream runs in the lightweight
  /// foreground-only configuration to save battery.
  final FlightState flightState;

  StreamSubscription<Position>? _sub;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  bool _attached = false;
  bool _hadFix = false;

  /// Whether the currently-open stream is running in the background-resilient
  /// configuration (foreground service on Android, background updates on iOS).
  /// Tracks [flightState] so a state change only tears down / reopens the
  /// native stream when the required configuration actually changes.
  bool _backgroundMode = false;

  /// Timestamp of the last position we forwarded downstream, used by the
  /// app-level throttle to enforce [updateInterval] on every platform.
  DateTime? _lastEmit;

  GpsFlightDataBridge({
    required this.source,
    this.distanceFilterMeters = 0,
    this.accuracy = LocationAccuracy.bestForNavigation,
    this.updateInterval = const Duration(seconds: 1),
    FlightState? flightState,
  }) : flightState = flightState ?? FlightState.instance;

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

    // React to flight start/stop: entering a flight upgrades the stream to the
    // background-resilient configuration (foreground service / background
    // updates) so the track keeps recording with the screen off, and leaving
    // it drops back to the lightweight foreground-only stream.
    flightState.addListener(_onFlightStateChanged);

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
    // Snapshot the configuration this stream is opened with so a later flight
    // start/stop knows whether the native stream has to be reopened.
    _backgroundMode = flightState.isFlying;
    _sub = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(background: _backgroundMode),
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

  /// Reacts to a flight starting or stopping.
  ///
  /// Starting a flight upgrades the location stream to the background-resilient
  /// configuration (Android foreground service / iOS background updates) so
  /// the track keeps recording with the screen off or the app backgrounded;
  /// stopping drops back to the lightweight foreground-only stream. The native
  /// stream is only torn down and reopened when the required configuration
  /// actually changes, so toggling other flight state (e.g. auto-detect) is a
  /// no-op here.
  void _onFlightStateChanged() {
    // Nothing to do if we never managed to open a stream (unsupported
    // platform, permission denied, or location services off — the
    // service-status watcher will open it later in whatever mode is current).
    if (_sub == null) return;
    if (flightState.isFlying == _backgroundMode) return;
    // Re-request permission best-effort when entering a flight: background /
    // "Always" location is what actually keeps the foreground service and
    // background updates delivering fixes. Fire-and-forget so a slow prompt
    // never blocks the flight from starting.
    if (flightState.isFlying) {
      _ensureBackgroundPermission();
    }
    _startStream();
  }

  /// Best-effort upgrade to background ("Always") location authorization, used
  /// when a flight starts. On both platforms this is what unlocks reliable
  /// screen-off / backgrounded location delivery; if the user declines we keep
  /// running on whatever authorization we already have.
  Future<void> _ensureBackgroundPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse) {
        // Ask to extend to "Always" so background updates continue once the
        // app leaves the foreground. Declining is fine — foreground-service
        // recording still works while the app/session is alive.
        await Geolocator.requestPermission();
      }
    } catch (_) {
      // Ignore: the stream keeps running on the current authorization.
    }
  }

  /// Builds platform-specific location settings so the OS delivers fixes at the
  /// requested [updateInterval] where it can (Android's `intervalDuration`).
  /// The app-level time gate in [_onPosition] enforces the same cadence on
  /// platforms (e.g. iOS) whose native stream is distance-driven rather than
  /// time-driven.
  ///
  /// When [background] is true (a flight is in progress) the stream is
  /// configured to survive the screen turning off and the app being
  /// backgrounded:
  ///   * Android — starts a location foreground service with a persistent,
  ///     non-dismissible notification and holds a wake lock so the CPU (and
  ///     therefore GPS + the recording loop) keeps running.
  ///   * iOS — enables background location updates and disables automatic
  ///     pausing, and shows the background-location indicator. This requires
  ///     the `location` UIBackgroundMode (declared in Info.plist) and, for
  ///     screen-locked delivery, "Always" authorization.
  LocationSettings _buildLocationSettings({required bool background}) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
        intervalDuration: updateInterval,
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: 'ParaBeacon — recording flight',
                notificationText:
                    'Logging your track with the screen off. Tap to return.',
                notificationChannelName: 'Flight recording',
                notificationIcon:
                    AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
                // Keep the CPU alive so location + the recorder keep running
                // while the screen is off, and pin the notification so the
                // service can't be casually swiped away mid-flight.
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
        activityType: ActivityType.airborne,
        // Never let iOS auto-pause updates mid-flight (it would stop the
        // track when the device looks stationary between GPS fixes).
        pauseLocationUpdatesAutomatically: false,
        // Only claim background execution while a flight is in progress so we
        // don't hold the background-location indicator when merely idling.
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
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
    flightState.removeListener(_onFlightStateChanged);
    _sub?.cancel();
    _sub = null;
    _serviceStatusSub?.cancel();
    _serviceStatusSub = null;
  }
}
