import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_settings.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/audio/ble_sensor_announcement_bridge.dart';
import 'package:parabeacon/theme/app_languages.dart';
import 'package:parabeacon/theme/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitForSpeechCount(List<MethodCall> calls, int count) async {
  for (var i = 0; i < 300; i++) {
    if (calls.where((call) => call.method == 'speak').length >= count) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    messenger.setMockMethodCallHandler(ttsChannel, (call) async {
      calls.add(call);
      if (call.method == 'isLanguageAvailable') return true;
      return 1;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(ttsChannel, null);
  });

  test('speaks customized content for connect and disconnect events', () async {
    final settings = AltitudeAnnouncementSettings.instance;
    await settings.load();
    settings.setAnnouncementsEnabled(true);
    settings.setBleSensorAnnouncementsEnabled(true);
    settings.setBleSensorAnnouncementText(
      BleSensorAnnouncementEvent.connected,
      AnnouncementLanguage.english,
      'Ready for flight',
    );
    settings.setBleSensorAnnouncementText(
      BleSensorAnnouncementEvent.disconnected,
      AnnouncementLanguage.chinese,
      '传感器连接已结束',
    );

    final locale = LocaleController.instance;
    await locale.setLanguage(AppLanguage.english);
    final connected = ValueNotifier(false);
    final speaker = AltitudeAnnouncementSpeaker();
    final bridge = BleSensorAnnouncementBridge(
      connectionChanges: connected,
      isConnected: () => connected.value,
      speaker: speaker,
      settings: settings,
    )..attach();
    addTearDown(() {
      bridge.dispose();
      connected.dispose();
      speaker.dispose();
    });
    addTearDown(() => locale.setLanguage(AppLanguage.system));

    connected.value = true;
    await _waitForSpeechCount(calls, 1);
    final spoken = calls.where((call) => call.method == 'speak').toList();
    expect(spoken, hasLength(1));
    expect(spoken.single.arguments.toString(), contains('Ready for flight'));

    await locale.setLanguage(AppLanguage.chineseSimplified);
    connected.value = false;
    await _waitForSpeechCount(calls, 2);
    final allSpoken = calls.where((call) => call.method == 'speak').toList();
    expect(allSpoken, hasLength(2));
    expect(allSpoken.last.arguments.toString(), contains('传感器连接已结束'));
  });
}
