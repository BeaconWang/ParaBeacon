import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/flight_data_provider.dart';
import '../data/gcj02.dart';

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
      urlTemplate: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      attribution: '© OSM · CARTO',
    ),
    MapTileSource(
      id: 'carto-voyager',
      label: 'Carto Voyager',
      urlTemplate:
          'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
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
/// Position comes from the device GPS (via `geolocator`, requesting the
/// location permission on Android/iOS) when available, otherwise it falls back
/// to the unified [FlightDataProvider] feed (simulator / BLE sensor).
class MapControl extends StatefulWidget {
  /// Initial zoom level (flutter_map zoom, ~1..19).
  final double initialZoom;

  /// Whether the map re-centers on the current position as it updates.
  final bool follow;

  /// Tile source id (see [MapTileSources]).
  final String tileSource;

  const MapControl({
    super.key,
    this.initialZoom = 13.0,
    this.follow = true,
    this.tileSource = 'osm',
  });

  @override
  State<MapControl> createState() => _MapControlState();
}

class _MapControlState extends State<MapControl> {
  final MapController _map = MapController();

  /// Whether the map is currently following the aircraft. Turned off when the
  /// user pans/zooms manually, restored by the re-center button.
  late bool _follow = widget.follow;

  /// Whether the map widget has been laid out and is ready for programmatic
  /// moves (calling [MapController.move] before the first frame throws).
  bool _ready = false;

  /// Latest device GPS position (WGS-84), or null when unavailable/denied.
  Position? _gps;
  StreamSubscription<Position>? _gpsSub;

  /// Last WGS-84 position pushed to the map (for re-center / follow).
  LatLng? _lastWgs;

  @override
  void initState() {
    super.initState();
    _initGps();
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
    _gpsSub?.cancel();
    super.dispose();
  }

  /// Requests the location permission and starts streaming device GPS.
  ///
  /// Best-effort: on unsupported platforms (or when the user denies), the map
  /// silently falls back to the flight-data position.
  Future<void> _initGps() async {
    // geolocator supports mobile + web + desktop, but GPS is really only
    // meaningful on mobile; guard so a desktop denial dialog never blocks.
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => _gps = pos);
      }, onError: (_) {});
    } catch (_) {
      // Location unavailable: keep falling back to the flight-data position.
    }
  }

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
  /// WGS-84 [wgs] position aligns with the tiles.
  LatLng _shift(LatLng wgs, String sourceId) {
    final src = MapTileSources.byId(sourceId);
    if (!src.requiresGcjShift) return wgs;
    final p = Gcj02.wgsToGcj(wgs.latitude, wgs.longitude);
    return LatLng(p[0], p[1]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = FlightDataProvider.of(context);
    final src = MapTileSources.byId(widget.tileSource);

    // Prefer real device GPS; fall back to the flight-data feed.
    LatLng? wgs;
    if (_gps != null) {
      wgs = LatLng(_gps!.latitude, _gps!.longitude);
    } else if (data.hasFix) {
      wgs = LatLng(data.latitude, data.longitude);
    }
    final hasFix = wgs != null;

    final heading = _gps?.heading ?? data.heading;

    if (hasFix) _maybeFollow(wgs);

    // Render position in the tile coordinate system (GCJ-shifted if needed).
    final renderPos = hasFix
        ? _shift(wgs, widget.tileSource)
        : _shift(const LatLng(46.5197, 6.6323), widget.tileSource);

    return Stack(
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
              },
              onMapReady: () {
                _ready = true;
                final p = _lastWgs;
                if (p != null) _maybeFollow(p);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: src.urlTemplate,
                userAgentPackageName: 'com.parabeacon.app',
                maxNativeZoom: src.maxZoom.round(),
                tileProvider: NetworkTileProvider(),
              ),
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

        if (!hasFix)
          Positioned(
            left: 8,
            top: 8,
            child: _glassChip(theme, icon: Icons.gps_off, label: 'No GPS fix'),
          ),

        if (!_follow)
          Positioned(
            right: 8,
            bottom: 8,
            child: _MapButton(
              icon: Icons.my_location,
              tooltip: 'Re-center',
              onTap: () {
                setState(() => _follow = true);
                final p = _lastWgs;
                if (p != null && _ready) {
                  _map.move(_shift(p, widget.tileSource), _map.camera.zoom);
                }
              },
            ),
          ),

        // Attribution (required by the tile providers' usage policies).
        Positioned(
          right: 4,
          top: 4,
          child: _glassChip(theme, label: src.attribution, small: true),
        ),
      ],
    );
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

/// Small circular glass button used for map affordances (re-center).
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
