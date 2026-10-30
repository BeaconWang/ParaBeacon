import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/share_card_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'migrates the legacy toggle and persists the selected map source',
    () async {
      SharedPreferences.setMockInitialValues({
        'pb.shareCardAmapSatellite': false,
      });
      final settings = ShareCardSettings.instance;

      await settings.load();

      expect(settings.mapSourceId, 'none');
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('pb.shareCardMapSource'), 'none');
      expect(preferences.containsKey('pb.shareCardAmapSatellite'), isFalse);

      await settings.setMapSourceId('esri-world-imagery');
      expect(settings.mapSourceId, 'esri-world-imagery');
      expect(
        preferences.getString('pb.shareCardMapSource'),
        'esri-world-imagery',
      );

      await settings.setMapSourceId('google-satellite-mirror');
      expect(settings.mapSourceId, 'none');
      expect(preferences.getString('pb.shareCardMapSource'), 'none');
    },
  );
}
