import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/share_card_settings.dart';
import 'package:parabeacon/theme/app_languages.dart';
import 'package:parabeacon/theme/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'map source defaults follow language until the user selects one',
    () async {
      SharedPreferences.setMockInitialValues({
        'pb.language': 'zh_CN',
        'pb.shareCardMapSource': 'amap-sat',
      });
      final settings = ShareCardSettings.instance;
      final locale = LocaleController.instance;

      await settings.load();

      expect(settings.mapSourceId, 'amap-sat');
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('pb.shareCardMapSource'), isFalse);

      await locale.setLanguage(AppLanguage.english);
      expect(settings.mapSourceId, 'none');
      await locale.setLanguage(AppLanguage.chineseSimplified);
      expect(settings.mapSourceId, 'amap-sat');

      await settings.setMapSourceId('osm');
      await locale.setLanguage(AppLanguage.english);
      expect(settings.mapSourceId, 'osm');
    },
  );
}
