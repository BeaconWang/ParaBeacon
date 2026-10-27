import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_settings.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/audio/announcement_template.dart';
import 'package:parabeacon/controls/altitude_announcement_settings_sheet.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:parabeacon/theme/app_languages.dart';
import 'package:parabeacon/theme/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sheet shows every feature with a preview', (tester) async {
    await LocaleController.instance.setLanguage(AppLanguage.chineseSimplified);
    addTearDown(() async {
      await LocaleController.instance.setLanguage(AppLanguage.system);
    });
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAltitudeAnnouncementSettingsSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('事件'), findsOneWidget);
    expect(find.text('起飞/降落播报'), findsOneWidget);
    expect(find.text('开启或关闭所有自动语音播报。'), findsOneWidget);
    expect(find.text('蓝牙传感器连接播报'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(6));
    final bleAnnouncementSwitch = find.ancestor(
      of: find.text('蓝牙传感器连接播报'),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(bleAnnouncementSwitch).value, isTrue);
    await tester.tap(bleAnnouncementSwitch);
    await tester.pumpAndSettle();
    expect(
      AltitudeAnnouncementSettings.instance.bleSensorAnnouncementsEnabled,
      isFalse,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(
        'pb.altitudeAnnouncements.bleSensorAnnouncements.enabled',
      ),
      isFalse,
    );
    await tester.tap(bleAnnouncementSwitch);
    await tester.pumpAndSettle();
    expect(
      AltitudeAnnouncementSettings.instance.bleSensorAnnouncementsEnabled,
      isTrue,
    );

    final settings = AltitudeAnnouncementSettings.instance;
    await tester.tap(
      find.byKey(const ValueKey('bleSensorAnnouncementCustomize-connected')),
    );
    await tester.pumpAndSettle();
    const connectedChineseKey = ValueKey(
      'bleSensorAnnouncement-connected-chinese',
    );
    expect(
      find.byKey(const ValueKey('bleSensorAnnouncement-connected-english')),
      findsNothing,
    );
    await tester.enterText(find.byKey(connectedChineseKey), '传感器就绪');
    await tester.pumpAndSettle();
    expect(
      settings.bleSensorAnnouncementText(
        BleSensorAnnouncementEvent.connected,
        AnnouncementLanguage.chinese,
      ),
      '传感器就绪',
    );
    expect(
      preferences.getString(
        'pb.altitudeAnnouncements.bleSensorAnnouncements.template.connected.chinese',
      ),
      '传感器就绪',
    );

    await tester.tap(
      find.byKey(const ValueKey('bleSensorAnnouncementCustomize-disconnected')),
    );
    await tester.pumpAndSettle();
    const disconnectedChineseKey = ValueKey(
      'bleSensorAnnouncement-disconnected-chinese',
    );
    await tester.enterText(find.byKey(disconnectedChineseKey), '传感器已离线');
    await tester.pumpAndSettle();
    expect(
      settings.bleSensorAnnouncementText(
        BleSensorAnnouncementEvent.disconnected,
        AnnouncementLanguage.chinese,
      ),
      '传感器已离线',
    );

    await tester.tap(
      find.byKey(
        const ValueKey('bleSensorAnnouncementReset-connected-chinese'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      settings.bleSensorAnnouncementText(
        BleSensorAnnouncementEvent.connected,
        AnnouncementLanguage.chinese,
      ),
      '蓝牙传感器已连接',
    );
    expect(
      preferences.getString(
        'pb.altitudeAnnouncements.bleSensorAnnouncements.template.connected.chinese',
      ),
      isNull,
    );

    expect(find.text('死区播报'), findsOneWidget);
    expect(find.text('新的最高高度播报'), findsOneWidget);
    expect(find.textContaining('继续飞行'), findsWidgets);
    // BLE connect/disconnect previews plus takeoff, continue flight, landing,
    // dead zone and altitude record previews.
    expect(find.textContaining('预览：'), findsNWidgets(7));
    expect(find.text('爬升播报'), findsNothing);
    expect(find.text('播报音量：100%'), findsOneWidget);
    final volumeSlider = find.byKey(const ValueKey('announcementVolume'));
    expect(tester.widget<Slider>(volumeSlider).value, 1.0);
    await tester.ensureVisible(volumeSlider);
    await tester.tapAt(tester.getCenter(volumeSlider));
    await tester.pumpAndSettle();
    expect(AltitudeAnnouncementSettings.instance.volume, 0.5);
    expect(find.text('播报音量：50%'), findsOneWidget);
    expect(preferences.getDouble('pb.altitudeAnnouncements.volume'), 0.5);
    AltitudeAnnouncementSettings.instance.setVolume(1.0);
    await tester.pump();

    // Customizing a text updates its preview.
    AltitudeAnnouncementSettings.instance.setTemplateFor(
      AnnouncementEvent.altitudeRecord,
      '新纪录 {altitude}{altitudeUnit}',
    );
    await tester.pump();
    expect(find.text('预览：新纪录 1310米'), findsOneWidget);
    AltitudeAnnouncementSettings.instance.setTemplateFor(
      AnnouncementEvent.altitudeRecord,
      null,
    );

    await tester.tap(find.text('添加条件'));
    await tester.pumpAndSettle();
    expect(find.text('播报条件'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '高度： ');
    await tester.tap(find.byTooltip('{altitude}'));
    await tester.pump();
    final templateField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    expect(templateField.controller!.text, '高度： {altitude}');
    expect(find.text('预览：高度： 1250'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final rule = AltitudeAnnouncementSettings.instance.customRules.single;
    expect(rule.content, '高度： {altitude}');
    AltitudeAnnouncementSettings.instance.removeCustomRule(rule.id);
    expect(tester.takeException(), isNull);
  });
}
