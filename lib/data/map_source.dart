import 'package:flutter/foundation.dart';

/// Rendering backend required by a map source.
enum MapSourceType { rasterTiles, vectorStyle }

/// Coordinate reference system in which a provider publishes its map data.
enum MapCoordinateSystem { wgs84, gcj02 }

/// Immutable metadata for an online basemap provider.
///
/// [url] is an XYZ URL template for raster sources; [styleUrl] is a MapLibre
/// Style JSON URL for vector sources. This catalog intentionally contains
/// provider metadata only: it does not imply that a provider permits unlimited
/// usage, offline downloads, or use without attribution.
@immutable
class MapSource {
  const MapSource._({
    required this.id,
    required this.label,
    required this.type,
    required this.attribution,
    required this.coordinateSystem,
    required this.maxZoom,
    this.url,
    this.styleUrl,
    this.requiresInsecureHttp = false,
  }) : assert(
         (type == MapSourceType.rasterTiles &&
                 url != null &&
                 styleUrl == null) ||
             (type == MapSourceType.vectorStyle &&
                 styleUrl != null &&
                 url == null),
       );

  const MapSource.raster({
    required String id,
    required String label,
    required String url,
    required String attribution,
    MapCoordinateSystem coordinateSystem = MapCoordinateSystem.wgs84,
    double maxZoom = 19,
    bool requiresInsecureHttp = false,
  }) : this._(
         id: id,
         label: label,
         type: MapSourceType.rasterTiles,
         url: url,
         attribution: attribution,
         coordinateSystem: coordinateSystem,
         maxZoom: maxZoom,
         requiresInsecureHttp: requiresInsecureHttp,
       );

  const MapSource.vector({
    required String id,
    required String label,
    required String styleUrl,
    required String attribution,
    double maxZoom = 20,
  }) : this._(
         id: id,
         label: label,
         type: MapSourceType.vectorStyle,
         styleUrl: styleUrl,
         attribution: attribution,
         coordinateSystem: MapCoordinateSystem.wgs84,
         maxZoom: maxZoom,
       );

  final String id;
  final String label;
  final MapSourceType type;
  final String attribution;
  final MapCoordinateSystem coordinateSystem;
  final double maxZoom;
  final String? url;
  final String? styleUrl;

  /// True only for the supplied Google mirror URL, which is HTTP-only in the
  /// provided source list. Production renderers reject it rather than enabling
  /// platform-wide cleartext traffic or silently downgrading TLS.
  final bool requiresInsecureHttp;

  bool get requiresGcjShift => coordinateSystem == MapCoordinateSystem.gcj02;
}

/// Canonical catalog for provider definitions. Vector styles need a MapLibre
/// renderer; raster sources can be used with `flutter_map`.
class MapSourceCatalog {
  MapSourceCatalog._();

  static const List<MapSource> all = [
    MapSource.vector(
      id: 'openfreemap-liberty',
      label: 'OpenFreeMap Liberty',
      styleUrl: 'https://tiles.openfreemap.org/styles/liberty',
      attribution: '© OpenStreetMap contributors · OpenFreeMap',
    ),
    MapSource.vector(
      id: 'openfreemap-dark',
      label: 'OpenFreeMap Dark',
      styleUrl: 'https://tiles.openfreemap.org/styles/dark',
      attribution: '© OpenStreetMap contributors · OpenFreeMap',
    ),
    MapSource.vector(
      id: 'maptoolkit-outdoor',
      label: 'Maptoolkit Outdoor',
      styleUrl: 'https://styles.maptoolkit.org/summer.json',
      attribution: '© OpenStreetMap contributors · Maptoolkit',
    ),
    MapSource.raster(
      id: 'osm',
      label: 'OpenStreetMap Standard',
      url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors',
    ),
    MapSource.raster(
      id: 'opentopomap',
      label: 'OpenTopoMap Topographic',
      url: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors · SRTM · OpenTopoMap',
      maxZoom: 17,
    ),
    MapSource.raster(
      id: 'carto-dark',
      label: 'CartoDB Dark',
      url: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors · CARTO',
    ),
    MapSource.raster(
      id: 'esri-world-imagery',
      label: 'Esri World Imagery',
      url:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      attribution: 'Tiles © Esri and its contributors',
      maxZoom: 23,
    ),
    MapSource.raster(
      id: 'amap',
      label: 'AutoNavi Street (GCJ-02)',
      url:
          'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
      attribution: '© AutoNavi',
      coordinateSystem: MapCoordinateSystem.gcj02,
      maxZoom: 18,
    ),
    MapSource.raster(
      id: 'amap-sat',
      label: 'AutoNavi Satellite (GCJ-02)',
      url:
          'https://webst01.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}',
      attribution: '© AutoNavi',
      coordinateSystem: MapCoordinateSystem.gcj02,
      maxZoom: 18,
    ),
    MapSource.raster(
      id: 'google-satellite-mirror',
      label: 'Google Satellite Mirror (WGS-84, HTTP)',
      url: 'http://gac-geo.googlecnapps.cn/maps/vt?lyrs=s&x={x}&y={y}&z={z}',
      attribution: 'Google satellite imagery mirror; verify source terms',
      requiresInsecureHttp: true,
      maxZoom: 20,
    ),
    // Existing application sources retained to keep saved map settings valid.
    MapSource.raster(
      id: 'osmfr',
      label: 'OSM France (CN-friendly)',
      url: 'https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors · OpenStreetMap France',
    ),
    MapSource.raster(
      id: 'carto-voyager',
      label: 'Carto Voyager',
      url: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors · CARTO',
    ),
  ];

  static List<MapSource> get rasterSources => List.unmodifiable(
    all.where((source) => source.type == MapSourceType.rasterTiles),
  );

  static List<MapSource> get secureRasterSources => List.unmodifiable(
    rasterSources.where((source) => !source.requiresInsecureHttp),
  );

  static List<MapSource> get vectorStyles => List.unmodifiable(
    all.where((source) => source.type == MapSourceType.vectorStyle),
  );

  static MapSource byId(String id) {
    for (final source in all) {
      if (source.id == id) return source;
    }
    throw ArgumentError.value(id, 'id', 'Unknown map source');
  }
}

/// Runtime selection state shared by a source selector and a map renderer.
/// Persist [selectedId] with the app's existing settings store if selection
/// should survive an app restart.
class MapSourceManager extends ChangeNotifier {
  MapSourceManager({String initialSourceId = 'osm'})
    : _selectedId = MapSourceCatalog.byId(initialSourceId).id;

  String _selectedId;

  String get selectedId => _selectedId;
  MapSource get selectedSource => MapSourceCatalog.byId(_selectedId);

  void select(String sourceId) {
    final next = MapSourceCatalog.byId(sourceId);
    if (_selectedId == next.id) return;
    _selectedId = next.id;
    notifyListeners();
  }
}
