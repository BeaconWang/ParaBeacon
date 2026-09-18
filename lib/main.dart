import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:ui' as ui;

import 'l10n/app_localizations.dart';

import 'controls/accounts_sheet.dart';
import 'controls/aircraft_settings_sheet.dart';
import 'controls/live_tracking_settings_sheet.dart';
import 'controls/add_control_sheet.dart';
import 'controls/bluetooth_sensor_sheet.dart';
import 'controls/flights_sheet.dart';
import 'controls/control_catalog.dart';
import 'controls/control_context_menu.dart';
import 'controls/control_settings_sheet.dart';
import 'controls/control_widget.dart';
import 'controls/dash_page.dart';
import 'controls/placed_control.dart';
import 'controls/vario_sound_settings_sheet.dart';
import 'controls/weather_sheet.dart';
import 'data/ble/ble_flight_data_bridge.dart';
import 'data/ble/ble_sensor_service.dart';
import 'data/device_battery_service.dart';
import 'data/aircraft_settings.dart';
import 'data/airspace_store.dart';
import 'data/asfc_auth_service.dart';
import 'data/xcontest_auth_service.dart';
import 'data/live_tracking_settings.dart';
import 'data/debug_settings.dart';
import 'data/flight_data_provider.dart';
import 'data/flight_data_transformer.dart';
import 'data/flight_recorder.dart';
import 'data/gps_flight_data_bridge.dart';
import 'data/layout_store.dart';
import 'data/offline_tiles_service.dart';
import 'data/raw_flight_data_source.dart';
import 'data/recording_settings.dart';
import 'audio/vario_audio_example.dart';
import 'audio/vario_audio_service.dart';
import 'audio/vario_sound_settings.dart';
import 'theme/app_themes.dart';
import 'theme/locale_controller.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_settings_sheet.dart';
import 'theme/language_settings_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  // (e.g. the trailing-2s-average vertical speed). Controls, the vario audio
  // and the recorder all read from this so they share the same transforms.
  //   [control] <- [_transformer] <- [_dataSource] <- [raw data]
  late final FlightDataTransformer _transformer;

  // Drives the Vario audio directly from the vertical speed of [_dataSource].
  // Every FlightData update forwards `verticalSpeed` into the audio engine, so
  // the sound is always a function of the current vertical speed.
  late final VarioAudioBridge _varioAudio;

  // Forwards a connected BLE sensor's readings into [_dataSource] so that,
  // whenever a real sensor is connected, its vertical speed drives the app
  // (and the vario audio) instead of the development simulator.
  late final BleFlightDataBridge _bleBridge;

  // Forwards continuous device-GPS readings into [_dataSource] so every
  // consumer (map, recorder, data-value controls, ...) sees the real
  // latitude/longitude/heading/groundSpeed/gpsAltitude/hasFix without having
  // to open its own geolocator stream. Sits at the "other" raw tier so BLE
  // sensor readings always win on fields the BLE device owns (vertical speed,
  // baro altitude, ...).
  late final GpsFlightDataBridge _gpsBridge;

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

    // Bring up the BLE sensor service (best-effort; no-op on desktop/web) and
    // bridge its readings into the unified data source. When a sensor connects,
    // its vertical speed takes over from the simulator.
    BleSensorService.instance.init();
    _bleBridge = BleFlightDataBridge(source: _dataSource)..attach();

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

    // Continuously record the full flight-data feed while a flight is in
    // progress (driven by the shared FlightState; supports auto take-off /
    // landing detection when enabled). Records the transformed feed.
    FlightRecorder.instance.bind(_transformer);
    // Restore previously-saved flight summaries so the Flights sheet
    // shows past flights across app restarts (best-effort; failures are
    // silent so a corrupt on-disk log doesn't block startup).
    FlightRecorder.instance.loadPersisted();

    // Map control: re-open the last-activated offline basemap (.mbtiles) and
    // load airspace data if the pilot has dropped an OpenAir file. Both are
    // best-effort and leave the map on online tiles / no airspace on failure.
    OfflineTilesService.instance.warmup();
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsBridge.dispose();
    _bleBridge.dispose();
    _varioAudio.dispose();
    _transformer.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
            title: 'ParaBeacon',
            debugShowCheckedModeBanner: false,
            theme: themeDataFor(ThemeController.instance.current),
            // Chosen language (null = follow the device language, resolved
            // against supportedLocales by the framework).
            locale: LocaleController.instance.current.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const DashGridPage(),
          );
        },
      ),
    );
  }
}

class DashGridPage extends StatefulWidget {
  const DashGridPage({super.key});

  @override
  State<DashGridPage> createState() => _DashGridPageState();
}

class _DashGridPageState extends State<DashGridPage> {
  double _gridSize = 32.0;
  bool _menuOpen = false;
  // Start in view mode on cold launch when the dashboard already has content:
  // pilots opening the app in flight should see their instrument dashboard,
  // not the edit affordances. If the dashboard is empty (first launch or
  // after "Clear all controls"), _loadLayout flips this to true so the user
  // lands directly in edit mode and can add their first control.
  bool _isEditMode = false;

  // Dashboard pages (tabs). The user swipes horizontally to switch pages in
  // view mode and can add pages in edit mode.
  final List<DashPage> _pages = [DashPage(id: 'page_0')];
  int _currentPage = 0;
  int _pageSeq = 1;
  late final PageController _pageController;

  // Auto-hide state for the bottom page indicator in view mode. The indicator
  // is revealed while the user is swiping between pages and then fades out
  // one second after the swipe settles, so it doesn't linger over the
  // dashboard content. In edit mode the indicator stays permanently visible
  // (the pilot needs it to customize page icons and delete pages).
  bool _pageIndicatorVisible = false;
  Timer? _pageIndicatorHideTimer;
  static const Duration _pageIndicatorHideDelay = Duration(seconds: 1);
  static const Duration _pageIndicatorFadeDuration = Duration(
    milliseconds: 200,
  );

  /// Controls on the currently visible page.
  List<PlacedControl> get _controls => _pages[_currentPage].controls;

  String? _selectedControlId;
  int _controlSeq = 0;

  // Stable per-control keys. Reusing the same GlobalKey for a given control
  // instance keeps its State alive when the widget tree around it changes
  // (e.g. selecting/deselecting swaps the edit-mode Stack for the view-mode
  // branch, and toggles an IgnorePointer wrapper). Without this, stateful
  // controls like the Map would be rebuilt from scratch on every
  // select/deselect and lose their zoom/pan.
  final Map<String, GlobalKey> _controlKeys = {};

  GlobalKey _keyFor(String instanceId) =>
      _controlKeys.putIfAbsent(instanceId, () => GlobalKey());

  // The single control on the current page that is currently "unlocked" and
  // therefore allowed to receive its own pointer events (map pan/zoom,
  // buttons, list scroll, etc.). Every other control on the page is treated
  // as a static, drawable-only display and swallows any pointer events except
  // the long-press that unlocks it. Reset when switching pages, tapping
  // empty background, or entering edit mode.
  String? _activeControlId;

  // Raw pointer tracking for the selected Vertical Graph. Pointer signals cover
  // mouse wheels and trackpads; the pointer map adds two-finger touch scrolling
  // without enabling interactions on any unselected control.
  final Map<int, Offset> _verticalGraphPointers = {};
  String? _verticalGraphGestureControlId;
  Offset? _verticalGraphTwoFingerCenter;
  double _verticalGraphTwoFingerRemainder = 0.0;

  // Accumulated pixel offset during a control drag (before grid snapping).
  Offset _dragAccum = Offset.zero;
  int _dragStartCol = 0;
  int _dragStartRow = 0;
  int _dragStartCols = 0;
  int _dragStartRows = 0;

  // Drag state
  double _dragOffset = 0.0;
  double _menuHeight = 300.0; // measured from the menu panel after layout
  final GlobalKey _menuKey = GlobalKey();

  /// Measures the actual rendered menu-panel height and updates [_menuHeight]
  /// so the pull-down offset matches the content (no blank space below items).
  void _measureMenu() {
    final ctx = _menuKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if ((h - _menuHeight).abs() > 0.5) {
      setState(() => _menuHeight = h);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadLayout();
  }

  /// Restores the saved dashboard layout (pages, controls, grid size,
  /// last-viewed page) if any.
  Future<void> _loadLayout() async {
    final saved = await LayoutStore.instance.load();
    if (!mounted) {
      return;
    }
    if (saved != null) {
      setState(() {
        _pages
          ..clear()
          ..addAll(saved.pages);
        _gridSize = saved.gridSize;
        // Restore the page the user was last viewing (already clamped by the
        // store to a valid index).
        _currentPage = saved.currentPage;
        _selectedControlId = null;

        // Advance the id sequences past any restored ids so new pages/controls
        // never collide with loaded ones.
        _pageSeq = _pages.length;
        _controlSeq = 0;
        for (final page in _pages) {
          for (final c in page.controls) {
            final n = _seqFromId(c.instanceId, 'ctrl_');
            if (n != null && n >= _controlSeq) _controlSeq = n + 1;
          }
          final pn = _seqFromId(page.id, 'page_');
          if (pn != null && pn >= _pageSeq) _pageSeq = pn + 1;
        }
      });
      // Sync the PageView to the restored page once it exists. Using jumpTo
      // (not animateTo) so the initial navigation isn't visible to the user.
      if (_currentPage != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(_currentPage);
          }
        });
      }
    }

    // Empty-dashboard bootstrap: if no page has any control (first launch, or
    // the user cleared everything), drop straight into edit mode so the edit
    // affordances and "Add Control" entry point are immediately discoverable
    // instead of showing a blank screen.
    final hasAnyControl = _pages.any((p) => p.controls.isNotEmpty);
    if (!hasAnyControl && !_isEditMode) {
      setState(() => _isEditMode = true);
    }
  }

  /// Extracts the numeric suffix of an id like `ctrl_12` / `page_3`.
  int? _seqFromId(String id, String prefix) {
    if (!id.startsWith(prefix)) return null;
    return int.tryParse(id.substring(prefix.length));
  }

  /// Persists the current layout (debounced).
  void _saveLayout() {
    LayoutStore.instance.save(
      pages: _pages,
      gridSize: _gridSize,
      currentPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _pageIndicatorHideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Reveals the bottom page indicator and (re)arms the auto-hide timer so it
  /// fades out [_pageIndicatorHideDelay] after the last page-swipe activity.
  /// No-op in edit mode, where the indicator is always visible.
  void _revealPageIndicator() {
    if (_isEditMode) return;
    _pageIndicatorHideTimer?.cancel();
    if (!_pageIndicatorVisible) {
      setState(() => _pageIndicatorVisible = true);
    }
  }

  /// Starts (or restarts) the countdown that hides the page indicator after
  /// a swipe finishes. Called on scroll-end so cross-page flings that emit
  /// multiple end events collapse into a single 1s hide delay.
  void _schedulePageIndicatorHide() {
    if (_isEditMode) return;
    _pageIndicatorHideTimer?.cancel();
    _pageIndicatorHideTimer = Timer(_pageIndicatorHideDelay, () {
      if (!mounted) return;
      if (_isEditMode) return;
      if (!_pageIndicatorVisible) return;
      setState(() => _pageIndicatorVisible = false);
    });
  }

  void _openMenu() {
    setState(() {
      _menuOpen = true;
      _dragOffset = _menuHeight;
    });
  }

  void _closeMenu() {
    setState(() {
      _menuOpen = false;
      _dragOffset = 0.0;
    });
  }

  void _onDragStart(DragStartDetails details) {
    _dragOffset = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, _menuHeight);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    // Open the top menu when either:
    // 1) pull-down distance exceeds 30% of the current window height, OR
    // 2) the menu has been fully pulled into view.
    //
    // This keeps the gesture responsive on tall screens while still allowing
    // short menus to open as soon as they are fully revealed.
    final windowHeight = MediaQuery.of(context).size.height;
    final byWindowThreshold = _dragOffset > windowHeight * 0.30;
    final byFullMenuReveal = _dragOffset >= _menuHeight;

    if (byWindowThreshold || byFullMenuReveal) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  // --- Drag-to-close (dragging up on the open menu) ---

  void _onCloseDragStart(DragStartDetails details) {
    // Start tracking from the fully-open position.
    _menuOpen = false;
    _dragOffset = _menuHeight;
    setState(() {});
  }

  void _onCloseDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, _menuHeight);
    });
  }

  void _onCloseDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Close on a clear upward fling, or when dragged past the halfway point up.
    if (velocity < -300 || _dragOffset < _menuHeight * 0.6) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  double get _effectiveMenuOffset => _menuOpen ? _menuHeight : _dragOffset;

  /// Handles a tap on a menu item.
  Future<void> _onMenuAction(String action) async {
    switch (action) {
      case 'add_control':
        _closeMenu();
        await _addControlFromMenu();
        break;
      case 'add_page':
        _closeMenu();
        _addPage();
        break;
      case 'toggle_edit':
        setState(() {
          _isEditMode = !_isEditMode;
          if (!_isEditMode) _selectedControlId = null;
          // Edit-mode transitions always re-lock controls: entering edit
          // mode means the user is arranging widgets (not interacting with
          // them); leaving it returns to a clean, fully-locked dashboard.
          _activeControlId = null;
          // Edit mode pins the page indicator on-screen (needed to reorder
          // icons and delete pages); leaving edit mode hands control back
          // to the swipe-driven auto-hide. Cancel any pending hide timer
          // and reset the visible flag so view mode starts hidden until
          // the user swipes again.
          _pageIndicatorHideTimer?.cancel();
          _pageIndicatorVisible = false;
        });
        break;
      case 'preferences':
        _closeMenu();
        await _openPreferences();
        break;
    }
  }

  /// Adds a new empty page after the current one and navigates to it.
  void _addPage() {
    setState(() {
      final newPage = DashPage(id: 'page_${_pageSeq++}');
      final insertAt = _currentPage + 1;
      _pages.insert(insertAt, newPage);
      _currentPage = insertAt;
      _selectedControlId = null;
      _isEditMode = true;
    });
    _saveLayout();
    // Jump the PageView to the new page after the frame so it exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// Deletes the current page (keeping at least one page).
  void _deleteCurrentPage() {
    if (_pages.length <= 1) return;
    setState(() {
      _pages.removeAt(_currentPage);
      if (_currentPage >= _pages.length) {
        _currentPage = _pages.length - 1;
      }
      _selectedControlId = null;
      _activeControlId = null;
    });
    _saveLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  /// Opens the app preferences sheet (full screen).
  Future<void> _openPreferences() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Background driven by the theme's bottomSheetTheme so runtime theme
      // switches (via the Theme picker inside this sheet) repaint every
      // pixel live — capturing `Theme.of(context)…` here would freeze the
      // sheet chrome on the old palette.
      // Full-screen: no rounded corners, occupies the entire available height.
      shape: const RoundedRectangleBorder(),
      constraints: const BoxConstraints.expand(),
      builder: (context) {
        // Local state within the sheet, applied back via the parent setState.
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final l10n = AppLocalizations.of(context);
            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pinned header with a close button.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.preferences,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.close,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Scrollable settings content fills the rest of the screen.
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.account_circle_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.accounts),
                          subtitle: Text(l10n.accountsSubtitle),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () async {
                            await showAccountsSheet(context);
                            setSheetState(() {});
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.flight,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.aircraft),
                          subtitle: Text(
                            AircraftSettings.instance.manufacturer
                                        .trim()
                                        .isEmpty &&
                                    AircraftSettings.instance.model
                                        .trim()
                                        .isEmpty &&
                                    AircraftSettings.instance.name
                                        .trim()
                                        .isEmpty
                                ? l10n.aircraftSubtitle
                                : AircraftSettings.instance.displayName,
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () async {
                            await showAircraftSettingsSheet(context);
                            setSheetState(() {});
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.track_changes,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.liveTracking),
                          subtitle: Text(
                            LiveTrackingSettings.instance.enabled
                                ? l10n.liveTrackingReady
                                : l10n.liveTrackingSubtitle,
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () async {
                            await showLiveTrackingSettingsSheet(context);
                            setSheetState(() {});
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.palette_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.theme),
                          subtitle: Text(
                            ThemeController.instance.current.labelOf(l10n),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () async {
                            await showThemeSettingsSheet(context);
                            // Refresh the subtitle in the still-open Preferences
                            // sheet so it reflects the newly-selected theme.
                            setSheetState(() {});
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.language,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.language),
                          subtitle: Text(
                            LocaleController.instance.current.labelOf(l10n),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () async {
                            await showLanguageSettingsSheet(context);
                            // Refresh the subtitle in the still-open Preferences
                            // sheet so it reflects the newly-selected language.
                            setSheetState(() {});
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.graphic_eq,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.varioSoundSettings),
                          subtitle: Text(l10n.varioSoundSettingsSubtitle),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => showVarioSoundSettingsSheet(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.bluetooth,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.bluetoothSensor),
                          subtitle: Text(l10n.bluetoothSensorSubtitle),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => showBluetoothSensorSheet(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.timeline,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(l10n.trackRecording),
                          subtitle: Text(
                            l10n.trackRecordingSubtitle(
                              RecordingSettings.instance.intervalMode ==
                                      RecordingIntervalMode.fixed1s
                                  ? l10n.recordingIntervalEvery1s
                                  : l10n.recordingIntervalSmart,
                              RecordingSettings.instance.detail ==
                                      RecordingDetail.full
                                  ? l10n.recordingDetailFull
                                  : l10n.recordingDetailXcTrack,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () async {
                            await _showRecordingSettingsSheet(context);
                            setSheetState(() {});
                          },
                        ),
                        // Debug tools are only compiled/shown in debug builds.
                        if (kDebugMode) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bug_report_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.debug,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(
                              Icons.sensors,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(l10n.simulatedFlightData),
                            subtitle: Text(l10n.simulatedFlightDataSubtitle),
                            value: DebugSettings.instance.simulatorEnabled,
                            onChanged: (on) {
                              DebugSettings.instance.setSimulatorEnabled(on);
                              setSheetState(() {});
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(
                              Icons.public,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(l10n.fakeGpsInChina),
                            subtitle: Text(l10n.fakeGpsInChinaSubtitle),
                            value: DebugSettings.instance.fakeChinaLocation,
                            // Only meaningful while the simulator is running.
                            onChanged: DebugSettings.instance.simulatorEnabled
                                ? (on) {
                                    DebugSettings.instance.setFakeChinaLocation(
                                      on,
                                    );
                                    setSheetState(() {});
                                  }
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Lets the user choose how flight track points are recorded: the smart
  /// interval (current logic, default) or a fixed 1-second interval.
  Future<void> _showRecordingSettingsSheet(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final mode = RecordingSettings.instance.intervalMode;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timeline, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          l10n.trackRecording,
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.trackRecordingChooseHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<RecordingIntervalMode>(
                      contentPadding: EdgeInsets.zero,
                      value: RecordingIntervalMode.smart,
                      groupValue: mode,
                      title: Text(l10n.trackRecordingSmart),
                      subtitle: Text(l10n.trackRecordingSmartSubtitle),
                      onChanged: (v) {
                        if (v == null) return;
                        RecordingSettings.instance.setIntervalMode(v);
                        setSheetState(() {});
                      },
                    ),
                    RadioListTile<RecordingIntervalMode>(
                      contentPadding: EdgeInsets.zero,
                      value: RecordingIntervalMode.fixed1s,
                      groupValue: mode,
                      title: Text(l10n.trackRecordingEverySecond),
                      subtitle: Text(l10n.trackRecordingEverySecondSubtitle),
                      onChanged: (v) {
                        if (v == null) return;
                        RecordingSettings.instance.setIntervalMode(v);
                        setSheetState(() {});
                      },
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.dataset_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(l10n.recordMoreInformation),
                      subtitle: Text(
                        RecordingSettings.instance.detail ==
                                RecordingDetail.full
                            ? l10n.recordMoreInformationFull
                            : l10n.recordMoreInformationXcTrack,
                      ),
                      value:
                          RecordingSettings.instance.detail ==
                          RecordingDetail.full,
                      onChanged: (on) {
                        RecordingSettings.instance.setDetail(
                          on ? RecordingDetail.full : RecordingDetail.xctrack,
                        );
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Confirms with the user, then removes every control from the current
  /// dashboard. Wired to the edit-mode "Clear all controls" menu item.
  Future<void> _clearAllControls() async {
    if (_controls.isEmpty) return;
    final confirmed = await _confirmClearAll(context);
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() {
      _controls.clear();
      _selectedControlId = null;
      _activeControlId = null;
    });
    _saveLayout();
  }

  Future<bool?> _confirmClearAll(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearAllControlsTitle),
        content: Text(l10n.clearAllControlsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }

  /// Opens the control chooser and, on selection, places the new control on
  /// the grid at the first free spot.
  Future<void> _addControlFromMenu() async {
    final ControlType? type = await showAddControlSheet(context);
    if (type == null || !mounted) return;

    final position = _findFreeCell(type.defaultCols, type.defaultRows);
    setState(() {
      final control = PlacedControl.fromType(
        type,
        instanceId: 'ctrl_${_controlSeq++}',
        col: position.$1,
        row: position.$2,
      );
      _controls.add(control);
      _selectedControlId = control.instanceId;
      // Adding a control implies we want to see/edit it.
      _isEditMode = true;
    });
    _saveLayout();
  }

  /// Number of grid columns/rows that best matches the user's desired cell
  /// size ([_gridSize]) for the given [size]. Rounded (not floored) so the
  /// whole screen is used and the cell size stays closest to the target.
  int _gridCols(Size size) => (size.width / _gridSize).round().clamp(1, 1000);
  int _gridRows(Size size) => (size.height / _gridSize).round().clamp(1, 1000);

  /// Effective cell dimensions that divide *evenly* into the full screen:
  /// `cols * cellWidth == width` and `rows * cellHeight == height` exactly,
  /// regardless of the grid dimensions. Cells may be slightly non-square, but
  /// they tile the screen with no leftover gap at the right/bottom edges.
  double _cellWidth(Size size) => size.width / _gridCols(size);
  double _cellHeight(Size size) => size.height / _gridRows(size);

  /// Finds a grid cell (col, row) where a control of the given size does not
  /// overlap an existing one. Falls back to (0, 0) if the grid is full.
  (int, int) _findFreeCell(int cols, int rows) {
    final size = MediaQuery.of(context).size;
    final maxCols = _gridCols(size);
    final maxRows = _gridRows(size);

    for (int row = 0; row + rows <= maxRows; row++) {
      for (int col = 0; col + cols <= maxCols; col++) {
        if (!_overlapsExisting(col, row, cols, rows)) {
          return (col, row);
        }
      }
    }
    return (0, 0);
  }

  bool _overlapsExisting(int col, int row, int cols, int rows) {
    for (final c in _controls) {
      final overlapX = col < c.col + c.cols && col + cols > c.col;
      final overlapY = row < c.row + c.rows && row + rows > c.row;
      if (overlapX && overlapY) return true;
    }
    return false;
  }

  void _deleteControl(String instanceId) {
    setState(() {
      _controls.removeWhere((c) => c.instanceId == instanceId);
      if (_selectedControlId == instanceId) _selectedControlId = null;
      if (_activeControlId == instanceId) _activeControlId = null;
      _controlKeys.remove(instanceId);
    });
    _saveLayout();
  }

  /// Shows the long-press context menu for [control] and performs the action.
  Future<void> _showControlMenu(PlacedControl control) async {
    setState(() => _selectedControlId = control.instanceId);
    final action = await showControlContextMenu(context, control: control);
    if (action == null || !mounted) return;

    switch (action) {
      case ControlAction.settings:
        await showControlSettingsSheet(
          context,
          control: control,
          onChanged: () {
            setState(() {});
            _saveLayout();
          },
        );
        break;
      case ControlAction.duplicate:
        _duplicateControl(control);
        break;
      case ControlAction.bringToFront:
        setState(() {
          _controls.remove(control);
          _controls.add(control);
        });
        _saveLayout();
        break;
      case ControlAction.sendToBack:
        setState(() {
          _controls.remove(control);
          _controls.insert(0, control);
        });
        _saveLayout();
        break;
      case ControlAction.delete:
        _deleteControl(control.instanceId);
        break;
    }
  }

  void _duplicateControl(PlacedControl control) {
    final position = _findFreeCell(control.cols, control.rows);
    setState(() {
      final copy = control.copyAt(
        instanceId: 'ctrl_${_controlSeq++}',
        col: position.$1,
        row: position.$2,
      );
      _controls.add(copy);
      _selectedControlId = copy.instanceId;
      _isEditMode = true;
    });
    _saveLayout();
  }

  void _changeVerticalGraphInterval(PlacedControl control, int steps) {
    if (control.type.id != 'vertical_graph' || steps == 0) return;

    final current = control
        .doubleSetting('interval', fallback: 60.0)
        .clamp(10.0, 600.0)
        .roundToDouble();
    final next = (current + steps * 2.0).clamp(10.0, 600.0).toDouble();
    if (next == current) return;

    setState(() => control.settings['interval'] = next);
    _saveLayout();
  }

  void _onVerticalGraphPointerSignal(
    PlacedControl control,
    PointerSignalEvent event,
  ) {
    if (event is! PointerScrollEvent ||
        control.type.id != 'vertical_graph' ||
        _selectedControlId != control.instanceId &&
            _activeControlId != control.instanceId) {
      return;
    }

    final delta = event.scrollDelta.dy;
    if (delta == 0) return;
    final steps = (delta.abs() / 20.0).ceil().clamp(1, 10);
    // Follow the usual wheel convention: scrolling up increases the range.
    _changeVerticalGraphInterval(control, -delta.sign.toInt() * steps);
  }

  void _onVerticalGraphPointerDown(
    PlacedControl control,
    PointerDownEvent event,
  ) {
    if (control.type.id != 'vertical_graph' ||
        _selectedControlId != control.instanceId &&
            _activeControlId != control.instanceId) {
      return;
    }
    if (_verticalGraphGestureControlId != control.instanceId) {
      _verticalGraphPointers.clear();
      _verticalGraphTwoFingerCenter = null;
      _verticalGraphTwoFingerRemainder = 0.0;
      _verticalGraphGestureControlId = control.instanceId;
    }
    _verticalGraphPointers[event.pointer] = event.position;
    if (_verticalGraphPointers.length >= 2) {
      _verticalGraphTwoFingerCenter = _verticalGraphCenter();
      _verticalGraphTwoFingerRemainder = 0.0;
    }
  }

  void _onVerticalGraphPointerMove(
    PlacedControl control,
    PointerMoveEvent event,
  ) {
    if (_verticalGraphGestureControlId != control.instanceId) return;
    final previousCenter = _verticalGraphTwoFingerCenter;
    _verticalGraphPointers[event.pointer] = event.position;
    if (_verticalGraphPointers.length < 2) return;

    final currentCenter = _verticalGraphCenter();
    if (previousCenter == null || currentCenter == null) {
      _verticalGraphTwoFingerCenter = currentCenter;
      return;
    }

    _verticalGraphTwoFingerRemainder += currentCenter.dy - previousCenter.dy;
    _verticalGraphTwoFingerCenter = currentCenter;

    var steps = 0;
    while (_verticalGraphTwoFingerRemainder >= 16.0) {
      steps++;
      _verticalGraphTwoFingerRemainder -= 16.0;
    }
    while (_verticalGraphTwoFingerRemainder <= -16.0) {
      steps--;
      _verticalGraphTwoFingerRemainder += 16.0;
    }
    // A two-finger swipe up also increases the visible time range.
    if (steps != 0) _changeVerticalGraphInterval(control, -steps);
  }

  Offset? _verticalGraphCenter() {
    if (_verticalGraphPointers.length < 2) return null;
    var x = 0.0;
    var y = 0.0;
    for (final position in _verticalGraphPointers.values) {
      x += position.dx;
      y += position.dy;
    }
    return Offset(
      x / _verticalGraphPointers.length,
      y / _verticalGraphPointers.length,
    );
  }

  void _onVerticalGraphPointerEnd(PlacedControl control, int pointer) {
    if (_verticalGraphGestureControlId != control.instanceId) return;
    _verticalGraphPointers.remove(pointer);
    if (_verticalGraphPointers.length < 2) {
      _verticalGraphTwoFingerCenter = null;
      _verticalGraphTwoFingerRemainder = 0.0;
    }
    if (_verticalGraphPointers.isEmpty) {
      _verticalGraphGestureControlId = null;
    }
  }

  Widget _verticalGraphPointerLayer(PlacedControl control, Widget child) {
    final active =
        _selectedControlId == control.instanceId ||
        _activeControlId == control.instanceId;
    if (!active || control.type.id != 'vertical_graph') return child;

    return Listener(
      onPointerSignal: (event) => _onVerticalGraphPointerSignal(control, event),
      onPointerDown: (event) => _onVerticalGraphPointerDown(control, event),
      onPointerMove: (event) => _onVerticalGraphPointerMove(control, event),
      onPointerUp: (event) =>
          _onVerticalGraphPointerEnd(control, event.pointer),
      onPointerCancel: (event) =>
          _onVerticalGraphPointerEnd(control, event.pointer),
      child: child,
    );
  }

  void _onControlDragStart(PlacedControl control) {
    _dragAccum = Offset.zero;
    _dragStartCol = control.col;
    _dragStartRow = control.row;
    setState(() => _selectedControlId = control.instanceId);
  }

  void _onControlDragUpdate(PlacedControl control, Offset delta) {
    // A two-finger gesture on a selected Vertical Graph changes its time
    // window; it must not also move the widget on the edit grid.
    if (control.type.id == 'vertical_graph' &&
        _verticalGraphPointers.length >= 2) {
      return;
    }
    _dragAccum += delta;
    setState(() {
      final size = MediaQuery.of(context).size;
      final maxCols = _gridCols(size);
      final maxRows = _gridRows(size);

      // Convert pixel movement to whole cells using the *effective* cell size
      // (which divides evenly into the screen), so dragging tracks the visible
      // grid regardless of dimensions.
      final colDelta = (_dragAccum.dx / _cellWidth(size)).round();
      final rowDelta = (_dragAccum.dy / _cellHeight(size)).round();

      control.col = (_dragStartCol + colDelta).clamp(
        0,
        (maxCols - control.cols).clamp(0, maxCols),
      );
      control.row = (_dragStartRow + rowDelta).clamp(
        0,
        (maxRows - control.rows).clamp(0, maxRows),
      );
    });
  }

  void _onControlResizeStart(PlacedControl control) {
    _dragAccum = Offset.zero;
    _dragStartCols = control.cols;
    _dragStartRows = control.rows;
    setState(() => _selectedControlId = control.instanceId);
  }

  void _onControlResizeUpdate(PlacedControl control, Offset delta) {
    _dragAccum += delta;
    setState(() {
      final size = MediaQuery.of(context).size;
      final maxCols = _gridCols(size);
      final maxRows = _gridRows(size);

      final colDelta = (_dragAccum.dx / _cellWidth(size)).round();
      final rowDelta = (_dragAccum.dy / _cellHeight(size)).round();

      // At least 1 cell; cannot extend past the grid edge from current origin.
      control.cols = (_dragStartCols + colDelta).clamp(
        1,
        (maxCols - control.col).clamp(1, maxCols),
      );
      control.rows = (_dragStartRows + rowDelta).clamp(
        1,
        (maxRows - control.row).clamp(1, maxRows),
      );
    });
  }

  /// Whether pressing the system Back button (Android) / triggering the
  /// root-route pop gesture (iOS) currently has an in-app dismissal to do
  /// instead of leaving the app. Used by [PopScope] to decide whether to
  /// intercept the back gesture.
  bool get _hasBackDismissTarget =>
      _menuOpen ||
      _selectedControlId != null ||
      _activeControlId != null ||
      _isEditMode;

  /// Handles a back-button press that [PopScope] intercepted (i.e. one that
  /// we chose to consume by setting `canPop: false`). Peels the interaction
  /// layers off one at a time — menu first, then any unlocked/selected
  /// control, then edit mode itself — so a repeated back press eventually
  /// falls through to the default pop (which exits the app on Android's
  /// root route).
  void _handleBackDismiss() {
    if (_menuOpen) {
      _closeMenu();
      return;
    }
    if (_selectedControlId != null || _activeControlId != null) {
      setState(() {
        _selectedControlId = null;
        _activeControlId = null;
      });
      return;
    }
    if (_isEditMode) {
      // Mirror the top-menu / preferences edit-mode toggle: leaving edit
      // mode clears any selection, re-locks controls, and hands the page
      // indicator back to the swipe-driven auto-hide.
      setState(() {
        _isEditMode = false;
        _selectedControlId = null;
        _activeControlId = null;
        _pageIndicatorHideTimer?.cancel();
        _pageIndicatorVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Measure the real menu height after this frame so the pull-down offset
    // matches the content exactly (avoids blank space below the last item).
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureMenu());

    return PopScope(
      // Only intercept the back gesture when there is something on screen
      // to dismiss (open menu, a selected control in edit mode, or an
      // unlocked/"controlled" widget in view mode). Otherwise let the
      // system perform the default pop so Android's Back exits the app.
      canPop: !_hasBackDismissTarget,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackDismiss();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Pages (tabs). Swipe horizontally to switch pages in view mode;
            // in edit mode swiping is disabled so controls can be dragged.
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                // Track the PageView's horizontal scroll so we can flash the
                // bottom page indicator while the user is actively swiping
                // and fade it back out one second after the swipe settles.
                onNotification: (notification) {
                  if (_isEditMode) return false;
                  // Only react to horizontal (page) scroll — the PageView is
                  // horizontal, and nested controls (lists, maps) are vertical
                  // or don't emit ScrollNotifications, so this filter keeps
                  // stray inner-scroll events from re-arming the timer.
                  if (notification.metrics.axis != Axis.horizontal) {
                    return false;
                  }
                  if (notification is ScrollStartNotification ||
                      notification is ScrollUpdateNotification) {
                    _revealPageIndicator();
                  } else if (notification is ScrollEndNotification) {
                    _schedulePageIndicatorHide();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  physics: _isEditMode
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      _selectedControlId = null;
                      // Leaving a page re-locks whichever control the user had
                      // unlocked on it, so returning to it starts fresh.
                      _activeControlId = null;
                    });
                    // Persist the last-viewed page so re-launching the app
                    // returns the user to where they left off.
                    _saveLayout();
                  },
                  itemBuilder: (context, index) => _buildPageContent(index),
                ),
              ),
            ),

            // Page indicator. Shown with more than one page, or in edit mode
            // so a single page's icon can be customized. Visibility is driven
            // entirely by AnimatedOpacity (rather than removing the widget
            // from the tree) so opening/closing the top menu doesn't cause a
            // fade-in "pop" every time the indicator reappears — it merely
            // fades opacity while the menu is open and, if it was visible
            // before, is already at full opacity the instant the menu closes.
            //
            // In view mode the indicator auto-fades one second after the last
            // page swipe; in edit mode it stays fully visible.
            if (_pages.length > 1 || _isEditMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: IgnorePointer(
                  ignoring:
                      _menuOpen || (!_isEditMode && !_pageIndicatorVisible),
                  child: AnimatedOpacity(
                    duration: _pageIndicatorFadeDuration,
                    opacity: _menuOpen
                        ? 0.0
                        : ((_isEditMode || _pageIndicatorVisible) ? 1.0 : 0.0),
                    child: _buildPageIndicator(),
                  ),
                ),
              ),

            // Dim overlay when menu is open
            if (_effectiveMenuOffset > 0 || _menuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeMenu,
                  child: Container(color: Colors.black.withAlpha(80)),
                ),
              ),

            // Top swipe menu panel
            Positioned(
              left: 0,
              right: 0,
              top: _effectiveMenuOffset - _menuHeight,
              child: _buildMenuPanel(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the content (grid + controls + gesture layer) for one page.
  Widget _buildPageContent(int pageIndex) {
    final page = _pages[pageIndex];
    return Stack(
      children: [
        // Fullscreen main panel: drag down to open menu, tap to dismiss.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_menuOpen) {
                _closeMenu();
              } else if (_selectedControlId != null ||
                  _activeControlId != null) {
                setState(() {
                  _selectedControlId = null;
                  // Tapping outside any control re-locks it, matching how
                  // tapping outside deselects a control in edit mode.
                  _activeControlId = null;
                });
              }
            },
            onVerticalDragStart: _menuOpen ? null : _onDragStart,
            onVerticalDragUpdate: _menuOpen ? null : _onDragUpdate,
            onVerticalDragEnd: _menuOpen ? null : _onDragEnd,
            child: _isEditMode
                ? CustomPaint(
                    painter: DashGridPainter(
                      cellWidth: _cellWidth(MediaQuery.of(context).size),
                      cellHeight: _cellHeight(MediaQuery.of(context).size),
                      // Use the theme's on-surface color so the grid is
                      // visible on light backgrounds too, not just dark ones.
                      lineColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    size: Size.infinite,
                  )
                : const SizedBox.expand(),
          ),
        ),

        // Placed controls layer for this page.
        ..._buildPlacedControls(page.controls),
      ],
    );
  }

  /// A row of page-header icons showing the current page position.
  ///
  /// Tapping an inactive page navigates to it. Tapping the active page in edit
  /// mode opens the icon picker to customize its header icon.
  Widget _buildPageIndicator() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _currentPage;
        final page = _pages[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest.withAlpha(200),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (active) {
                  if (_isEditMode) _customizePageIcon(page);
                } else {
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: active ? 12 : 8,
                  vertical: 6,
                ),
                child: Icon(
                  page.icon,
                  size: 18,
                  color: active
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Opens a picker to choose the header icon for [page].
  Future<void> _customizePageIcon(DashPage page) async {
    final selected = await showModalBottomSheet<IconData>(
      context: context,
      showDragHandle: true,
      // Background driven by the theme's bottomSheetTheme (see other sheets).
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).pageIcon,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kPageHeaderIcons.map((icon) {
                    final isCurrent = icon == page.icon;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(icon),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Icon(
                          icon,
                          color: isCurrent
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => page.icon = selected);
      _saveLayout();
    }
  }

  /// Builds the positioned control widgets for the given [controls], laid out
  /// by grid cell.
  List<Widget> _buildPlacedControls(List<PlacedControl> controls) {
    // Diameter of the corner affordances (delete button and resize handle).
    // When a control is selected in edit mode we enlarge its outer layout
    // box by half of this so both affordances fall fully inside a hittable
    // area, even though visually they still overhang the control corners.
    const double affordanceSize = 32;
    const double overhang = affordanceSize / 2;

    // Effective per-cell dimensions that divide evenly into the screen, so
    // controls tile it with no leftover gap regardless of grid dimensions.
    final size = MediaQuery.of(context).size;
    final cellW = _cellWidth(size);
    final cellH = _cellHeight(size);

    return controls.map((control) {
      final left = control.col * cellW;
      final top = control.row * cellH;
      final width = control.cols * cellW;
      final height = control.rows * cellH;
      final isSelected = _selectedControlId == control.instanceId;
      final isControlled =
          !_isEditMode && _activeControlId == control.instanceId;
      final showAffordances = _isEditMode && isSelected;

      final child = ControlWidget(
        control: control,
        isEditMode: _isEditMode,
        isSelected: isSelected,
        isControlled: isControlled,
        // Stable key so the map (and any other stateful control) keeps its
        // State — e.g. the current zoom level — when the widget is
        // selected/deselected and its surrounding tree is rebuilt.
        mapKey: _keyFor(control.instanceId),
        // In edit mode taps are handled by the outer GestureDetector so we
        // can also ignore the control's internal interactions (e.g. map pan,
        // buttons). Passing null here disables the inner InkWell.
        onTap: null,
      );

      // When affordances are visible, expand the layout box by `overhang` on
      // every side so the corner buttons fit inside it and remain hittable.
      final outerLeft = showAffordances ? left - overhang : left;
      final outerTop = showAffordances ? top - overhang : top;
      final outerWidth = showAffordances ? width + affordanceSize : width;
      final outerHeight = showAffordances ? height + affordanceSize : height;

      return Positioned(
        left: outerLeft,
        top: outerTop,
        width: outerWidth,
        height: outerHeight,
        child: _isEditMode
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  // The actual control face is inset by [overhang] on every
                  // side (only when affordances are shown) so its position
                  // and size on the grid stay exactly as before.
                  Positioned(
                    left: showAffordances ? overhang : 0,
                    top: showAffordances ? overhang : 0,
                    width: width,
                    height: height,
                    child: _verticalGraphPointerLayer(
                      control,
                      GestureDetector(
                        // When the control is selected it owns its drag-to-move
                        // gesture, so swallow pointer events (opaque). While it
                        // is *not* selected there is nothing to drag here, so be
                        // translucent: a vertical swipe starting on the control
                        // then falls through to the fullscreen background gesture
                        // layer that opens the top menu.
                        behavior: isSelected
                            ? HitTestBehavior.opaque
                            : HitTestBehavior.translucent,
                        onTap: () => setState(
                          () => _selectedControlId = control.instanceId,
                        ),
                        onLongPress: () => _showControlMenu(control),
                        // A widget must be selected before it can be moved.
                        // While unselected the first tap only selects it (like
                        // non-editing mode); drag/move gestures are ignored so
                        // an accidental pan can't reposition an unselected
                        // widget.
                        onPanStart: isSelected
                            ? (_) => _onControlDragStart(control)
                            : null,
                        onPanUpdate: isSelected
                            ? (details) =>
                                  _onControlDragUpdate(control, details.delta)
                            : null,
                        onPanEnd: isSelected ? (_) => _saveLayout() : null,
                        // Swallow every pointer event before it reaches the
                        // control's own contents so its internal interactions
                        // (map pan/zoom, buttons, list scroll, etc.) are
                        // disabled while the user is arranging the dashboard.
                        child: IgnorePointer(child: child),
                      ),
                    ),
                  ),
                  // Delete button — centered on the top-right corner of the
                  // control. Rendered here (at the enlarged outer layer) so
                  // its full circular area is inside a hittable region.
                  if (showAffordances)
                    Positioned(
                      top: 0,
                      right: 0,
                      width: affordanceSize,
                      height: affordanceSize,
                      child: _CornerButton(
                        icon: Icons.close,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                        onPressed: () => _deleteControl(control.instanceId),
                      ),
                    ),
                  // Resize handle — centered on the bottom-right corner of
                  // the control. Same trick: laid out at the very edge of
                  // the enlarged box so every pixel of it receives gestures.
                  if (showAffordances)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      width: affordanceSize,
                      height: affordanceSize,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => _onControlResizeStart(control),
                        onPanUpdate: (details) =>
                            _onControlResizeUpdate(control, details.delta),
                        onPanEnd: (_) => _saveLayout(),
                        child: Center(
                          child: _ResizeHandle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : (isControlled
                  // Unlocked ("controlled") widget on the current page: let its
                  // internal interactions (map pan/zoom, buttons, list scroll,
                  // etc.) receive pointer events normally. Tapping outside the
                  // control re-locks it (handled by the background gesture
                  // layer above).
                  ? _verticalGraphPointerLayer(control, child)
                  // Default state: the widget is locked and fully static —
                  // acts as a drawable readout only. IgnorePointer swallows
                  // every internal pointer event so nothing inside the control
                  // reacts to taps or drags. A long-press on the widget flips
                  // it into the unlocked ("controlled") state.
                  : GestureDetector(
                      // Translucent so vertical drags starting on a locked
                      // control still reach the fullscreen background gesture
                      // layer that opens the top menu.
                      behavior: HitTestBehavior.translucent,
                      onLongPress: () {
                        setState(() {
                          _activeControlId = control.instanceId;
                        });
                      },
                      child: IgnorePointer(child: child),
                    )),
      );
    }).toList();
  }

  Widget _buildMenuPanel() {
    final maxMenuHeight = MediaQuery.of(context).size.height * 0.88;
    return Container(
      key: _menuKey,
      constraints: BoxConstraints(maxHeight: maxMenuHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Draggable handle region: drag up (or fling up) to close.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              onVerticalDragStart: _onCloseDragStart,
              onVerticalDragUpdate: _onCloseDragUpdate,
              onVerticalDragEnd: _onCloseDragEnd,
              child: SizedBox(
                height: 48 + MediaQuery.of(context).padding.top,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(120),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Menu items — wraps content, scrolls only if it exceeds the cap.
            Flexible(
              child: _MenuContent(
                isEditMode: _isEditMode,
                pageIndex: _currentPage,
                pageCount: _pages.length,
                gridSize: _gridSize,
                controlCount: _controls.length,
                onGridSizeChanged: (value) {
                  setState(() => _gridSize = value);
                  _saveLayout();
                },
                onToggleEditMode: () => _onMenuAction('toggle_edit'),
                onAddControl: () => _onMenuAction('add_control'),
                onAddPage: () => _onMenuAction('add_page'),
                onDeletePage: () {
                  _closeMenu();
                  _deleteCurrentPage();
                },
                onClearAll: () {
                  _closeMenu();
                  _clearAllControls();
                },
                onOpenPreferences: () => _onMenuAction('preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuContent extends StatelessWidget {
  final bool isEditMode;
  final int pageIndex;
  final int pageCount;
  final double gridSize;
  final int controlCount;
  final ValueChanged<double> onGridSizeChanged;
  final VoidCallback onToggleEditMode;
  final VoidCallback onAddControl;
  final VoidCallback onAddPage;
  final VoidCallback onDeletePage;
  final VoidCallback onClearAll;
  final VoidCallback onOpenPreferences;

  const _MenuContent({
    required this.isEditMode,
    required this.pageIndex,
    required this.pageCount,
    required this.gridSize,
    required this.controlCount,
    required this.onGridSizeChanged,
    required this.onToggleEditMode,
    required this.onAddControl,
    required this.onAddPage,
    required this.onDeletePage,
    required this.onClearAll,
    required this.onOpenPreferences,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      // Wrap content height so the panel matches the items (no blank space);
      // scrolls only when the items exceed the panel's max height.
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        SwitchListTile(
          secondary: Icon(_Icons.mode, color: theme.colorScheme.primary),
          title: Text(l10n.editMode),
          subtitle: Text(l10n.pageOfPages(pageIndex + 1, pageCount)),
          value: isEditMode,
          onChanged: (_) => onToggleEditMode(),
        ),
        // Control- and page-editing items are only meaningful in edit mode.
        if (isEditMode) ...[
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.add_box_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(l10n.addControl),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onAddControl,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.note_add_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(l10n.addPage),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: onAddPage,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: pageCount > 1
                  ? theme.colorScheme.error
                  : theme.disabledColor,
            ),
            title: Text(
              l10n.deletePage,
              style: TextStyle(
                color: pageCount > 1
                    ? theme.colorScheme.error
                    : theme.disabledColor,
              ),
            ),
            enabled: pageCount > 1,
            onTap: pageCount > 1 ? onDeletePage : null,
          ),
          const Divider(height: 1),
          // Grid size slider — only meaningful while placing/resizing
          // controls, so it lives under the edit-mode section of the menu.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _Icons.grid,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l10n.gridSize)),
                    Text(
                      l10n.gridSizePx(gridSize.round()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: gridSize.clamp(16.0, 120.0),
                  min: 16.0,
                  max: 120.0,
                  divisions: 26, // step = 4px
                  label: l10n.gridSizePx(gridSize.round()),
                  onChanged: onGridSizeChanged,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_sweep_outlined,
              color: controlCount > 0
                  ? theme.colorScheme.error
                  : theme.disabledColor,
            ),
            title: Text(
              l10n.clearAllControls,
              style: TextStyle(
                color: controlCount > 0
                    ? theme.colorScheme.error
                    : theme.disabledColor,
              ),
            ),
            subtitle: Text(l10n.controlsPlaced(controlCount)),
            enabled: controlCount > 0,
            onTap: controlCount > 0 ? onClearAll : null,
          ),
        ],
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.route, color: theme.colorScheme.primary),
          title: Text(l10n.flights),
          subtitle: Text(l10n.flightsSubtitle),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => showFlightsSheet(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.air, color: theme.colorScheme.primary),
          title: Text(l10n.weather),
          subtitle: Text(l10n.weatherSubtitle),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => showWeatherSheet(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(_Icons.settings, color: theme.colorScheme.primary),
          title: Text(l10n.preferences),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: onOpenPreferences,
        ),
      ],
    );
  }
}

// Icon aliases for cleaner table definition
const _Icons = (
  mode: Icons.edit_outlined,
  grid: Icons.grid_4x4,
  settings: Icons.settings_outlined,
);

/// A small draggable handle used to resize a selected control by its
/// bottom-right corner.
class _ResizeHandle extends StatelessWidget {
  final Color color;

  const _ResizeHandle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.open_in_full, size: 16, color: Colors.white),
    );
  }
}

/// A circular tappable button rendered at a control's corner. The button
/// itself fills its parent square so every pixel of the visual glyph is
/// hittable — used for the "delete control" affordance in edit mode.
class _CornerButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  const _CornerButton({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Center(child: Icon(icon, size: 18, color: foregroundColor)),
      ),
    );
  }
}

class DashGridPainter extends CustomPainter {
  /// Effective cell width/height that divide evenly into the canvas, so the
  /// painted grid lines land exactly on the same boundaries used to lay out
  /// controls (no leftover partial cell at the right/bottom edge).
  final double cellWidth;
  final double cellHeight;

  /// Base color for the grid lines. Derived from the current theme so the grid
  /// is visible on both dark and light backgrounds (hardcoded white was
  /// invisible in light mode).
  final Color lineColor;

  DashGridPainter({
    required this.cellWidth,
    required this.cellHeight,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withAlpha(90)
      ..strokeWidth = 0.5;

    final dashPaint = Paint()
      ..color = lineColor.withAlpha(55)
      ..strokeWidth = 0.5;

    // Integer cell counts; the grid divides the canvas evenly by construction.
    final cols = cellWidth > 0 ? (size.width / cellWidth).round() : 0;
    final rows = cellHeight > 0 ? (size.height / cellHeight).round() : 0;

    // Draw solid grid lines on exact cell boundaries (i == cols/rows lands on
    // the far edge precisely).
    for (int i = 0; i <= cols; i++) {
      final x = i == cols ? size.width : i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int i = 0; i <= rows; i++) {
      final y = i == rows ? size.height : i * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw dashed sub-grid lines at half-cell intervals (only when cells are
    // large enough for the extra detail to be legible).
    if (cellWidth >= 30) {
      for (int i = 0; i < cols; i++) {
        final x = (i + 0.5) * cellWidth;
        _drawDashedLine(
          canvas,
          Offset(x, 0),
          Offset(x, size.height),
          dashPaint,
        );
      }
    }
    if (cellHeight >= 30) {
      for (int i = 0; i < rows; i++) {
        final y = (i + 0.5) * cellHeight;
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), dashPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashGap = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = dx == 0 ? dy.abs() : dx.abs();
    final dirX = dx == 0 ? 0.0 : dx.sign;
    final dirY = dy == 0 ? 0.0 : dy.sign;

    double drawn = 0;
    while (drawn < len) {
      final segment = (drawn + dashWidth > len) ? len - drawn : dashWidth;
      final from = Offset(start.dx + drawn * dirX, start.dy + drawn * dirY);
      final to = Offset(from.dx + segment * dirX, from.dy + segment * dirY);
      canvas.drawLine(from, to, paint);
      drawn += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(DashGridPainter oldDelegate) {
    return cellWidth != oldDelegate.cellWidth ||
        cellHeight != oldDelegate.cellHeight ||
        lineColor != oldDelegate.lineColor;
  }
}
