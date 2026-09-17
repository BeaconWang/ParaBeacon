import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../audio/vario_sound_settings.dart';
import '../data/airspace_store.dart';
import '../data/debug_settings.dart';
import '../data/flight_data_provider.dart';
import '../data/flight_recorder.dart';
import '../data/gcj02.dart';
import '../data/offline_tiles_service.dart';
import '../data/solar_position.dart';
import '../data/thermal_detector.dart';
import '../data/vario_color_scale.dart';
import '../data/wind_estimator.dart';

/// A raster map tile source available to the [MapControl].
@immutable
class MapTileSource {
  const MapTileSource({
    required this.id,
    required this.label,
    required this.urlTemplate,
    required this.attribution,
    this.requiresGcjShift = false,
    this.maxZoom = 18,
    this.isNone = false,
  });

  final String id;
  final String label;
  final String urlTemplate;
  final String attribution;

  /// Chinese providers (AMap) publish GCJ-02 tiles; the WGS-84 aircraft
  /// position must be shifted to GCJ-02 to align with the streets.
  final bool requiresGcjShift;

  final double maxZoom;

  /// When true, no basemap tiles are drawn at all: the map renders overlays
  /// (track, thermal, airspace, position marker) on a plain background.
  final bool isNone;
}

/// All map sources available to the Map control (ported from the reference
/// ParaBeacon `MapTileSourceCatalog`).
///
/// Note: flutter_map >= 6 requires the `{s}` subdomain placeholder to appear
/// only in the URL path, not the hostname, so each source uses a fixed
/// hostname.
class MapTileSources {
  MapTileSources._();

  static const List<MapTileSource> all = [
    MapTileSource(
      id: 'none',
      label: 'None (no basemap)',
      urlTemplate: '',
      attribution: 'No basemap',
      isNone: true,
    ),
    MapTileSource(
      id: 'osm',
      label: 'OpenStreetMap',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap',
    ),
    MapTileSource(
      id: 'osmfr',
      label: 'OSM France (CN-friendly)',
      urlTemplate: 'https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap France',
    ),
    MapTileSource(
      id: 'carto-dark',
      label: 'Carto Dark Matter',
      urlTemplate: 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      attribution: '© OSM · CARTO',
    ),
    MapTileSource(
      id: 'carto-voyager',
      label: 'Carto Voyager',
      urlTemplate:
          'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
      attribution: '© OSM · CARTO',
    ),
    MapTileSource(
      id: 'amap',
      label: '高德地图 (China)',
      urlTemplate:
          'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
      attribution: '© AutoNavi',
      requiresGcjShift: true,
    ),
    MapTileSource(
      id: 'amap-sat',
      label: '高德卫星 (China Satellite)',
      urlTemplate:
          'https://webst01.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}',
      attribution: '© AutoNavi',
      requiresGcjShift: true,
    ),
  ];

  /// Looks up a source by id, defaulting to OSM.
  static MapTileSource byId(String id) {
    return all.firstWhere(
      (s) => s.id == id,
      orElse: () => all.firstWhere((s) => s.id == 'osm'),
    );
  }
}

/// A live slippy-map control that follows the current flight position.
///
/// Renders raster map tiles (see [MapTileSources]) via `flutter_map` and
/// overlays a heading arrow at the current position. When [follow] is on the
/// map re-centers on the aircraft as it moves; the user can pan/zoom freely,
/// and a re-center button restores following.
///
/// Overlays (all optional, controlled by flags): the recorded flight track
/// coloured by vertical speed, a thermal/climb-assistant ring, airspace
/// polygons coloured by proximity, plus HDG/ALT, zoom-level and required-L/D
/// readouts. Offline `.mbtiles` basemaps are used automatically when the user
/// has activated one via [OfflineTilesService].
///
/// Position comes from the unified [FlightDataProvider] feed. On mobile the
/// real device GPS is streamed into that feed by a top-level bridge (see
/// `GpsFlightDataBridge`), so both the map and every other control see the
/// same live position without opening their own geolocator stream. On desktop
/// (where GPS isn't available) the feed simply falls back to the BLE sensor
/// or the debug simulator.
class MapControl extends StatefulWidget {
  /// Initial zoom level (flutter_map zoom, ~1..19).
  final double initialZoom;

  /// Whether the map re-centers on the current position as it updates.
  final bool follow;

  /// Tile source id (see [MapTileSources]).
  final String tileSource;

  /// Draw the recorded flight track (coloured by vertical speed).
  final bool showTrack;

  /// Draw the thermal / climb-assistant ring when climbing.
  final bool showThermal;

  /// Draw airspace polygons (only visible when airspace data is loaded).
  final bool showAirspace;

  /// Rotate the map so the current heading points up ("track up"). When false
  /// the map stays north-up. Ported from XCTrack's Thermal Assistant rotation
  /// setting.
  final bool trackUp;

  /// Draw a small fixed North indicator (arrow + "N") in the top-right, which
  /// is useful when the map is rotated (track-up).
  final bool showNorth;

  /// Multiplier for the pilot position arrow size (1.0 == default). Mirrors
  /// XCTrack's "Pilot arrow size coefficient".
  final double pilotArrowCoef;

  /// Multiplier for the flight-track / bearing line stroke width (1.0 ==
  /// default). Mirrors XCTrack's "Thickness of lines".
  final double lineThickness;

  /// Only draw the most recent N minutes of the flight track. 0 means draw the
  /// whole track. Mirrors XCTrack's "Tracklog length".
  final double tracklogMinutes;

  /// Number of previously-worked thermal cores to mark on the map. 0 hides
  /// them. Mirrors XCTrack's "Show N latest thermals".
  final int latestThermals;

  /// How wind is included in the thermal computation: 'none', 'classic' or
  /// 'particle'. Mirrors XCTrack's "How to include wind into computation".
  final String windAlgorithm;

  /// Draw a wind indicator (arrow + speed) in the corner.
  final bool showWind;

  /// Draw a sun-position marker at the sun's azimuth on the map edge.
  final bool showSun;

  /// Draw a bearing (course) line from the aircraft along its ground track.
  final bool showBearing;

  /// Draw a straight line from the current position back to the take-off
  /// point (the first fixed sample of the in-progress flight).
  final bool showTakeoffLine;

  /// Draw the ground-distance scale ruler (bottom-left).
  final bool showScale;

  /// Prefer an activated offline `.mbtiles` basemap over online tiles.
  final bool useOffline;

  /// Show the vario colour-scale legend (bottom-centre).
  final bool showLegend;

  /// Show the zoom-level readout chip (top-right).
  final bool showZoomLevel;

  /// Show the map attribution / offline-source chip (top-right).
  final bool showAttribution;

  /// Show the HDG/ALT readout and the "No GPS fix" status chip (top-left).
  final bool showStatus;

  /// Whether this map is the currently active/selected widget. The operation
  /// buttons (zoom in/out, re-center, reset-north) are only shown while the
  /// map is selected; when it isn't, the map is a static readout with no
  /// controls, matching the rest of the dashboard.
  final bool active;

  const MapControl({
    super.key,
    this.initialZoom = 17.0,
    this.follow = true,
    this.tileSource = 'osm',
    this.showTrack = true,
    this.showThermal = true,
    this.showAirspace = true,
    this.trackUp = false,
    this.showNorth = false,
    this.pilotArrowCoef = 1.0,
    this.lineThickness = 1.0,
    this.tracklogMinutes = 0.0,
    this.latestThermals = 8,
    this.windAlgorithm = 'classic',
    this.showWind = true,
    this.showSun = false,
    this.showBearing = false,
    this.showTakeoffLine = false,
    this.showScale = true,
    this.useOffline = true,
    this.showLegend = false,
    this.showZoomLevel = true,
    this.showAttribution = true,
    this.showStatus = true,
    this.active = false,
  });

  @override
  State<MapControl> createState() => _MapControlState();
}

class _MapControlState extends State<MapControl> {
  final MapController _map = MapController();

  /// Broadcast stream used to force [TileLayer] to drop error tiles and
  /// re-fetch them after a transient network failure. See [_onTileLoadError]
  /// for why this exists and how the retry backoff works.
  final StreamController<void> _tileResetCtrl =
      StreamController<void>.broadcast();

  /// Backoff timer for the tile-reload retry. Coalesces bursts of tile errors
  /// (e.g. dozens of tiles failing at once on Wi-Fi drop) into a single reset.
  Timer? _tileRetryTimer;

  /// Growing backoff (seconds) between successive resets while errors persist,
  /// so we don't hammer the network. Reset to the base on the first successful
  /// build after a reset.
  int _tileRetrySeconds = 2;

  /// Monotonic retry generation. Folded into the [TileLayer] key so that each
  /// retry recreates the layer and forces a full re-request of the visible
  /// tiles. This is the reliable recovery path: flutter_map's `reset` stream
  /// subscription is a `late final` that is effectively never activated during
  /// normal operation, so a first-load failure would otherwise never heal.
  int _tileRetryGen = 0;

  /// Timestamp of the last tile-load error, used to reset the retry backoff
  /// once errors have stopped for a while (fresh transient blip should not
  /// inherit an old exponential delay).
  DateTime _lastTileError = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the map is currently following the aircraft. Turned off when the
  /// user pans/zooms manually, restored by the re-center button.
  late bool _follow = widget.follow;

  /// Whether the map widget has been laid out and is ready for programmatic
  /// moves (calling [MapController.move] before the first frame throws).
  bool _ready = false;

  /// Current map rotation in degrees (0 = north up). Tracked so we can show
  /// a "reset north" affordance whenever the user has rotated the map.
  double _rotationDeg = 0.0;

  /// Current zoom level, mirrored from the camera so the readout and zoom
  /// buttons stay in sync with pinch gestures.
  late double _zoom = widget.initialZoom;

  /// Last WGS-84 position pushed to the map (for re-center / follow).
  LatLng? _lastWgs;

  /// Last heading (deg) seen from the feed, used for track-up rotation and the
  /// bearing line.
  double _lastHeading = 0.0;

  /// Self-contained thermal detector fed from the flight-data / GPS feed.
  final ThermalDetector _thermalDetector = ThermalDetector();
  ThermalHint? _thermal;

  /// Self-contained wind estimator fed from GPS ground velocity while
  /// circling. Used as a fallback when the sensor feed has no wind reading,
  /// and to drift-compensate the thermal core.
  final WindEstimator _windEstimator = WindEstimator();

  /// Most recent wind estimate (sensor-provided when available, otherwise
  /// derived from circling). Null until enough data / no wind.
  WindEstimate? _wind;

  /// Latest airspace proximity list (drives boundary colouring).
  List<AirspaceProximity> _airspaceProximity = const [];
  StreamSubscription<List<AirspaceProximity>>? _airspaceSub;

  /// Vario → colour scale for the flight track. Rebuilt from the live
  /// [VarioSoundSettings] thresholds whenever the user changes them, so the
  /// track (and legend) recolour dynamically.
  late VarioColorScale _varioScale = _buildVarioScale();

  VarioColorScale _buildVarioScale() {
    final s = VarioSoundSettings.instance;
    return VarioColorScale(
      sinkThreshold: s.sinkThreshold,
      liftThreshold: s.liftThreshold,
    );
  }

  @override
  void initState() {
    super.initState();
    _airspaceProximity = AirspaceStore.instance.lastProximity;
    _airspaceSub = AirspaceStore.instance.proximityStream.listen((l) {
      if (mounted) setState(() => _airspaceProximity = l);
    });
    // Rebuild the tile layer when the active offline source changes, and when
    // the recorder appends new track points.
    OfflineTilesService.instance.revision.addListener(_onExternalChange);
    FlightRecorder.instance.addListener(_onExternalChange);
    // Recolour the track/legend when the vario thresholds change.
    VarioSoundSettings.instance.addListener(_onThresholdsChanged);
    // React to the debug simulator being toggled on/off: when it turns on the
    // map should immediately switch to the simulated position (highest
    // priority), and when it turns off fall back to real device GPS / BLE.
    DebugSettings.instance.addListener(_onExternalChange);
  }

  @override
  void didUpdateWidget(covariant MapControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.follow != widget.follow) {
      _follow = widget.follow;
    }
    // Switching rotation mode: snap back to north-up when leaving track-up, and
    // re-apply the heading rotation when entering it.
    if (oldWidget.trackUp != widget.trackUp) {
      if (!widget.trackUp && _ready) {
        _map.rotate(0);
        _rotationDeg = 0;
      } else if (widget.trackUp) {
        final p = _lastWgs;
        if (p != null) _maybeFollow(p);
      }
    }
  }

  @override
  void dispose() {
    _tileRetryTimer?.cancel();
    _tileResetCtrl.close();
    _airspaceSub?.cancel();
    OfflineTilesService.instance.revision.removeListener(_onExternalChange);
    FlightRecorder.instance.removeListener(_onExternalChange);
    VarioSoundSettings.instance.removeListener(_onThresholdsChanged);
    DebugSettings.instance.removeListener(_onExternalChange);
    super.dispose();
  }

  /// Called by [TileLayer.errorTileCallback] whenever a tile fails to load
  /// (transient DNS failure, captive portal, cellular blip, HTTP 5xx …).
  ///
  /// Without this, flutter_map keeps the failed tile as a permanent hole:
  /// the tile stays in the image cache tagged `loadError = true` and is only
  /// re-fetched when the camera moves enough to evict it. That is the root
  /// cause of the "map sometimes doesn't load" bug — a couple of tiles fail
  /// during startup, the user isn't panning yet, and the holes never heal.
  ///
  /// The fix: coalesce error bursts into a single delayed reset broadcast
  /// on [_tileResetCtrl], which [TileLayer] listens to and reacts to by
  /// dropping all tiles (per its `evictErrorTileStrategy`) and re-requesting
  /// the visible range. Backoff grows on repeated failures so we don't hammer
  /// an offline network.
  void _onTileLoadError(dynamic tile, Object error, StackTrace? _) {
    if (!mounted) return;
    final now = DateTime.now();
    // If it's been quiet for > 15s since the last error, treat this as a
    // fresh incident and start over from the base backoff — otherwise a long
    // idle followed by one blip would inherit a 30s cooldown.
    if (now.difference(_lastTileError) > const Duration(seconds: 15)) {
      _tileRetrySeconds = 2;
    }
    _lastTileError = now;
    if (_tileRetryTimer?.isActive ?? false) return;
    final delay = Duration(seconds: _tileRetrySeconds);
    _tileRetryTimer = Timer(delay, () {
      if (!mounted || _tileResetCtrl.isClosed) return;
      // Belt-and-suspenders: broadcast on the reset stream (in case a future
      // flutter_map version wires it up reliably)...
      _tileResetCtrl.add(null);
      // ...and, the part that actually recovers a first-load failure: bump the
      // retry generation so the TileLayer key changes and the layer is rebuilt
      // from scratch, re-requesting every visible tile.
      setState(() => _tileRetryGen++);
      // Exponential-ish backoff, capped at 30s so recovery stays snappy once
      // connectivity comes back but idle retries don't spam the radio.
      _tileRetrySeconds = math.min(_tileRetrySeconds * 2, 30);
    });
  }

  void _onExternalChange() {
    if (mounted) setState(() {});
  }

  void _onThresholdsChanged() {
    if (!mounted) return;
    setState(() => _varioScale = _buildVarioScale());
  }

  /// (Device GPS is streamed at app scope by `GpsFlightDataBridge` and merged
  /// into the unified [FlightDataProvider] feed, so the map reads it through
  /// the shared source with no per-widget subscription.)

  /// Re-centers the map on [pos] when following (and ready). In track-up mode
  /// the camera is also rotated so the current heading points up.
  void _maybeFollow(LatLng pos) {
    _lastWgs = pos;
    if (!_follow || !_ready) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ready || !_follow) return;
      final shifted = _shift(pos, widget.tileSource);
      if (widget.trackUp) {
        // flutter_map rotation is measured counter-clockwise, so to bring the
        // heading (clockwise from north) to the top we rotate by -heading.
        _map.moveAndRotate(shifted, _map.camera.zoom, -_lastHeading);
      } else {
        _map.move(shifted, _map.camera.zoom);
      }
    });
  }

  /// Applies the GCJ-02 offset when the active [sourceId] needs it, so the
  /// WGS-84 [wgs] position aligns with the tiles. Offline mbtiles are assumed
  /// WGS-84 (no shift).
  LatLng _shift(LatLng wgs, String sourceId) {
    if (_offlineActive) return wgs;
    final src = MapTileSources.byId(sourceId);
    if (!src.requiresGcjShift) return wgs;
    final p = Gcj02.wgsToGcj(wgs.latitude, wgs.longitude);
    return LatLng(p[0], p[1]);
  }

  bool get _offlineActive =>
      widget.useOffline && OfflineTilesService.instance.isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = FlightDataProvider.of(context);
    final src = MapTileSources.byId(widget.tileSource);

    // Position source: everything now flows through the unified flight-data
    // feed. The GPS bridge (see `GpsFlightDataBridge`) pushes device GPS into
    // that feed at app scope, the BLE sensor pushes barometric/vertical-speed
    // fields, and the debug simulator (when enabled) supplies its synthetic
    // position. Whatever won inside [FlightDataProvider] is what we render.
    LatLng? wgs;
    final double climb = data.verticalSpeed;
    final double heading = data.heading;
    final double altMsl = data.altitude;
    final double groundMps = data.groundSpeed / 3.6; // km/h -> m/s
    if (data.hasFix) {
      wgs = LatLng(data.latitude, data.longitude);
    }
    final hasFix = wgs != null;

    if (hasFix) {
      _lastHeading = heading;
      _maybeFollow(wgs);
      // Feed the thermal detector + airspace proximity from the live fix.
      _thermal = _thermalDetector.add(
        lat: wgs.latitude,
        lon: wgs.longitude,
        climbMps: climb,
      );
      AirspaceStore.instance
          .updatePosition(wgs.latitude, wgs.longitude, altMsl);
      // Wind: prefer a real sensor reading; otherwise fall back to the
      // circling estimator so the map can still show/use wind.
      final estimate = _windEstimator.add(
        groundSpeedMps: groundMps,
        headingDeg: heading,
      );
      if (data.windSpeed > 0.1) {
        _wind = WindEstimate(
          fromDirectionDeg: data.windDirection,
          speedMps: data.windSpeed / 3.6,
          confident: true,
        );
      } else {
        _wind = estimate;
      }
    }

    // Render position in the tile coordinate system (GCJ-shifted if needed).
    final renderPos = hasFix
        ? _shift(wgs, widget.tileSource)
        : _shift(const LatLng(46.5197, 6.6323), widget.tileSource);

    return _SuppressPageSwipe(
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: renderPos,
                initialZoom: widget.initialZoom,
                minZoom: 2,
                maxZoom: src.maxZoom,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _follow) {
                    setState(() => _follow = false);
                  }
                  // Keep the reset-north button + zoom readout in sync with the
                  // live camera. Rebuild only when values actually change to
                  // avoid per-frame setState churn while panning.
                  final rotChanged =
                      (camera.rotation - _rotationDeg).abs() > 0.01;
                  final zoomChanged = (camera.zoom - _zoom).abs() > 0.01;
                  if (rotChanged || zoomChanged) {
                    setState(() {
                      _rotationDeg = camera.rotation;
                      _zoom = camera.zoom;
                    });
                  }
                },
                onMapReady: () {
                  _ready = true;
                  final p = _lastWgs;
                  if (p != null) _maybeFollow(p);
                },
              ),
              children: [
                _buildTileLayer(src),

                // "None" basemap: draw a dashed reference grid so the user
                // still has a sense of scale and orientation on the blank
                // background. Skipped when an offline basemap is active.
                if (src.isNone && !_offlineActive)
                  _DashedGridLayer(
                    color: theme.colorScheme.onSurface.withAlpha(46),
                    labelColor: theme.colorScheme.onSurfaceVariant,
                  ),

                // Airspace polygons (below track/markers so labels stay legible).
                if (widget.showAirspace)
                  PolygonLayer(polygons: _buildAirspacePolygons()),

                // Bearing (course) line projected ahead along the ground track.
                if (widget.showBearing && hasFix)
                  PolylineLayer(
                    polylines: [_buildBearingLine(renderPos, heading)],
                  ),

                // Straight line from the current position back to take-off.
                if (widget.showTakeoffLine && hasFix)
                  Builder(builder: (context) {
                    final line = _buildTakeoffLine(renderPos);
                    return line == null
                        ? const SizedBox.shrink()
                        : PolylineLayer(polylines: [line]);
                  }),

                // Recorded flight track coloured by vertical speed.
                if (widget.showTrack)
                  PolylineLayer(polylines: _buildTrackPolylines()),

                // Previously-worked thermal cores ("N latest thermals").
                if (widget.showThermal && widget.latestThermals > 0)
                  CircleLayer(circles: _buildHistoryThermalCircles()),

                // Thermal / climb-assistant ring (current core).
                if (widget.showThermal && _thermal != null)
                  CircleLayer(circles: [_buildThermalCircle(_thermal!)]),

                if (hasFix)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: renderPos,
                        width: 40 * widget.pilotArrowCoef,
                        height: 40 * widget.pilotArrowCoef,
                        child: _HeadingMarker(
                          // In track-up mode the map itself is rotated so the
                          // heading points up; the arrow then stays fixed
                          // pointing up (relative to the rotated map).
                          heading: widget.trackUp ? 0 : heading,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),

                // Sun-position marker: a sun glyph placed along its azimuth
                // bearing from the aircraft, so the pilot can read where the
                // sun is relative to the terrain.
                if (widget.showSun && hasFix)
                  MarkerLayer(markers: _buildSunMarkers(wgs, renderPos)),

                // Ground-distance scale ruler (bottom-left), screen-fixed.
                if (widget.showScale)
                  _ScaleBarLayer(
                    color: theme.colorScheme.onSurface.withAlpha(200),
                    background: theme.colorScheme.surface.withAlpha(150),
                  ),
              ],
            ),
          ),

          if (!hasFix && widget.showStatus)
            Positioned(
              left: 8,
              top: 8,
              child:
                  _glassChip(theme, icon: Icons.gps_off, label: 'No GPS fix'),
            ),

          // Top-left: HDG / ALT readout (only with a fix).
          if (hasFix && widget.showStatus)
            Positioned(
              left: 8,
              top: 8,
              child: _glassChip(
                theme,
                label: 'HDG ${heading.round()}°  ·  ALT ${altMsl.round()}m',
                small: true,
              ),
            ),

          // Wind indicator (arrow pointing the way the wind blows *to*, plus
          // the speed it comes *from*). Sits under the HDG/ALT chip when that
          // is shown, otherwise at the top-left corner.
          if (widget.showWind && hasFix && _wind != null)
            Positioned(
              left: 8,
              top: (hasFix && widget.showStatus) ? 34 : 8,
              child: _WindIndicator(
                wind: _wind!,
                // In track-up mode the arrow must be counter-rotated so it
                // still points at the true wind direction on screen.
                mapRotationDeg: _rotationDeg,
                color: theme.colorScheme.onSurfaceVariant,
                background: theme.colorScheme.surface.withAlpha(180),
              ),
            ),

          // Bottom-left: required L/D readout (feature 31).
          Positioned(
            left: 8,
            bottom: 8,
            child: _glassChip(
              theme,
              icon: Icons.trending_down,
              label: 'L/D REQ ${_ldReqStr(data)}',
              small: true,
            ),
          ),

          // Bottom-center: vario colour-scale legend (feature 20 legend).
          // Requires the track layer to be enabled (the legend explains the
          // track's colours) and its own toggle; hidden by default.
          if (widget.showTrack && widget.showLegend)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: _VarioLegend(
                  scale: _varioScale,
                  background: theme.colorScheme.surface.withAlpha(180),
                  textColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          // Top-right: zoom-level readout (feature 32) + attribution. Each has
          // its own toggle; the whole column is omitted when both are hidden.
          if (widget.showZoomLevel || widget.showAttribution)
            Positioned(
              right: 4,
              top: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.showNorth) ...[
                    _NorthIndicator(
                      rotationDeg: _rotationDeg,
                      color: theme.colorScheme.onSurfaceVariant,
                      background: theme.colorScheme.surface.withAlpha(180),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (widget.showZoomLevel)
                    _glassChip(theme, label: 'Z ${_zoom.toStringAsFixed(1)}',
                        small: true),
                  if (widget.showZoomLevel && widget.showAttribution)
                    const SizedBox(height: 4),
                  if (widget.showAttribution)
                    _glassChip(
                      theme,
                      label: _offlineActive
                          ? 'Offline · ${OfflineTilesService.instance.activeFileName}'
                          : src.attribution,
                      small: true,
                    ),
                ],
              ),
            ),

          // Standalone North indicator when both zoom + attribution are hidden
          // (otherwise it lives in that top-right column above).
          if (widget.showNorth &&
              !(widget.showZoomLevel || widget.showAttribution))
            Positioned(
              right: 4,
              top: 4,
              child: _NorthIndicator(
                rotationDeg: _rotationDeg,
                color: theme.colorScheme.onSurfaceVariant,
                background: theme.colorScheme.surface.withAlpha(180),
              ),
            ),

          // Column of map affordances stacked in the bottom-right corner.
          // Only shown while the map widget is selected/active; otherwise the
          // map is a static readout with no operation buttons.
          if (widget.active)
            Positioned(
              right: 8,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_rotationDeg.abs() > 0.5) ...[
                    _CompassButton(
                      rotationDeg: _rotationDeg,
                      onTap: _resetNorth,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!_follow) ...[
                    _MapButton(
                      icon: Icons.my_location,
                      tooltip: 'Re-center',
                      onTap: () {
                        setState(() => _follow = true);
                        final p = _lastWgs;
                        if (p != null && _ready) {
                          _map.move(
                              _shift(p, widget.tileSource), _map.camera.zoom);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Zoom in / out buttons (feature 15).
                  _MapButton(
                    icon: Icons.add,
                    tooltip: 'Zoom in',
                    onTap: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom out',
                    onTap: () => _zoomBy(-1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the base tile layer: an activated offline `.mbtiles` source takes
  /// precedence, otherwise the selected online source.
  Widget _buildTileLayer(MapTileSource src) {
    if (_offlineActive) {
      final tp = OfflineTilesService.instance.tileProvider();
      if (tp != null) {
        return TileLayer(
          key: ValueKey(
              'offline-${OfflineTilesService.instance.activeFileName}-r$_tileRetryGen'),
          tileProvider: tp,
          maxNativeZoom: 19,
          userAgentPackageName: 'com.beacon.parabeacon',
          // Even mbtiles reads can fail (file busy, corrupt tile); use the
          // same retry path as online tiles so we recover instead of leaving
          // permanent blanks.
          errorTileCallback: _onTileLoadError,
          evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
          reset: _tileResetCtrl.stream,
        );
      }
    }
    // "None" basemap: draw no tiles at all, leaving only the overlays
    // (track / thermal / airspace / position marker) on a plain background.
    if (src.isNone) {
      return const SizedBox.shrink();
    }
    // NOTE (Android blank-map fix): do NOT set a custom `User-Agent` via
    // NetworkTileProvider(headers:). On Android, dart:io's HttpClient silently
    // drops the header, so tiles go out with the default `Dart/x.y (dart:io)`
    // UA — which OSM's tile usage policy rejects (403/418), leaving the map
    // blank. flutter_map's own `userAgentPackageName` correctly formats an
    // accepted UA (`<pkg>/flutter_map/<ver>`) on every platform, so we rely on
    // that instead. Keep it in sync with the offline branch above.
    //
    // Retry / recovery: transient network errors (cell handoff, Wi-Fi drop,
    // captive portal) leave individual tiles in a permanent `loadError` state
    // in flutter_map's cache, appearing as "the map won't load sometimes".
    // We opt into `notVisibleRespectMargin` so the eviction actually kicks in
    // when tiles leave the buffer, wire up `errorTileCallback` to schedule a
    // reset, and pipe a broadcast [_tileResetCtrl] stream into `reset` so the
    // layer drops failed tiles and re-requests the visible range without
    // waiting for the user to pan.
    return TileLayer(
      key: ValueKey('${src.id}-r$_tileRetryGen'),
      urlTemplate: src.urlTemplate,
      maxNativeZoom: src.maxZoom.round(),
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
      keepBuffer: 3,
      panBuffer: 2,
      userAgentPackageName: 'com.beacon.parabeacon',
      errorTileCallback: _onTileLoadError,
      reset: _tileResetCtrl.stream,
    );
  }

  /// Zooms in/out by [delta] levels, clamped to the source's range.
  void _zoomBy(double delta) {
    if (!_ready) return;
    final src = MapTileSources.byId(widget.tileSource);
    final next = (_map.camera.zoom + delta).clamp(2.0, src.maxZoom);
    _map.move(_map.camera.center, next);
    setState(() => _zoom = next);
  }

  /// Rotates the map back to north-up. No-op when the map isn't ready or is
  /// already aligned.
  void _resetNorth() {
    if (!_ready) return;
    _map.rotate(0);
    setState(() => _rotationDeg = 0);
  }

  // ── Overlay builders ───────────────────────────────────────────────────────

  /// Builds the recorded-flight-track polylines, coloured by vertical speed
  /// with a continuous gradient (feature 20).
  ///
  /// Each track segment (pair of consecutive points) becomes its own short
  /// [Polyline] tinted by that segment's vario, so the colour varies smoothly
  /// along the track rather than in a few discrete bands. Adjacent segments of
  /// identical colour are merged to keep the layer element count low.
  List<Polyline> _buildTrackPolylines() {
    final track = FlightRecorder.instance.currentTrack;
    final all = track?.samples ?? const [];
    if (all.length < 2) return const [];

    // Tracklog length: keep only the most recent N minutes when configured
    // (0 == draw the whole track). Mirrors XCTrack's "Tracklog length".
    final List<dynamic> samples;
    if (widget.tracklogMinutes > 0) {
      final cutoff = DateTime.now()
          .subtract(Duration(seconds: (widget.tracklogMinutes * 60).round()));
      final start = all.indexWhere((s) => s.time.isAfter(cutoff));
      samples = start <= 0 ? all : all.sublist(math.max(0, start - 1));
    } else {
      samples = all;
    }
    if (samples.length < 2) return const [];

    // Lightly decimate very long tracks to keep rendering smooth.
    const cap = 2000;
    final List<dynamic> pts;
    if (samples.length <= cap) {
      pts = samples;
    } else {
      final step = samples.length / cap;
      pts = [
        for (int i = 0; i < cap; i++) samples[(i * step).floor()],
        samples.last,
      ];
    }

    LatLng at(int i) {
      final d = pts[i].data;
      return _shift(LatLng(d.latitude, d.longitude), widget.tileSource);
    }

    double vario(int i) => (pts[i].data.verticalSpeed as double);

    final strokeWidth = 3.0 * widget.lineThickness;
    final out = <Polyline>[];
    int runStart = 0;
    // A segment's colour is derived from the vario at its *end* point via the
    // threshold-aware [VarioColorScale].
    Color runColor = _varioScale.colorFor(vario(1));

    void flush(int endExclusive) {
      if (endExclusive - runStart < 2) return;
      out.add(Polyline(
        points: [for (int i = runStart; i < endExclusive; i++) at(i)],
        strokeWidth: strokeWidth,
        color: runColor,
      ));
    }

    for (int i = 2; i < pts.length; i++) {
      final c = _varioScale.colorFor(vario(i));
      if (c != runColor) {
        flush(i);
        runStart = i - 1; // share the endpoint for visual continuity
        runColor = c;
      }
    }
    flush(pts.length);
    return out;
  }

  /// Builds a bearing (course) line extending ahead of the aircraft along its
  /// current ground track, so the pilot can see where the current heading
  /// leads. Length scales inversely with zoom so it stays a sensible on-screen
  /// size.
  Polyline _buildBearingLine(LatLng from, double headingDeg) {
    // Ground distance for the line: longer when zoomed out, shorter zoomed in.
    final meters = (2000.0 * math.pow(2, 15 - _zoom)).clamp(150.0, 20000.0);
    const mPerDegLat = 111320.0;
    final mPerDegLon =
        mPerDegLat * math.cos(from.latitude * math.pi / 180.0).abs();
    final rad = headingDeg * math.pi / 180.0;
    // In tile space we've already GCJ-shifted `from`; project the endpoint in
    // the same (shifted) frame so the line stays anchored to the marker.
    final dLat = (meters * math.cos(rad)) / mPerDegLat;
    final dLon = (meters * math.sin(rad)) /
        (mPerDegLon < 1e-6 ? 1e-6 : mPerDegLon);
    final to = LatLng(from.latitude + dLat, from.longitude + dLon);
    return Polyline(
      points: [from, to],
      strokeWidth: 2.5 * widget.lineThickness,
      color: const Color(0xFF2196F3),
    );
  }

  /// Builds a straight line from the current position [to] back to the
  /// take-off point of the in-progress flight, or null when there is no
  /// take-off reference yet (no recording, or no fixed sample recorded).
  ///
  /// The take-off point is the first recorded sample that carries a GPS fix.
  /// Its coordinates are GCJ-shifted the same way as the live position so the
  /// line stays anchored to the tiles on AMap sources.
  Polyline? _buildTakeoffLine(LatLng to) {
    final track = FlightRecorder.instance.currentTrack;
    final samples = track?.samples ?? const [];
    if (samples.isEmpty) return null;

    dynamic takeoff;
    for (final s in samples) {
      if (s.data.hasFix == true) {
        takeoff = s;
        break;
      }
    }
    // Fall back to the very first sample if none is flagged as fixed.
    takeoff ??= samples.first;

    final d = takeoff.data;
    final from = _shift(
      LatLng(d.latitude as double, d.longitude as double),
      widget.tileSource,
    );
    return Polyline(
      points: [from, to],
      strokeWidth: 2.0 * widget.lineThickness,
      // Dashed magenta so it reads distinctly from the blue bearing line and
      // the vario-coloured track.
      color: const Color(0xFFE040FB),
      pattern: StrokePattern.dashed(segments: const [8, 6]),
    );
  }

  /// Builds faded rings for the most recent previously-worked thermal cores
  /// (XCTrack's "Show N latest thermals"), oldest most faded.
  List<CircleMarker> _buildHistoryThermalCircles() {
    final history = _thermalDetector.history;
    if (history.isEmpty) return const [];
    final take =
        history.length > widget.latestThermals ? widget.latestThermals : history.length;
    final start = history.length - take;
    final out = <CircleMarker>[];
    for (int i = start; i < history.length; i++) {
      final t = history[i];
      // Newer entries are more opaque; older ones fade out.
      final age = (i - start) / take; // 0 (oldest) .. ~1 (newest)
      final alpha = (30 + 60 * age).round().clamp(20, 120);
      final strong = t.avgClimbMps >= 2.0;
      final color = strong ? const Color(0xFF13FF43) : const Color(0xFFD4FF6A);
      final drifted = _applyWindDrift(t.centerLat, t.centerLon);
      out.add(CircleMarker(
        point: _shift(LatLng(drifted[0], drifted[1]), widget.tileSource),
        radius: t.radiusM,
        useRadiusInMeter: true,
        color: color.withAlpha((alpha * 0.4).round()),
        borderColor: color.withAlpha(alpha + 60),
        borderStrokeWidth: 1.5,
      ));
    }
    return out;
  }

  /// Builds the thermal/climb-assistant ring at the detected core (feature 27).
  CircleMarker _buildThermalCircle(ThermalHint t) {
    final drifted = _applyWindDrift(t.centerLat, t.centerLon);
    final pos = _shift(LatLng(drifted[0], drifted[1]), widget.tileSource);
    // Greener the stronger the climb.
    final strong = t.avgClimbMps >= 2.0;
    final color = strong ? const Color(0xFF13FF43) : const Color(0xFFD4FF6A);
    return CircleMarker(
      point: pos,
      radius: t.radiusM,
      useRadiusInMeter: true,
      color: color.withAlpha(38),
      borderColor: color,
      borderStrokeWidth: 2,
    );
  }

  /// Applies wind-drift compensation to a thermal core position according to
  /// [MapControl.windAlgorithm] and the current [_wind] estimate.
  ///
  /// A thermal drifts downwind as it rises, so the lift a climbing pilot is
  /// actually working sits slightly *upwind* of the raw circling centroid.
  /// Shifting the drawn core upwind keeps the ring centred on the useful lift.
  /// Returns `[lat, lon]`.
  List<double> _applyWindDrift(double lat, double lon) {
    final w = _wind;
    if (w == null || widget.windAlgorithm == 'none' || w.speedMps < 0.5) {
      return [lat, lon];
    }
    // Shift distance: a few seconds of wind travel. Particle-drift uses a
    // longer horizon than classic, matching XCTrack's stronger correction.
    final seconds = widget.windAlgorithm == 'particle' ? 12.0 : 6.0;
    final shiftM = w.speedMps * seconds;
    // Move upwind: the wind comes *from* `fromDirectionDeg`, so upwind is
    // towards that bearing.
    final rad = w.fromDirectionDeg * math.pi / 180.0;
    const mPerDegLat = 111320.0;
    final mPerDegLon = mPerDegLat * math.cos(lat * math.pi / 180.0).abs();
    final dLat = (shiftM * math.cos(rad)) / mPerDegLat;
    final dLon =
        (shiftM * math.sin(rad)) / (mPerDegLon < 1e-6 ? 1e-6 : mPerDegLon);
    return [lat + dLat, lon + dLon];
  }

  /// Builds the sun-position marker(s): a sun glyph placed a fixed on-screen
  /// distance from the aircraft along the sun's azimuth. Hidden when the sun
  /// is below the horizon.
  List<Marker> _buildSunMarkers(LatLng wgs, LatLng renderPos) {
    final sun = SolarCalculator.at(wgs.latitude, wgs.longitude);
    if (!sun.isUp) return const [];
    // Place the glyph a distance ahead along the azimuth that scales with
    // zoom, so it stays a comfortable distance from the pilot marker.
    final meters = (600.0 * math.pow(2, 15 - _zoom)).clamp(80.0, 8000.0);
    const mPerDegLat = 111320.0;
    final mPerDegLon =
        mPerDegLat * math.cos(renderPos.latitude * math.pi / 180.0).abs();
    final rad = sun.azimuthDeg * math.pi / 180.0;
    final dLat = (meters * math.cos(rad)) / mPerDegLat;
    final dLon =
        (meters * math.sin(rad)) / (mPerDegLon < 1e-6 ? 1e-6 : mPerDegLon);
    final sunPos =
        LatLng(renderPos.latitude + dLat, renderPos.longitude + dLon);
    return [
      Marker(
        point: sunPos,
        width: 34,
        height: 34,
        child: _SunMarker(elevationDeg: sun.elevationDeg),
      ),
    ];
  }

  /// Builds altitude-aware airspace polygons (feature 19).
  List<Polygon> _buildAirspacePolygons() {
    final airspaces = AirspaceStore.instance.all;
    if (airspaces.isEmpty) return const [];
    final out = <Polygon>[];
    for (final a in airspaces.take(80)) {
      if (a.polygon.length < 3) continue;
      final color = _airspaceColor(a);
      out.add(Polygon(
        points: a.polygon
            .map((pt) => _shift(LatLng(pt[0], pt[1]), widget.tileSource))
            .toList(growable: false),
        borderColor: color,
        borderStrokeWidth: a.severity == AirspaceSeverity.high ? 2 : 1,
        color: color.withAlpha(20),
      ));
    }
    return out;
  }

  /// Picks a boundary colour by proximity: inside = red, near = orange,
  /// else grey (bolder for high-severity classes).
  Color _airspaceColor(Airspace a) {
    final pr = _airspaceProximity.firstWhere(
      (p) => p.airspace.name == a.name,
      orElse: () => AirspaceProximity(
        airspace: a,
        horizontalM: double.infinity,
        verticalM: double.infinity,
        inside: false,
      ),
    );
    if (pr.inside) return const Color(0xFFFF3B30); // red: penetrating
    if (pr.horizontalM < 1000 || pr.verticalM < 200) {
      return const Color(0xFFFF9800); // orange: about to enter
    }
    return a.severity == AirspaceSeverity.high
        ? const Color(0xFF9E9E9E)
        : const Color(0x889E9E9E);
  }

  /// Required glide ratio to sustain the current descent: ground speed / sink.
  /// Only meaningful while sinking (vertical speed < 0).
  String _ldReqStr(dynamic data) {
    final v = data.verticalSpeed as double; // m/s (+climb / -sink)
    if (v >= -0.1) return '--';
    final groundMps = (data.groundSpeed as double) / 3.6; // km/h -> m/s
    final ld = groundMps / -v;
    if (!ld.isFinite || ld <= 0) return '--';
    if (ld >= 100) return '99+';
    return ld.toStringAsFixed(1);
  }

  Widget _glassChip(
    ThemeData theme, {
    IconData? icon,
    required String label,
    bool small = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(180),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: (small
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium)
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A map layer that paints a dashed reference grid, used as a stand-in for the
/// basemap when the "None" tile source is selected.
///
/// The grid step is chosen as a "nice" ground distance (1-2-5 series in metres)
/// from the visible span, then converted to latitude/longitude degree steps at
/// the view centre so that each cell represents the *same ground distance*
/// horizontally and vertically. Because Web-Mercator is locally conformal
/// (isotropic scale), equal ground distance projects to equal screen pixels, so
/// the cells render square. A scale label (bottom-left) states the distance one
/// cell edge represents. Lines are projected through the live [MapCamera] via
/// `getOffsetFromOrigin`, so the grid pans, zooms and rotates with the map.
class _DashedGridLayer extends StatelessWidget {
  const _DashedGridLayer({required this.color, required this.labelColor});

  final Color color;
  final Color labelColor;

  /// Picks a "nice" ground distance (metres) from a 1-2-5 series such that the
  /// visible span is divided into a comfortable number of cells.
  static double _niceMeters(double spanMeters) {
    const targetCells = 6;
    final raw = spanMeters / targetCells;
    if (raw <= 0) return 0;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag; // 1..10
    final double stepNorm;
    if (norm < 1.5) {
      stepNorm = 1;
    } else if (norm < 3.5) {
      stepNorm = 2;
    } else if (norm < 7.5) {
      stepNorm = 5;
    } else {
      stepNorm = 10;
    }
    return stepNorm * mag;
  }

  /// Formats a metric [meters] distance for the scale label.
  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      final s = km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
      return '$s km';
    }
    if (meters >= 1) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters * 100).toStringAsFixed(0)} cm';
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;
    final centerLat = camera.center.latitude;

    // Ground metres spanned by the visible view (N-S), used to size the step.
    const metersPerDegLat = 111320.0;
    final latSpanM = (bounds.north - bounds.south).abs() * metersPerDegLat;
    final stepMeters = _niceMeters(latSpanM);

    // Degree steps that represent `stepMeters` of ground distance in each
    // direction at the view centre (equal ground distance => square on screen).
    final cosLat = math.cos(centerLat * math.pi / 180.0).abs();
    final latStepDeg = stepMeters / metersPerDegLat;
    final lonStepDeg =
        stepMeters / (metersPerDegLat * (cosLat < 1e-6 ? 1e-6 : cosLat));

    return Positioned.fill(
      child: Stack(
        children: [
          MobileLayerTransformer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _DashedGridPainter(
                camera: camera,
                color: color,
                latStepDeg: latStepDeg,
                lonStepDeg: lonStepDeg,
              ),
            ),
          ),
          // Scale label: rendered outside the transformer so it stays upright
          // and screen-fixed regardless of map rotation.
          Positioned(
            left: 8,
            bottom: 34,
            child: _GridScaleLabel(
              text: 'Grid ${_formatDistance(stepMeters)}',
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small upright chip stating the grid cell size (see [_DashedGridLayer]).
class _GridScaleLabel extends StatelessWidget {
  const _GridScaleLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(180),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_4x4, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _DashedGridPainter extends CustomPainter {
  _DashedGridPainter({
    required this.camera,
    required this.color,
    required this.latStepDeg,
    required this.lonStepDeg,
  });

  final MapCamera camera;
  final Color color;
  final double latStepDeg;
  final double lonStepDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = camera.visibleBounds;
    final south = bounds.south;
    final north = bounds.north;
    final west = bounds.west;
    final east = bounds.east;

    if (latStepDeg <= 0 || lonStepDeg <= 0) return;
    if ((north - south).abs() <= 0 || (east - west).abs() <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Latitude lines (constant lat, spanning west→east). Projecting both
    // endpoints and drawing a straight dashed segment keeps the grid correct
    // even when the map is rotated.
    final firstLat = (south / latStepDeg).ceil() * latStepDeg;
    for (double lat = firstLat; lat <= north; lat += latStepDeg) {
      final a = camera.getOffsetFromOrigin(LatLng(lat, west));
      final b = camera.getOffsetFromOrigin(LatLng(lat, east));
      _drawDashedLine(canvas, a, b, paint);
    }

    // Longitude lines (constant lon, spanning south→north).
    final firstLon = (west / lonStepDeg).ceil() * lonStepDeg;
    for (double lon = firstLon; lon <= east; lon += lonStepDeg) {
      final a = camera.getOffsetFromOrigin(LatLng(south, lon));
      final b = camera.getOffsetFromOrigin(LatLng(north, lon));
      _drawDashedLine(canvas, a, b, paint);
    }
  }

  /// Draws a dashed line from [a] to [b] using a fixed dash/gap pattern.
  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0;
    const gap = 5.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    double drawn = 0.0;
    while (drawn < total) {
      final start = a + dir * drawn;
      final end = a + dir * math.min(drawn + dash, total);
      canvas.drawLine(start, end, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedGridPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.latStepDeg != latStepDeg ||
      oldDelegate.lonStepDeg != lonStepDeg ||
      oldDelegate.camera.center != camera.center ||
      oldDelegate.camera.zoom != camera.zoom ||
      oldDelegate.camera.rotation != camera.rotation;
}

/// Absorbs horizontal drag gestures so panning the map does not bubble up to a
/// parent horizontally-scrolling `PageView` (which would flip dashboard pages
/// mid-pan). Implements feature 17 ("page-swipe lock").
///
/// It claims the horizontal-drag gesture arena with a no-op recognizer that
/// always wins, so flutter_map still receives the pointer for panning while the
/// enclosing PageView never does.
class _SuppressPageSwipe extends StatelessWidget {
  const _SuppressPageSwipe({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _AlwaysWinHorizontalDragRecognizer:
            GestureRecognizerFactoryWithHandlers<
                _AlwaysWinHorizontalDragRecognizer>(
          () => _AlwaysWinHorizontalDragRecognizer(),
          (instance) {},
        ),
      },
      child: child,
    );
  }
}

/// A horizontal-drag recognizer that eagerly accepts the gesture (so the
/// ancestor PageView loses the arena) but performs no action itself.
class _AlwaysWinHorizontalDragRecognizer
    extends HorizontalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'suppressPageSwipe';
}

/// A north-up map marker: a filled arrow rotated to the current [heading].
class _HeadingMarker extends StatelessWidget {
  final double heading;
  final Color color;

  const _HeadingMarker({required this.heading, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180.0,
      child: CustomPaint(
        size: const Size(40, 40),
        painter: _ArrowPainter(color: color),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;

  _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    // A chevron/arrow pointing "up" (north); rotation is applied by the parent.
    final path = Path()
      ..moveTo(cx, h * 0.12) // tip
      ..lineTo(w * 0.80, h * 0.85) // bottom-right
      ..lineTo(cx, h * 0.66) // notch
      ..lineTo(w * 0.20, h * 0.85) // bottom-left
      ..close();

    canvas.drawShadow(path, Colors.black54, 2.0, false);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}

/// A compact legend for the vario colour [scale].
///
/// Renders the gradient bar plus SINK / NEUTRAL / LIFT captions and the tick
/// labels -10 · sinkThreshold · 0 · liftThreshold · +10. The threshold values
/// are read live from the scale, so the legend updates whenever the user
/// changes them.
class _VarioLegend extends StatelessWidget {
  const _VarioLegend({
    required this.scale,
    required this.background,
    required this.textColor,
  });

  final VarioColorScale scale;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: textColor,
      fontSize: 9,
      height: 1.0,
    );
    final captionStyle = theme.textTheme.labelSmall?.copyWith(
      color: textColor,
      fontSize: 9,
      height: 1.0,
      fontWeight: FontWeight.w600,
    );

    String fmt(double v) {
      final s = v.toStringAsFixed(1);
      return v > 0 ? '+$s' : s;
    }

    // Fractions (0..1 over the visualisation range) at which the threshold
    // ticks sit, so the labels line up with the gradient bar.
    double frac(double mps) =>
        ((mps - scale.colorMin) / (scale.colorMax - scale.colorMin))
            .clamp(0.0, 1.0);

    const barWidth = 220.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SINK / NEUTRAL / LIFT captions.
          SizedBox(
            width: barWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SINK', style: captionStyle),
                Text('NEUTRAL', style: captionStyle),
                Text('LIFT', style: captionStyle),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // Gradient bar sampled from the scale.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              width: barWidth,
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: scale.sampleGradient(24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Tick labels: colorMin · sink · 0 · lift · colorMax, positioned to
          // align with their value on the bar. Endpoints and thresholds are all
          // derived from the scale (nothing hard-coded).
          SizedBox(
            width: barWidth,
            height: 11,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _tick(0.0, fmt(scale.colorMin), labelStyle, barWidth,
                    Alignment.centerLeft),
                _tick(frac(scale.effectiveSinkThreshold),
                    fmt(scale.effectiveSinkThreshold), labelStyle, barWidth,
                    Alignment.center),
                _tick(frac(0), '0', labelStyle, barWidth, Alignment.center),
                _tick(frac(scale.effectiveLiftThreshold),
                    fmt(scale.effectiveLiftThreshold), labelStyle, barWidth,
                    Alignment.center),
                _tick(1.0, fmt(scale.colorMax), labelStyle, barWidth,
                    Alignment.centerRight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Positions a tick [label] at horizontal [fraction] (0..1) of [barWidth].
  Widget _tick(
    double fraction,
    String label,
    TextStyle? style,
    double barWidth,
    Alignment align,
  ) {
    const halfLabel = 14.0;
    double left = fraction * barWidth - halfLabel;
    left = left.clamp(0.0, barWidth - 2 * halfLabel);
    return Positioned(
      left: left,
      top: 0,
      child: SizedBox(
        width: 2 * halfLabel,
        child: Text(label, style: style, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Small circular glass button used for map affordances (re-center, zoom).
class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface.withAlpha(210),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

/// A compass affordance that shows the current map [rotationDeg] and, when
/// tapped, snaps the map back to north-up. Same visual style as [_MapButton]
/// but rotates its icon so the "N" needle always points at true north.
class _CompassButton extends StatelessWidget {
  final double rotationDeg;
  final VoidCallback onTap;

  const _CompassButton({required this.rotationDeg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // flutter_map's camera rotation is measured counter-clockwise (positive
    // rotates the tiles CCW). To keep the needle pointing at true north on
    // screen we counter-rotate the icon by the same amount.
    final iconAngleRad = -rotationDeg * math.pi / 180.0;
    return Tooltip(
      message: 'Reset north',
      child: Material(
        color: theme.colorScheme.surface.withAlpha(210),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Transform.rotate(
              angle: iconAngleRad,
              child: Icon(
                Icons.explore,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small, non-interactive North indicator: an upward arrow labelled "N",
/// counter-rotated by the current map rotation so it always points at true
/// north. Useful when the map is track-up. Ported from XCTrack's "Display
/// North direction" option.
class _NorthIndicator extends StatelessWidget {
  final double rotationDeg;
  final Color color;
  final Color background;

  const _NorthIndicator({
    required this.rotationDeg,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    // Camera rotation is counter-clockwise; counter-rotate to keep N up.
    final angle = -rotationDeg * math.pi / 180.0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Transform.rotate(
        angle: angle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.navigation, size: 16, color: color),
            Text(
              'N',
              style: TextStyle(
                fontSize: 9,
                height: 1.0,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A screen-fixed ground-distance scale ruler drawn in the bottom-left, sized
/// to a "nice" 1-2-5 series distance for the current zoom. Ported from
/// XCTrack's "Display map scale" option.
class _ScaleBarLayer extends StatelessWidget {
  const _ScaleBarLayer({required this.color, required this.background});

  final Color color;
  final Color background;

  /// Picks a "nice" distance (metres) from a 1-2-5 series near [target].
  static double _niceMeters(double target) {
    if (target <= 0) return 0;
    final mag = math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
    final norm = target / mag; // 1..10
    final double stepNorm;
    if (norm < 1.5) {
      stepNorm = 1;
    } else if (norm < 3.5) {
      stepNorm = 2;
    } else if (norm < 7.5) {
      stepNorm = 5;
    } else {
      stepNorm = 10;
    }
    return stepNorm * mag;
  }

  static String _fmt(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      return '${km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final center = camera.center;

    // Metres per screen pixel at the view centre (Web-Mercator ground
    // resolution): 156543.03 * cos(lat) / 2^zoom.
    final metersPerPixel = 156543.03392 *
        math.cos(center.latitude * math.pi / 180.0).abs() /
        math.pow(2, camera.zoom);
    if (!metersPerPixel.isFinite || metersPerPixel <= 0) {
      return const SizedBox.shrink();
    }

    // Aim for a bar around 80px wide, then snap the represented distance to a
    // nice value and back-compute the exact pixel width.
    const targetPx = 80.0;
    final niceMeters = _niceMeters(targetPx * metersPerPixel);
    if (niceMeters <= 0) return const SizedBox.shrink();
    final barPx = (niceMeters / metersPerPixel).clamp(20.0, 200.0);

    return Positioned(
      left: 8,
      bottom: 34,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fmt(niceMeters),
              style: TextStyle(
                fontSize: 9,
                height: 1.0,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            // The ruler itself: a horizontal bar with end ticks.
            CustomPaint(
              size: Size(barPx.toDouble(), 6),
              painter: _ScaleBarPainter(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleBarPainter extends CustomPainter {
  _ScaleBarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final y = size.height - 1;
    // Baseline with end ticks pointing up.
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, y), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_ScaleBarPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A compact wind indicator: an arrow showing the direction the wind blows
/// *towards* plus the speed (km/h) it comes *from*. In track-up mode the arrow
/// is counter-rotated by the map rotation so it keeps pointing at the true
/// wind direction on screen. Low-confidence (estimated) winds render dimmed.
class _WindIndicator extends StatelessWidget {
  const _WindIndicator({
    required this.wind,
    required this.mapRotationDeg,
    required this.color,
    required this.background,
  });

  final WindEstimate wind;
  final double mapRotationDeg;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    // The arrow should point the way the wind blows *to* (from + 180°). Then
    // counter-rotate by the map rotation (CCW) so it stays true on a rotated
    // (track-up) map.
    final blowToDeg = (wind.fromDirectionDeg + 180.0) % 360.0;
    final angleRad =
        (blowToDeg - mapRotationDeg) * math.pi / 180.0;
    final dim = wind.confident ? 1.0 : 0.55;
    return Opacity(
      opacity: dim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: angleRad,
              child: Icon(Icons.navigation, size: 14, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              '${wind.speedKmh.round()} km/h',
              style: TextStyle(
                fontSize: 10,
                height: 1.0,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sun glyph whose ray colour warms as the sun gets lower (a low sun paints
/// the sky orange), used to mark the sun's azimuth on the map.
class _SunMarker extends StatelessWidget {
  const _SunMarker({required this.elevationDeg});

  final double elevationDeg;

  @override
  Widget build(BuildContext context) {
    // Higher sun = brighter yellow; low sun = warmer orange.
    final warm = (1.0 - (elevationDeg / 45.0)).clamp(0.0, 1.0);
    final color = Color.lerp(
      const Color(0xFFFFD54F), // high, bright yellow
      const Color(0xFFFF7043), // low, orange
      warm,
    )!;
    return Icon(
      Icons.wb_sunny,
      size: 26,
      color: color,
      shadows: const [
        Shadow(color: Colors.black45, blurRadius: 3),
      ],
    );
  }
}
