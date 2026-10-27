import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parabeacon/controls/map_control.dart' show MapTileSources;
import 'package:parabeacon/data/baidu09.dart';

void main() {
  group('Baidu tile sources', () {
    test('registers secure road and satellite tile endpoints', () {
      final road = MapTileSources.byId('baidu');
      final satellite = MapTileSources.byId('baidu-sat');

      expect(
        road.urlTemplate,
        startsWith('https://maponline0.bdimg.com/tile/'),
      );
      expect(road.urlTemplate, contains('styles=pl'));
      expect(
        satellite.urlTemplate,
        startsWith('https://maponline0.bdimg.com/starpic/'),
      );
      expect(satellite.urlTemplate, contains('type=sate'));
      expect(road.requiresBaiduShift, isTrue);
      expect(satellite.requiresBaiduShift, isTrue);
    });

    test('converts WGS-84 positions to BD-09 and back', () {
      const wgs = LatLng(39.915, 116.404);
      final provider = MapTileSources.toProviderCoordinate(
        wgs,
        MapTileSources.byId('baidu'),
      );
      final restored = MapTileSources.toWgsCoordinate(
        provider,
        MapTileSources.byId('baidu'),
      );

      expect(provider.latitude, isNot(wgs.latitude));
      expect(provider.longitude, isNot(wgs.longitude));
      expect(restored.latitude, closeTo(wgs.latitude, 0.00001));
      expect(restored.longitude, closeTo(wgs.longitude, 0.00001));
    });

    test('BD-09 conversion does not change WGS-84 outside mainland China', () {
      const wgs = LatLng(46.5197, 6.6323);
      final provider = Baidu09.wgsToBd(wgs.latitude, wgs.longitude);
      expect(provider[0], closeTo(wgs.latitude + 0.006, 0.0001));
      expect(provider[1], closeTo(wgs.longitude + 0.0065, 0.0001));
    });

    test('converts XYZ coordinates to Baidu centered tile indices', () {
      expect(Baidu09.tileFromXyz(x: 128, y: 127, z: 8), (0, 0));
      expect(Baidu09.tileFromXyz(x: 127, y: 127, z: 8), (-1, 0));
      expect(Baidu09.tileFromXyz(x: 128, y: 128, z: 8), (0, -1));
    });
  });
}
