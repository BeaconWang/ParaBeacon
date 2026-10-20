import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_settings.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/audio/vario_audio_service.dart';
import 'package:parabeacon/audio/vario_ducking.dart';

void main() {
  testWidgets('vario is lowered while speaking and restored after', (
    tester,
  ) async {
    final settings = AltitudeAnnouncementSettings.instance;
    final speaker = AltitudeAnnouncementSpeaker();
    final vario = VarioAudioService();
    final controller = VarioDuckingController(
      speaker: speaker,
      settings: settings,
      vario: vario,
    )..attach();
    addTearDown(controller.dispose);

    settings.setDuckVario(true);
    settings.setVarioDuckLevel(0.2);
    expect(vario.duckLevel, 1.0);

    speaker.speaking.value = true;
    expect(vario.duckLevel, closeTo(0.2, 1e-9));

    // Changing the level while speaking applies immediately.
    settings.setVarioDuckLevel(0.5);
    expect(vario.duckLevel, closeTo(0.5, 1e-9));

    speaker.speaking.value = false;
    expect(vario.duckLevel, closeTo(0.5, 1e-9));
    await tester.pump(const Duration(milliseconds: 500));
    expect(vario.duckLevel, 1.0);

    // Disabled: speech leaves the vario untouched.
    settings.setDuckVario(false);
    speaker.speaking.value = true;
    expect(vario.duckLevel, 1.0);
    speaker.speaking.value = false;
  });
}
