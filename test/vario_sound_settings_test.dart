import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/vario_config.dart';
import 'package:parabeacon/audio/vario_sound_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final settings = VarioSoundSettings.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await settings.resetToDefaults();
  });

  test('XC Track profile applies the configured lift and sink thresholds', () {
    settings.setLiftThreshold(1.0);
    settings.setSinkThreshold(-3.0);

    expect(settings.profile, VarioSoundProfile.xcTrack);
    expect(settings.config.liftThreshold, 1.0);
    expect(settings.config.sinkThreshold, -3.0);
    expect(settings.config.liftBaseFreq, VarioAudioConfig.xcTrack.liftBaseFreq);
  });
}
