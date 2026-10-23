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
    expect(settings.schemeId, 'high-saturation');
    expect(settings.includeNeutralColors, isFalse);

    await settings.setIncludeNeutralColors(false);
    expect(settings.includeNeutralColors, isFalse);
    expect(settings.visiblePresetColors, isNot(contains(0xFF808080)));

    await settings.setScheme('morandi');
    await settings.setColorCount(ColorPaletteSettings.maxColorCount + 5);
    expect(settings.schemeId, 'morandi');
    expect(settings.colorCount, ColorPaletteSettings.maxColorCount);
    expect(
      settings.pickerColors,
      hasLength(ColorPaletteSettings.maxColorCount + 1),
    );
    expect(settings.visiblePresetColors, isNot(contains(0xFF808080)));

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt('pb.colorPalette.count.v1'),
      ColorPaletteSettings.maxColorCount,
    );
    expect(prefs.getString('pb.colorPalette.scheme.v1'), 'morandi');
    expect(prefs.getBool('pb.colorPalette.neutralColors.v1'), isFalse);
    await settings.setIncludeNeutralColors(true);
    expect(prefs.getBool('pb.colorPalette.neutralColors.v1'), isTrue);
    expect(
      settings.visiblePresetColors.sublist(settings.colorCount - 3),
      ColorPalettePreset.neutralColors,
    );

    await settings.setColorCount(ColorPaletteSettings.minColorCount);
    expect(
      settings.pickerColors,
      hasLength(ColorPaletteSettings.minColorCount + 1),
    );
    await settings.setIncludeNeutralColors(true);
  });

  testWidgets('Preferences stores palette scheme and color count', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = ColorPaletteSettings.instance;
    await settings.setIncludeNeutralColors(true);
    await settings.setScheme('macaron');
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
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morandi').last);
    await tester.pumpAndSettle();
    expect(settings.schemeId, 'morandi');

    final sliderRect = tester.getRect(find.byType(Slider));
    await tester.tapAt(
      Offset(sliderRect.left + sliderRect.width * 0.8, sliderRect.center.dy),
    );
    await tester.pumpAndSettle();

    expect(settings.colorCount, isNot(ColorPaletteSettings.defaultColorCount));
    expect(settings.includeNeutralColors, isTrue);
    await tester.tap(find.text('Include black, white and gray'));
    await tester.pumpAndSettle();
    expect(settings.includeNeutralColors, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('pb.colorPalette.count.v1'), settings.colorCount);
  });
}
