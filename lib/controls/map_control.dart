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
import '../data/thermal_detector.dart';
import '../data/vario_color_scale.dart';

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
  });

  final String id;
  final String label;
  final String urlTemplate;
  final String attribution;

  /// Chinese providers (AMap) publish GCJ-02 tiles; the WGS-84 aircraft
  /// position must be shifted to GCJ-02 to align with the streets.
  final bool requiresGcjShift;

  final double maxZoom;
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
    return all.firstWhere((s) => s.id == id, orElse: () => all.first);
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

  /// Self-contained thermal detector fed from the flight-data / GPS feed.
  final ThermalDetector _thermalDetector = ThermalDetector();
  ThermalHint? _thermal;

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
      _tileResetCtrl.add(null);
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

  /// Re-centers the map on [pos] when following (and ready).
  void _maybeFollow(LatLng pos) {
    _lastWgs = pos;
    if (!_follow || !_ready) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ready || !_follow) return;
      _map.move(_shift(pos, widget.tileSource), _map.camera.zoom);
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
    if (data.hasFix) {
      wgs = LatLng(data.latitude, data.longitude);
    }
    final hasFix = wgs != null;

    if (hasFix) {
      _maybeFollow(wgs);
      // Feed the thermal detector + airspace proximity from the live fix.
      _thermal = _thermalDetector.add(
        lat: wgs.latitude,
        lon: wgs.longitude,
        climbMps: climb,
      );
      AirspaceStore.instance
          .updatePosition(wgs.latitude, wgs.longitude, altMsl);
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

                // Airspace polygons (below track/markers so labels stay legible).
                if (widget.showAirspace)
                  PolygonLayer(polygons: _buildAirspacePolygons()),

                // Recorded flight track coloured by vertical speed.
                if (widget.showTrack)
                  PolylineLayer(polylines: _buildTrackPolylines()),

                // Thermal / climb-assistant ring.
                if (widget.showThermal && _thermal != null)
                  CircleLayer(circles: [_buildThermalCircle(_thermal!)]),

                if (hasFix)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: renderPos,
                        width: 40,
                        height: 40,
                        child: _HeadingMarker(
                          heading: heading,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
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
          key: ValueKey('offline-${OfflineTilesService.instance.activeFileName}'),
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
      key: ValueKey(src.id),
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
    final samples = track?.samples ?? const [];
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

    final out = <Polyline>[];
    int runStart = 0;
    // A segment's colour is derived from the vario at its *end* point via the
    // threshold-aware [VarioColorScale].
    Color runColor = _varioScale.colorFor(vario(1));

    void flush(int endExclusive) {
      if (endExclusive - runStart < 2) return;
      out.add(Polyline(
        points: [for (int i = runStart; i < endExclusive; i++) at(i)],
        strokeWidth: 3,
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

  /// Builds the thermal/climb-assistant ring at the detected core (feature 27).
  CircleMarker _buildThermalCircle(ThermalHint t) {
    final pos =
        _shift(LatLng(t.centerLat, t.centerLon), widget.tileSource);
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
