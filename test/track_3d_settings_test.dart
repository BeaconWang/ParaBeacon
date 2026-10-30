import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/track_3d_map.dart';
import 'package:parabeacon/data/track_3d_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('camera zoom selects clearer ground-map tile levels', () {
    expect(Track3DGroundMap.zoomOffsetFor(0.5), 0);
    expect(Track3DGroundMap.zoomOffsetFor(1), 0);
    expect(Track3DGroundMap.zoomOffsetFor(1.5), 1);
    expect(Track3DGroundMap.zoomOffsetFor(2), 1);
    expect(Track3DGroundMap.zoomOffsetFor(4), 2);
  });

  test(
    '3D replay map source defaults to None and persists selection',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = Track3DSettings.instance;

      await settings.load();

      expect(settings.mapSourceId, 'none');
      await settings.setMapSourceId('amap-sat');
      expect(settings.mapSourceId, 'amap-sat');

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('pb.track3d.mapSource'), 'amap-sat');

      await settings.setMapSourceId('google-satellite-mirror');
      expect(settings.mapSourceId, 'none');
      expect(preferences.getString('pb.track3d.mapSource'), 'none');
    },
  );
}
