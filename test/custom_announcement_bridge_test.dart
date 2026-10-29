import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_bridge.dart';
import 'package:parabeacon/audio/altitude_announcement_settings.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/audio/custom_announcement_rule.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/flight_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestFlightDataView extends ChangeNotifier implements FlightDataView {
  @override
  final FlightData data = const FlightData(
    altitude: 1200,
    hasFix: true,
    groundSpeed: 36,
    hasGroundSpeed: true,
  );
}

Future<void> _waitForSpeech(Completer<void> speech) =>
    speech.future.timeout(const Duration(seconds: 2));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'speaks the configured content when a live-data condition matches',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final speeches = <Object?>[];
      final speechEvent = Completer<void>();
      final volumes = <Object?>[];
      messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
        call,
      ) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'setVolume') volumes.add(call.arguments);
        if (call.method == 'speak') {
          speeches.add(call.arguments);
          if (!speechEvent.isCompleted) speechEvent.complete();
        }
        return 1;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          null,
        );
      });

      final settings = AltitudeAnnouncementSettings.instance;
      await settings.load();
      settings.setVolume(0.35);
      addTearDown(() => settings.setVolume(1.0));
      settings.setAnnouncementsEnabled(true);
      settings.setTakeoffLandingEnabled(false);
      settings.setGlideEnabled(false);
      settings.setRecordEnabled(false);
      final ruleId = settings.nextCustomRuleId;
      settings.saveCustomRule(
        CustomAnnouncementRule(
          id: ruleId,
          metric: AnnouncementMetric.altitude,
          condition: AnnouncementCondition.greaterThan,
          threshold: 1000,
          upperThreshold: 1000,
          repeatSeconds: null,
          enabled: true,
          content: 'Configured threshold reached',
        ),
      );

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
      );
      flightState.start();
      bridge.attach();
      addTearDown(() {
        bridge.dispose();
        speaker.dispose();
        settings.removeCustomRule(ruleId);
        flightState.stop();
      });

      await _waitForSpeech(speechEvent);
      expect(speeches, hasLength(1));
      expect(speeches.single, contains('Configured threshold reached'));
      expect(volumes, [0.35]);
    },
  );
}
