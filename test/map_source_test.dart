import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/map_source.dart';

void main() {
  group('MapSourceCatalog', () {
    test('contains the requested vector styles', () {
      expect(
        MapSourceCatalog.vectorStyles.map((source) => source.styleUrl),
        containsAll([
          'https://tiles.openfreemap.org/styles/liberty',
          'https://tiles.openfreemap.org/styles/dark',
          'https://styles.maptoolkit.org/summer.json',
        ]),
      );
    });

    test('contains secure raster sources and tags GCJ-02 sources', () {
      final raster = MapSourceCatalog.secureRasterSources;
      expect(raster.map((source) => source.id), contains('opentopomap'));
      expect(raster.map((source) => source.id), contains('esri-world-imagery'));
      expect(
        raster.map((source) => source.id),
        isNot(contains('google-satellite-mirror')),
      );
      expect(MapSourceCatalog.byId('amap').requiresGcjShift, isTrue);
      expect(MapSourceCatalog.byId('amap-sat').requiresGcjShift, isTrue);
      expect(MapSourceCatalog.byId('osm').requiresGcjShift, isFalse);
    });

    test('rejects unknown source ids', () {
      expect(() => MapSourceCatalog.byId('missing'), throwsArgumentError);
    });
  });

  test('MapSourceManager notifies when the selection changes', () {
    final manager = MapSourceManager(initialSourceId: 'osm');
    var notifications = 0;
    manager.addListener(() => notifications++);

    manager.select('openfreemap-dark');
    expect(manager.selectedId, 'openfreemap-dark');
    expect(manager.selectedSource.type, MapSourceType.vectorStyle);
    expect(notifications, 1);

    manager.select('openfreemap-dark');
    expect(notifications, 1);
    manager.dispose();
  });
}
