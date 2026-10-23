import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/display_settings_sheet.dart';
import 'package:parabeacon/data/display_settings.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'larger font is off by default and its preference is persisted',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = DisplaySettings.instance;
      await settings.load();

      expect(settings.largerFontEnabled, isFalse);
      await settings.setLargerFontEnabled(true);
      expect(settings.largerFontEnabled, isTrue);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('pb.display.larger_font'), isTrue);

      await settings.setLargerFontEnabled(false);
      expect(settings.largerFontEnabled, isFalse);
      expect(preferences.getBool('pb.display.larger_font'), isFalse);
    },
  );

  testWidgets('display settings exposes and updates the larger font switch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = DisplaySettings.instance;
    await settings.setLargerFontEnabled(false);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDisplaySettingsSheet(context),
                child: const Text('Open display settings'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open display settings'));
    await tester.pumpAndSettle();
    expect(find.text('Larger font'), findsOneWidget);
    expect(settings.largerFontEnabled, isFalse);

    await tester.tap(find.text('Larger font'));
    await tester.pumpAndSettle();
    expect(settings.largerFontEnabled, isTrue);
  });
}
