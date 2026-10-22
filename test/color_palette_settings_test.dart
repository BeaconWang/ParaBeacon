import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/color_palette_settings_sheet.dart';
import 'package:parabeacon/data/color_palette_settings.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('preset count is bounded and persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = ColorPaletteSettings.instance;
    await settings.load();

    await settings.setColorCount(ColorPaletteSettings.maxColorCount + 5);
    expect(settings.colorCount, ColorPaletteSettings.maxColorCount);
    expect(
      settings.pickerColors,
      hasLength(ColorPaletteSettings.maxColorCount + 1),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt('pb.colorPalette.count.v1'),
      ColorPaletteSettings.maxColorCount,
    );

    await settings.setColorCount(ColorPaletteSettings.minColorCount);
    expect(
      settings.pickerColors,
      hasLength(ColorPaletteSettings.minColorCount + 1),
    );
  });

  testWidgets('Preferences slider changes and saves the shared color count', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = ColorPaletteSettings.instance;
    await settings.setColorCount(ColorPaletteSettings.defaultColorCount);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showColorPaletteSettingsSheet(context),
                child: const Text('Open palette preferences'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open palette preferences'));
    await tester.pumpAndSettle();
    final sliderRect = tester.getRect(find.byType(Slider));
    await tester.tapAt(
      Offset(sliderRect.left + sliderRect.width * 0.2, sliderRect.center.dy),
    );
    await tester.pumpAndSettle();

    expect(settings.colorCount, isNot(ColorPaletteSettings.defaultColorCount));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('pb.colorPalette.count.v1'), settings.colorCount);
  });
}
