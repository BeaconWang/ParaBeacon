import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../l10n/app_localizations.dart';
import '../theme/locale_controller.dart';
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
  /// stream is (re)opened in a *background-resilient* configuration:
  ///   * Android — a location foreground service with a persistent
  ///     notification and wake lock.
  ///   * iOS — background location updates, backed by the `location`
  ///     UIBackgroundMode and, if granted, "Always" authorization.
  /// Android uses its foreground service while a flight is active or automatic
  /// flight detection is enabled. Enabling detection while the app is visible
  /// starts the service before the app backgrounds.
  final FlightState flightState;

  StreamSubscription<Position>? _sub;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  bool _attached = false;
  bool _hadFix = false;
  bool _lastAutoDetect = false;

  /// Whether the currently-open stream is using background-resilient settings.
  bool _backgroundMode = false;

  bool get _requiresBackgroundMode =>
      flightState.isFlying || (Platform.isAndroid && flightState.autoDetect);

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

    // React to flight start/stop and app lifecycle changes so Android can
    // switch to a location foreground service before background throttling
    // pauses the stream. iOS only needs background updates during a flight.
    _lastAutoDetect = flightState.autoDetect;
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
        _watchServiceStatus();
        return;
      }

      if (Platform.isAndroid) {
        await _requestAndroidTrackingPermissions();
      }
      _startStream();
      _watchServiceStatus();
    } catch (_) {
      // Location unavailable: silently give up; the app keeps running on
      // whatever the BLE sensor / simulator is providing.
    }
  }

  Future<void> _requestAndroidTrackingPermissions() async {
    try {
      final notification = await permissions.Permission.notification.status;
      if (!notification.isGranted) {
        await permissions.Permission.notification.request();
      }
    } catch (_) {
      // Notification permission is not required to continue foreground tracking.
    }

    if (!flightState.autoDetect && !flightState.isFlying) return;
    await _requestAndroidBackgroundLocationPermission();
  }

  Future<void> _requestAndroidBackgroundLocationPermission() async {
    try {
      final foregroundLocation = await Geolocator.checkPermission();
      if (foregroundLocation == LocationPermission.denied ||
          foregroundLocation == LocationPermission.deniedForever) {
        return;
      }
      final backgroundLocation = await permissions.Permission.locationAlways.status;
      if (!backgroundLocation.isGranted) {
        await permissions.Permission.locationAlways.request();
      }
    } catch (_) {
      // Keep foreground location available if background permission is declined.
    }
  }

  /// Rechecks permissions after returning from system settings and restores a
  /// missing Android location stream.
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    if (!Platform.isAndroid ||
        state != AppLifecycleState.resumed ||
        _sub != null) {
      return;
    }
    unawaited(_resumeLocationStream());
  }

  Future<void> _resumeLocationStream() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _startStream();
      _watchServiceStatus();
    } catch (_) {
      // The next resume or service-status event can retry.
    }
  }

  void _watchServiceStatus() {
    _serviceStatusSub ??= Geolocator.getServiceStatusStream().listen((
      status,
    ) async {
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
    }, onError: (_) {});
  }

  void _startStream() {
    _sub?.cancel();
    _lastEmit = null;
    // Snapshot the configuration this stream is opened with so flight or app
    // lifecycle changes can reopen it only when the native mode must change.
    _backgroundMode = _requiresBackgroundMode;
    _sub =
        Geolocator.getPositionStream(
          locationSettings: _buildLocationSettings(background: _backgroundMode),
        ).listen(
          _onPosition,
          onError: (_) {
            // Transient stream error: cancel; the service-status watcher (or a
            // subsequent attach()) will restart it.
            _sub?.cancel();
            _sub = null;
            if (_hadFix) {
              _hadFix = false;
              source.reportGpsFixLost();
            }
          },
        );
  }

  /// Reacts to a flight starting or stopping.
  ///
  /// Starting a flight upgrades the stream to background-resilient settings.
  /// Stopping drops back to foreground-only settings only when the Android app
  /// itself is still in the foreground. Other flight-state changes are a no-op.
  void _onFlightStateChanged() {
    final autoDetectEnabled = flightState.autoDetect;
    final autoDetectJustEnabled = autoDetectEnabled && !_lastAutoDetect;
    _lastAutoDetect = autoDetectEnabled;
    if (Platform.isAndroid && autoDetectJustEnabled) {
      unawaited(_requestAndroidBackgroundLocationPermission());
    }

    // Nothing to do if we never managed to open a stream (unsupported
    // platform, permission denied, or location services off — the
    // service-status watcher will open it later in whatever mode is current).
    if (_sub == null) return;
    if (_requiresBackgroundMode == _backgroundMode) return;
    if (flightState.isFlying && Platform.isIOS) {
      _ensureBackgroundPermission();
    }
    _startStream();
  }

  /// Best-effort iOS upgrade to background ("Always") location authorization
  /// when a flight starts. If the user declines, keep running with the current
  /// authorization.
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
  /// When [background] is true (a flight is in progress, or Android automatic
  /// flight detection is enabled) the stream uses background-resilient settings:
  ///   * Android — starts a location foreground service with a persistent,
  ///     non-dismissible notification and holds a wake lock so the CPU (and
  ///     therefore GPS + the recording loop) keeps running.
  ///   * iOS — enables background location updates and disables automatic
  ///     pausing, and shows the background-location indicator. This requires
  ///     the `location` UIBackgroundMode (declared in Info.plist) and, for
  ///     screen-locked delivery, "Always" authorization.
  AppLocalizations _notificationLocalizations() {
    final selectedLocale = LocaleController.instance.current.locale;
    final locale =
        selectedLocale ??
        basicLocaleListResolution(
          WidgetsBinding.instance.platformDispatcher.locales,
          AppLocalizations.supportedLocales,
        );
    return lookupAppLocalizations(locale);
  }

  LocationSettings _buildLocationSettings({required bool background}) {
    if (Platform.isAndroid) {
      final l10n = _notificationLocalizations();
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
        intervalDuration: updateInterval,
        // Report NMEA-derived mean-sea-level altitude (EGM2008) rather than the
        // raw WGS84 geoidal height, so the GPS altitude matches iOS, the app's
        // "meters above mean sea level" definition, and external tools like
        // "GPS Test". Falls back to WGS84 automatically when the device emits
        // no `$GPGGA` NMEA altitude.
        useMSLAltitude: true,
        foregroundNotificationConfig: background
            ? ForegroundNotificationConfig(
                notificationTitle: l10n.gpsNotificationTitle,
                notificationText: l10n.gpsNotificationText,
                notificationChannelName: l10n.gpsNotificationChannel,
                notificationIcon: AndroidResource(
                  name: 'ic_launcher',
                  defType: 'mipmap',
                ),
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
    // geolocator's Android `AndroidPosition` never forwards the platform
    // `hasAltitude` / `hasSpeed` flags to the base `Position`, so they are
    // ALWAYS false on Android. Gating on them therefore silently discards a
    // perfectly good GPS altitude (the "GPS Altitude" control just shows `--`)
    // and ground speed. Treat a value as present when the platform flag says
    // so OR when the reported value is a real measurement — i.e. finite and not
    // the `0.0` "unavailable" placeholder geolocator documents.
    final hasGpsAltitude =
        pos.altitude.isFinite && (pos.hasAltitude || pos.altitude != 0.0);
    final hasGpsSpeed =
        pos.speed.isFinite && pos.speed >= 0 && (pos.hasSpeed || pos.speed > 0);
    // geolocator only surfaces the GNSS satellite count on Android, where each
    // fix is an `AndroidPosition`. Prefer the satellites actually used in the
    // fix, falling back to the total count; both default to 0.0 when the
    // platform could not determine them, in which case we leave it null so the
    // data monitor shows "—" instead of a bogus zero.
    int? satellites;
    if (pos is AndroidPosition) {
      final used = pos.satellitesUsedInFix;
      final total = pos.satelliteCount;
      final value = used > 0 ? used : total;
      if (value.isFinite && value > 0) satellites = value.round();
    }
    source.ingestGpsSnapshot(
      latitude: pos.latitude,
      longitude: pos.longitude,
      // Geolocator: heading is degrees relative to true north; negative /
      // NaN when unknown (e.g. stationary). Fall back to 0 in that case so
      // downstream consumers get a valid angle.
      heading: (pos.heading.isFinite && pos.heading >= 0) ? pos.heading : 0.0,
      hasHeading: pos.heading.isFinite && pos.heading >= 0,
      // Geolocator reports speed in m/s; the app-wide model uses km/h.
      groundSpeedKmh: hasGpsSpeed ? pos.speed * 3.6 : 0.0,
      hasGroundSpeed: hasGpsSpeed,
      gpsAltitude: hasGpsAltitude ? pos.altitude : null,
      gpsAccuracy: pos.accuracy.isFinite ? pos.accuracy : null,
      satellites: satellites,
      timestamp: pos.timestamp,
      isMockLocation: pos.isMocked,
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
