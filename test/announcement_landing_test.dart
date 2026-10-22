import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_bridge.dart';
import 'package:parabeacon/audio/altitude_announcement_settings.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/audio/announcement_template.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestFlightDataView extends ChangeNotifier implements FlightDataView {
  @override
  final FlightData data = const FlightData(
    altitude: 1000,
    hasFix: true,
    groundSpeed: 36,
    hasGroundSpeed: true,
  );
}

Future<void> _waitForSpeechCount(List<Object?> speeches, int count) async {
  for (var i = 0; i < 200 && speeches.length < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('landing event speaks after flight state switches off', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final speeches = <Object?>[];
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      call,
    ) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') speeches.add(call.arguments);
      return 1;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        null,
      );
    });

    final settings = AltitudeAnnouncementSettings.instance;
    settings.setAnnouncementsEnabled(true);
    settings.setTakeoffLandingEnabled(true);
    settings.setGlideEnabled(false);
    settings.setRecordEnabled(false);
    settings.setTemplateFor(AnnouncementEvent.landing, 'Landing');

    final flightState = FlightState.instance;
    flightState.stop();
    final source = _TestFlightDataView();
    final recorder = FlightRecorder.instance;
    recorder.bind(source, flightState: flightState);
    final speaker = AltitudeAnnouncementSpeaker();
    final bridge = AltitudeAnnouncementBridge(
      source: source,
      speaker: speaker,
      settings: settings,
      flightState: flightState,
      recorder: recorder,
      chime: () async {},
    )..attach();
    addTearDown(bridge.dispose);
    addTearDown(speaker.dispose);

    flightState.start();
    await _waitForSpeechCount(speeches, 1);
    expect(speeches, hasLength(1));

    flightState.stop();
    await _waitForSpeechCount(speeches, 2);
    expect(speeches, hasLength(2));
    expect(speeches.last.toString(), contains('Landing'));
  });
}
