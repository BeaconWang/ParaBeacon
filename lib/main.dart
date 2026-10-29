import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio/altitude_announcement_bridge.dart';
import 'audio/ble_sensor_announcement_bridge.dart';
import 'audio/vario_audio_example.dart';
import 'audio/vario_audio_service.dart';
import 'audio/vario_sound_settings.dart';
import 'controls/announcement_caption_overlay.dart';
import 'dash_grid_page.dart';
import 'data/aircraft_settings.dart';
import 'data/airspace_store.dart';
import 'data/asfc_auth_service.dart';
import 'data/ble/ble_flight_data_bridge.dart';
import 'data/ble/ble_sensor_service.dart';
import 'data/color_palette_settings.dart';
import 'data/debug_settings.dart';
import 'data/device_battery_service.dart';
import 'data/display_settings.dart';
import 'data/flight_data_provider.dart';
import 'data/flight_data_transformer.dart';
import 'data/flight_details_settings.dart';
import 'data/flight_recorder.dart';
import 'data/flight_state.dart';
import 'data/gps_flight_data_bridge.dart';
import 'data/landing_point_store.dart';
import 'data/live_tracking_config.dart';
import 'data/live_tracking_proxy_auth_service.dart';
import 'data/live_tracking_service.dart';
import 'data/live_tracking_settings.dart';
import 'data/offline_tiles_service.dart';
import 'data/raw_flight_data_source.dart';
import 'data/recording_settings.dart';
import 'data/sensors/internal_sensor_bridge.dart';
import 'data/sensors/internal_sensor_service.dart';
import 'data/share_card_settings.dart';
import 'data/vertical_speed_settings.dart';
import 'data/takeoff_reference.dart';
import 'data/unit_settings.dart';
import 'data/xcontest_auth_service.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_themes.dart';
import 'theme/locale_controller.dart';
import 'theme/theme_controller.dart';

export 'dash_grid_page.dart' show DashGridPage, DashGridPainter;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final trackingConfig = await const LiveTrackingConfigLoader().load();
    LiveTrackingService.instance.configure(trackingConfig);
  } on Object {
    LiveTrackingService.instance.configure(null);
  }
  // Restore offline maps after the first frame so opening the app is not held
  // up by preferences I/O or opening the MBTiles database.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(OfflineTilesService.instance.warmup());
  });
  // Keep the display awake: a flight instrument must stay visible and its
  // audio/GPS/sensor loops running rather than being suspended when the user
  // isn't touching the screen. Best-effort — unsupported platforms are no-ops.
  WakelockPlus.enable().catchError((_) {});
  // Run fullscreen: hide the system status bar (and Android navigation bar)
  // so the dashboard uses every pixel. `immersiveSticky` restores the bars
  // briefly when the user swipes from the edge, then auto-hides them again
  // — appropriate for an instrument panel that must stay unobstructed.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ParaBeaconApp());
}

class ParaBeaconApp extends StatefulWidget {
  const ParaBeaconApp({super.key});

  @override
  State<ParaBeaconApp> createState() => _ParaBeaconAppState();
}

class _ParaBeaconAppState extends State<ParaBeaconApp>
    with WidgetsBindingObserver {
  // The single, unified raw flight-data source for the whole app (raw data
  // layer: resolves each field by priority Debug > Bluetooth > Other).
  late final BluetoothSensorFlightDataSource _dataSource;

  // Data-transform layer: wraps [_dataSource] and derives display-ready values
  // (e.g. the configured trailing-window average vertical speed). Controls, the
  // vario audio and the recorder all read from this shared transform.
  //   [control] <- [_transformer] <- [_dataSource] <- [raw data]
  late final FlightDataTransformer _transformer;
  late final LiveTrackingService _liveTracking;

  // Drives the Vario audio directly from the vertical speed of [_dataSource].
  // Every FlightData update forwards `verticalSpeed` into the audio engine, so
  // the sound is always a function of the current vertical speed.
  late final VarioAudioBridge _varioAudio;
  late final AltitudeAnnouncementBridge _altitudeAnnouncements;

  // Forwards a connected BLE sensor's readings into [_dataSource] so that,
  // whenever a real sensor is connected, its vertical speed drives the app
  // (and the vario audio) instead of the development simulator.
  late final BleFlightDataBridge _bleBridge;
  late final BleSensorAnnouncementBridge _bleAnnouncements;

  // Forwards continuous device-GPS readings into [_dataSource] so every
  // consumer (map, recorder, data-value controls, ...) sees the real
  // latitude/longitude/heading/groundSpeed/gpsAltitude/hasFix without having
  // to open its own geolocator stream. Sits at the "other" raw tier so BLE
  // sensor readings always win on fields the BLE device owns (vertical speed,
  // baro altitude, ...).
  late final GpsFlightDataBridge _gpsBridge;

  // Forwards the device's own built-in barometer (when present and preferred)
  // into [_dataSource] at a tier above the BLE sensor, so an internal sensor
  // drives vario/altitude/pressure ahead of an external BLE device.
  late final InternalSensorBridge _internalBridge;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final FlightRecorder _flightRecorder = FlightRecorder.instance;
  bool _landingPromptVisible = false;

  @override
  void initState() {
    super.initState();
    // Watch app lifecycle so we can restore fullscreen after the OS
    // temporarily shows the system bars (e.g. after a permission dialog or
    // when the user returns from another app).
    WidgetsBinding.instance.addObserver(this);
    // Restore the ASFC session from platform secure storage. The account sheet
    // remains usable while this best-effort read completes.
    AsfcAuthService.instance.load();
    // Restore the XContest OAuth session from platform secure storage.
    XContestAuthService.instance.load();
    LiveTrackingSettings.instance.load();
    LiveTrackingProxyAuthService.instance.load();
    // Restore the aircraft preferences before the Preferences sheet opens.
    AircraftSettings.instance.load();
    // Load persisted debug preferences (e.g. the simulated-source toggle,
    // default off). Loading notifies listeners, so if the simulator was
    // previously enabled the data source resumes it automatically.
    DebugSettings.instance.load();
    // Load the persisted recording preferences (e.g. track-point interval
    // mode, default = smart/current logic) so the recorder uses the user's
    // choice from the first fix.
    RecordingSettings.instance.load();
    FlightState.instance.loadSettings();
    LandingPointStore.instance.load();
    ColorPaletteSettings.instance.load();
    // Load persisted units and display precision before dashboard controls render.
    UnitSettings.instance.load();
    DisplaySettings.instance.load();
    ShareCardSettings.instance.load();
    FlightDetailsSettings.instance.load();
    // Load the persisted theme preset before the first frame paints. The
    // MaterialApp below listens to ThemeController so setTheme(...) at any
    // later time rebuilds the whole tree with the new palette.
    ThemeController.instance.load();
    // Load the persisted language selection before the first frame paints.
    // The MaterialApp below listens to LocaleController so setLanguage(...) at
    // any later time rebuilds the whole tree with the new locale.
    LocaleController.instance.load();

    // Bluetooth-sensor tier is the raw feed; a debug override (installed via the
    // Debug Sensor control) always wins over it (Debug > Bluetooth sensor).
    // Falls back to the built-in simulator only when the debug simulator toggle
    // is enabled; otherwise no data is fabricated until a real BLE device pairs.
    _dataSource = BluetoothSensorFlightDataSource()..start();

    // Wrap the raw source in the data-transform layer. Everything downstream
    // (controls, recorder, vario audio) reads the transformed feed so they all
    // see the same derived values (e.g. the averaged vertical speed).
    _transformer = FlightDataTransformer(rawSource: _dataSource);
    VerticalSpeedSettings.instance.addListener(_onVerticalSpeedSettingsChanged);
    unawaited(VerticalSpeedSettings.instance.load());
    TakeoffReference.instance.bind(_transformer);

    // Bring up the BLE sensor service (best-effort; no-op on desktop/web) and
    // bridge its readings into the unified data source. When a sensor connects,
    // its vertical speed takes over from the simulator.
    BleSensorService.instance.init();
    _bleBridge = BleFlightDataBridge(source: _dataSource)..attach();
    _bleAnnouncements = BleSensorAnnouncementBridge()..attach();

    // Bring up the device's internal barometer (best-effort; no-op where there
    // is no barometer or on desktop/web). When present and preferred, its
    // readings take over the vario/altitude/pressure tier ahead of any BLE
    // sensor — "use the internal sensor first".
    InternalSensorService.instance.init();
    _internalBridge = InternalSensorBridge(source: _dataSource)..attach();

    // Bring up the device battery monitor (best-effort). Powers the charging /
    // level indicator on the Status Line widget.
    DeviceBatteryService.instance.init();

    // Start streaming the real device GPS into the unified data source. On
    // mobile this requests the location permission on first launch and then
    // continuously feeds position updates into the "other" raw tier — so the
    // map, recorder and every other control read a live GPS position through
    // the same FlightDataProvider they already use.
    _gpsBridge = GpsFlightDataBridge(source: _dataSource);
    // Fire-and-forget: permission + service checks are async but must not
    // block startup, and any failure silently falls back to whatever other
    // source (BLE sensor / simulator) is providing.
    _gpsBridge.attach();

    // Route the shared, transformed GPS feed through the configured ParaBeacon
    // proxy only while the user has enabled sharing and a flight is active.
    _liveTracking = LiveTrackingService.instance;
    _liveTracking.bind(
      data: _transformer,
      flightState: FlightState.instance,
      isEnabled: () =>
          LiveTrackingSettings.instance.isEffectivelyEnabled &&
          XContestAuthService.instance.isSignedIn &&
          LiveTrackingProxyAuthService.instance.isConfigured,
      pilotId: () => XContestAuthService.instance.uid,
      eligibilitySource: Listenable.merge([
        LiveTrackingSettings.instance,
        XContestAuthService.instance,
        LiveTrackingProxyAuthService.instance,
      ]),
    );

    // Continuously record the full flight-data feed while a flight is in
    // progress (driven by the shared FlightState; supports auto take-off /
    // landing detection when enabled). Records the transformed feed.
    _flightRecorder.bind(_transformer);
    _flightRecorder.addListener(_onFlightRecorderChanged);
    // Restore previously-saved flight summaries so the Flights sheet
    // shows past flights across app restarts (best-effort; failures are
    // silent so a corrupt on-disk log doesn't block startup).
    FlightRecorder.instance.loadPersisted();

    // Load airspace data if the pilot has dropped an OpenAir file; failure is
    // best-effort and leaves the map without airspace overlays.
    AirspaceStore.instance.warmup();

    // Load the user's persisted Vario sound profile and apply it to the audio
    // engine (no-op beyond defaults on first launch).
    VarioSoundSettings.instance.load();

    // Use the shared VarioAudioService singleton so the Vario Sound Settings
    // sheet can control the same engine (sound/volume/profile) without
    // threading it through the widget tree. Driven by the transformed vertical
    // speed.
    _varioAudio = VarioAudioBridge(
      source: _transformer,
      audio: VarioAudioService.instance,
      // Only let the vario make sound while a Bluetooth-sensor feed is
      // connected (real BLE device, or the debug simulator standing in for
      // one). With nothing connected the beeper stays silent regardless of any
      // vertical-speed values flowing through.
      sensorConnected: () => _dataSource.isConnected,
    );
    // Initialize the audio stream and start forwarding vertical speed. Safe to
    // fire-and-forget; forwarding begins as soon as init() completes.
    _varioAudio.attach();

    // Speak the current altitude when the smoothed climb rate enters the
    // configured lift band. Speech is opt-in and follows the selected UI locale.
    _altitudeAnnouncements = AltitudeAnnouncementBridge(source: _transformer)
      ..attach();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flightRecorder.removeListener(_onFlightRecorderChanged);
    _liveTracking.unbind();
    _gpsBridge.dispose();
    _internalBridge.dispose();
    _bleBridge.dispose();
    _bleAnnouncements.dispose();
    _varioAudio.dispose();
    _altitudeAnnouncements.dispose();
    VerticalSpeedSettings.instance.removeListener(
      _onVerticalSpeedSettingsChanged,
    );
    TakeoffReference.instance.unbind();
    _transformer.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  void _onVerticalSpeedSettingsChanged() {
    _transformer.setVerticalSpeedWindow(
      VerticalSpeedSettings.instance.verticalSpeedWindow,
    );
  }

  void _onFlightRecorderChanged() {
    if (!_flightRecorder.hasPendingLandingConfirmation ||
        _landingPromptVisible) {
      return;
    }
    _landingPromptVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = _navigatorKey.currentContext;
      if (!mounted || context == null) {
        _landingPromptVisible = false;
        return;
      }
      final l10n = AppLocalizations.of(context);
      final landed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.flightLandingDetectedTitle),
          content: Text(l10n.flightLandingDetectedBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.flightLandingStillFlying),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.flightLandingConfirm),
            ),
          ],
        ),
      );
      _landingPromptVisible = false;
      _flightRecorder.resolveLandingConfirmation(landed == true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _gpsBridge.onAppLifecycleStateChanged(state);
    if (state == AppLifecycleState.resumed) {
      // Re-assert fullscreen: some system events (permission prompts, task
      // switcher, etc.) can bring the status/nav bars back.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlightDataProvider(
      transformer: _transformer,
      // Rebuild the whole app when the user picks a different theme preset or
      // language. Both are ChangeNotifiers; Listenable.merge lets a single
      // AnimatedBuilder subscribe to both and rebuild this subtree on either.
      child: AnimatedBuilder(
        animation: Listenable.merge([
          ThemeController.instance,
          LocaleController.instance,
        ]),
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'ParaBeacon',
            debugShowCheckedModeBanner: false,
            theme: themeDataFor(ThemeController.instance.current),
            // Chosen language (null = follow the device language, resolved
            // against supportedLocales by the framework).
            locale: LocaleController.instance.current.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            // Caption with the text of the current voice announcement, shown
            // above every route (dashboard, sheets, dialogs).
            builder: (context, child) => Stack(
              children: [
                ?child,
                const Positioned.fill(child: AnnouncementCaptionOverlay()),
              ],
            ),
            home: const DashGridPage(),
          );
        },
      ),
    );
  }
}
