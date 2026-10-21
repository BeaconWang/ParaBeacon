import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'does not speak when the flight-only gate closes during preparation',
    () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
        call,
      ) async {
        calls.add(call.method);
        return call.method == 'isLanguageAvailable' ? true : 1;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          null,
        );
      });

      final speaker = AltitudeAnnouncementSpeaker();
      addTearDown(speaker.dispose);
      var gateChecks = 0;

      final result = await speaker.speak(
        preferred: AnnouncementLanguage.english,
        phraseFor: (_) => 'Altitude 1200 meters',
        canSpeak: () => ++gateChecks == 1,
      );

      expect(result, isFalse);
      expect(gateChecks, 2);
      expect(calls, contains('isLanguageAvailable'));
      expect(calls, isNot(contains('speak')));
      expect(speaker.caption.value, isNull);
    },
  );
}
