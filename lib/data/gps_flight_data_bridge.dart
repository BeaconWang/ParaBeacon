import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;

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
  /// Android uses its foreground service while a flight is active, or while
  /// the app is backgrounded and automatic flight detection is enabled. This
  /// keeps background GPS flowing for recording and takeoff/landing detection.
  final FlightState flightState;

  StreamSubscription<Position>? _sub;
  StreamSubscription<ServiceStatus>? _serviceStatusSub;
  Timer? _restartTimer;

  bool _attached = false;
  bool _hadFix = false;
  bool _batteryOptimizationPromptAttempted = false;
  int _streamGeneration = 0;
  int _restartAttempt = 0;

  /// Whether the currently-open stream is using background-resilient settings.
  bool _backgroundMode = false;
  bool _appIsBackgrounded = false;

  bool get _requiresBackgroundMode =>
      flightState.isFlying ||
      (Platform.isAndroid && _appIsBackgrounded && flightState.autoDetect);

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

  /// Updates the Android location service when the app leaves or returns to the
  /// foreground. `inactive` is included so the service starts before Android
  /// applies background location throttling.
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    if (!Platform.isAndroid) return;

    final appIsBackgrounded = state != AppLifecycleState.resumed;
    final lifecycleChanged = _appIsBackgrounded != appIsBackgrounded;
    _appIsBackgrounded = appIsBackgrounded;

    if (state == AppLifecycleState.resumed && flightState.isFlying) {
      unawaited(_requestBatteryOptimizationExemption());
    }
    if (state == AppLifecycleState.resumed && _requiresBackgroundMode) {
      // Recreate the location FGS on return; some OEMs stop the plugin service
      // while the UI is paused without closing the Dart stream cleanly.
      _startStream();
    } else if (_sub != null &&
        lifecycleChanged &&
        _requiresBackgroundMode != _backgroundMode) {
      _startStream();
    } else if (state == AppLifecycleState.resumed && _sub == null) {
      unawaited(_reopenStreamIfAvailable());
    }
  }

  void _watchServiceStatus() {
    _serviceStatusSub ??= Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled) {
        unawaited(_reopenStreamIfAvailable());
      } else if (status == ServiceStatus.disabled) {
        _streamGeneration++;
        _restartTimer?.cancel();
        _restartTimer = null;
        final sub = _sub;
        _sub = null;
        if (sub != null) unawaited(sub.cancel());
        if (_hadFix) {
          _hadFix = false;
          source.reportGpsFixLost();
        }
      }
    }, onError: (_) {});
  }

  Future<void> _reopenStreamIfAvailable() async {
    if (!_attached || _sub != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _watchServiceStatus();
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _startStream();
    } catch (_) {
      _scheduleStreamRestart();
    }
  }

  void _startStream() {
    _restartTimer?.cancel();
    _restartTimer = null;
    final generation = ++_streamGeneration;
    final previousSub = _sub;
    _sub = null;
    if (previousSub != null) unawaited(previousSub.cancel());
    _lastEmit = null;
    // Snapshot the configuration this stream is opened with so flight or app
    // lifecycle changes can reopen it only when the native mode must change.
    _backgroundMode = _requiresBackgroundMode;
    try {
      _sub =
          Geolocator.getPositionStream(
            locationSettings: _buildLocationSettings(
              background: _backgroundMode,
            ),
          ).listen(
            (position) {
              if (generation != _streamGeneration) return;
              _restartAttempt = 0;
              _restartTimer?.cancel();
              _restartTimer = null;
              _onPosition(position);
            },
            onError: (_) {
              if (generation != _streamGeneration) return;
              _sub = null;
              if (_hadFix) {
                _hadFix = false;
                source.reportGpsFixLost();
              }
              _scheduleStreamRestart();
            },
          );
    } catch (_) {
      if (generation == _streamGeneration) {
        _sub = null;
        _scheduleStreamRestart();
      }
    }
  }

  void _scheduleStreamRestart() {
    if (!_attached || _restartTimer != null) return;
    final delaySeconds = _restartAttempt >= 5 ? 30 : 1 << _restartAttempt;
    _restartAttempt++;
    _restartTimer = Timer(Duration(seconds: delaySeconds), () {
      _restartTimer = null;
      unawaited(_reopenStreamIfAvailable());
    });
  }

  /// Reacts to a flight starting or stopping.
  ///
  /// Starting a flight upgrades the stream to background-resilient settings.
  /// Stopping drops back to foreground-only settings only when the Android app
  /// itself is still in the foreground. Other flight-state changes are a no-op.
  void _onFlightStateChanged() {
    if (flightState.isFlying) {
      if (Platform.isAndroid && !_appIsBackgrounded) {
        unawaited(_requestBatteryOptimizationExemption());
      } else if (Platform.isIOS) {
        unawaited(_ensureBackgroundPermission());
      }
    }

    if (_sub == null) {
      unawaited(_reopenStreamIfAvailable());
      return;
    }
    if (_requiresBackgroundMode == _backgroundMode) return;
    _startStream();
  }

  /// Offers Android's system battery-optimization exemption when the user
  /// starts a flight. OEM-specific controls (such as MIUI autostart and
  /// battery restrictions) remain under the user's device settings.
  Future<void> _requestBatteryOptimizationExemption() async {
    if (!_attached || _batteryOptimizationPromptAttempted) return;
    _batteryOptimizationPromptAttempted = true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted && !_appIsBackgrounded) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {
      // A denied or unsupported exemption must not prevent the flight stream.
    }
  }

  /// Best-effort upgrade to iOS "Always" location authorization when a flight
  /// starts. If the user declines, keep running on the current authorization.
  Future<void> _ensureBackgroundPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse) {
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
  /// When [background] is true (a flight is in progress, or Android is
  /// backgrounded) the stream is configured to survive the screen turning off
  /// and the app being backgrounded:
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
    _streamGeneration++;
    _restartTimer?.cancel();
    _restartTimer = null;
    flightState.removeListener(_onFlightStateChanged);
    final sub = _sub;
    _sub = null;
    if (sub != null) unawaited(sub.cancel());
    final serviceStatusSub = _serviceStatusSub;
    _serviceStatusSub = null;
    if (serviceStatusSub != null) unawaited(serviceStatusSub.cancel());
  }
}
