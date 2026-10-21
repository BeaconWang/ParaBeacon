import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_settings.dart';
import 'package:parabeacon/audio/announcement_template.dart';
import 'package:parabeacon/controls/altitude_announcement_settings_sheet.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sheet shows every feature with a preview', (tester) async {
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

    expect(find.text('起飞/降落播报'), findsOneWidget);
    expect(find.text('死区播报'), findsOneWidget);
    expect(find.text('新的最高高度播报'), findsOneWidget);
    expect(find.textContaining('继续飞行'), findsWidgets);
    // One preview per announcement: takeoff, continue flight, landing, dead
    // zone, altitude record. (Default texts follow LocaleController, which is
    // not set here, so only the custom text below is asserted.)
    expect(find.textContaining('预览：'), findsNWidgets(5));
    expect(find.text('爬升播报'), findsNothing);

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
    expect(tester.takeException(), isNull);
  });
}
