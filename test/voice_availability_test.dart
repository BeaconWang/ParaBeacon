import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_bridge.dart';
import 'package:parabeacon/audio/altitude_announcement_settings.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestFlightDataView extends ChangeNotifier implements FlightDataView {
  @override
  FlightData get data => FlightData.empty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'disables and persists voice announcements when no voice is available',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
        call,
      ) async {
        if (call.method == 'isLanguageAvailable') return false;
        return 1;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          null,
        );
      });

      final settings = AltitudeAnnouncementSettings.instance;
      final speaker = AltitudeAnnouncementSpeaker();
      final bridge = AltitudeAnnouncementBridge(
        source: _TestFlightDataView(),
        speaker: speaker,
        settings: settings,
      );
      addTearDown(() {
        bridge.dispose();
        speaker.dispose();
      });

      bridge.attach();
      for (var i = 0; i < 100 && settings.announcementsEnabled; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(speaker.availability, SpeechAvailability.unavailable);
      expect(settings.announcementsEnabled, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool('pb.altitudeAnnouncements.voiceEnabled'),
        isFalse,
      );
    },
  );
}
