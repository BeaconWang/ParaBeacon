import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_bridge.dart';
import 'package:parabeacon/audio/altitude_announcement_settings.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/audio/announcement_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const volumeKey = 'pb.altitudeAnnouncements.volume';
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('voice volume defaults to full and restores the saved value', () async {
    final settings = AltitudeAnnouncementSettings.instance;
    expect(AltitudeAnnouncementSettings.defaultVolume, 1.0);
    expect(settings.volume, 1.0);
    SharedPreferences.setMockInitialValues({volumeKey: 0.35});
    await settings.load();
    expect(settings.volume, 0.35);
  });

  test('volume changes are bounded, persisted and notify listeners', () async {
    final settings = AltitudeAnnouncementSettings.instance;
    settings.setVolume(0.4);
    var notifications = 0;
    void onChanged() => notifications++;
    settings.addListener(onChanged);
    addTearDown(() => settings.removeListener(onChanged));

    final preferences = await SharedPreferences.getInstance();
    await Future<void>.delayed(Duration.zero);
    expect(preferences.getDouble(volumeKey), 0.4);
    settings.setVolume(2.0);
    expect(settings.volume, 1.0);
    settings.setVolume(-1.0);
    expect(settings.volume, 0.0);
    settings.setVolume(0.4);
    settings.setVolume(0.4);
    settings.setVolume(double.nan);
    settings.setVolume(double.infinity);
    settings.setVolume(double.negativeInfinity);
    await Future<void>.delayed(Duration.zero);
    expect(settings.volume, 0.4);
    expect(preferences.getDouble(volumeKey), 0.4);
    expect(notifications, 3);
  });

  group('voice playback', () {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('flutter_tts');

    setUp(() {
      calls.clear();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'isLanguageAvailable') return true;
        return 1;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test(
      'applies volume before each utterance and after language changes',
      () async {
        final speaker = AltitudeAnnouncementSpeaker();
        addTearDown(speaker.dispose);
        await speaker.warmUp(AnnouncementLanguage.english);
        calls.clear();
        for (final volume in [1.0, 0.25, 0.0, 0.7]) {
          expect(
            await speaker.speak(
              preferred: volume == 0.7
                  ? AnnouncementLanguage.chinese
                  : AnnouncementLanguage.english,
              phraseFor: (_) => 'Test',
              volume: volume,
            ),
            isTrue,
          );
        }
        final playbackCalls = calls
            .where(
              (call) => call.method == 'setVolume' || call.method == 'speak',
            )
            .toList();
        expect(playbackCalls.map((call) => call.method), [
          'setVolume',
          'speak',
          'setVolume',
          'speak',
          'setVolume',
          'speak',
          'setVolume',
          'speak',
        ]);
        expect(
          playbackCalls
              .where((call) => call.method == 'setVolume')
              .map((call) => call.arguments),
          [1.0, 0.25, 0.0, 0.7],
        );
      },
    );

    test('speaker bounds invalid inputs and defaults to full volume', () async {
      final speaker = AltitudeAnnouncementSpeaker();
      addTearDown(speaker.dispose);
      for (final volume in [
        -1.0,
        2.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        await speaker.speak(
          preferred: AnnouncementLanguage.english,
          phraseFor: (_) => 'Test',
          volume: volume,
        );
      }
      await speaker.speak(
        preferred: AnnouncementLanguage.english,
        phraseFor: (_) => 'Default volume',
      );
      expect(
        calls
            .where((call) => call.method == 'setVolume')
            .map((call) => call.arguments),
        [0.0, 1.0, 1.0, 1.0, 1.0, 1.0],
      );
    });

    test('built-in announcements forward the selected voice volume', () async {
      final speaker = AltitudeAnnouncementSpeaker();
      addTearDown(speaker.dispose);
      final settings = AltitudeAnnouncementSettings.instance;
      settings.setVolume(0.3);
      addTearDown(() => settings.setVolume(1.0));
      for (final event in AnnouncementEvent.values) {
        expect(
          await speakAnnouncement(
            event,
            AnnouncementValues.sampleFor(event),
            speaker: speaker,
            settings: settings,
          ),
          isTrue,
        );
      }
      expect(
        calls
            .where((call) => call.method == 'setVolume')
            .map((call) => call.arguments),
        List.filled(AnnouncementEvent.values.length, 0.3),
      );
    });

    test('listening previews use the selected voice volume', () async {
      final settings = AltitudeAnnouncementSettings.instance;
      settings.setVolume(0.2);
      addTearDown(() => settings.setVolume(1.0));
      addTearDown(AltitudeAnnouncementSpeaker.instance.dispose);
      expect(await speakAnnouncementTest(AnnouncementEvent.glide), isTrue);
      expect(
        calls
            .where((call) => call.method == 'setVolume')
            .map((call) => call.arguments),
        [0.2],
      );
    });
  });
}
