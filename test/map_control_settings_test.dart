import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/control_catalog.dart';
import 'package:parabeacon/controls/control_settings_sheet.dart';
import 'package:parabeacon/data/color_palette_settings.dart';
import 'package:parabeacon/controls/placed_control.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  test('13 HSL schemes meet color limits and evenly space hues', () {
    expect(ColorPaletteSettings.presets, hasLength(13));
    expect(ColorPaletteSettings.defaultSchemeId, 'high-saturation');
    final highSaturation = ColorPaletteSettings.presets.firstWhere(
      (preset) => preset.id == 'high-saturation',
    );
    expect(highSaturation.saturation, 0.75);
    for (final preset in ColorPaletteSettings.presets) {
      expect(preset.saturation, inInclusiveRange(0.4, 0.75));
      expect(preset.lightness, inInclusiveRange(0.5, 0.75));
      final hues = preset
          .colorsForCount(3)
          .map((color) => HSLColor.fromColor(Color(color)).hue)
          .toList();
      expect(hues, hasLength(3));
      for (var i = 0; i < hues.length; i++) {
        final next = hues[(i + 1) % hues.length];
        final gap = (next - hues[i] + 360) % 360;
        expect((gap - 120).abs(), lessThan(1.5));
      }
    }
    final highSaturationColors = highSaturation.colorsForCount(16);
    expect(highSaturationColors, hasLength(16));
    expect(
      highSaturationColors.sublist(11, 14),
      ColorPalettePreset.neutralColors,
    );
    expect(
      HSLColor.fromColor(Color(highSaturationColors[14])).lightness,
      closeTo(0.50, 0.01),
    );
    expect(
      HSLColor.fromColor(Color(highSaturationColors[15])).lightness,
      closeTo(0.75, 0.01),
    );

    final settings = ColorPaletteSettings.instance;
    settings.previewColorCount(4);
    expect(settings.pickerColors, hasLength(5));
    expect(settings.pickerColors.first, 0);
    settings.previewColorCount(ColorPaletteSettings.defaultColorCount);
    expect(
      settings.pickerColors,
      hasLength(ColorPaletteSettings.defaultColorCount + 1),
    );
  });

  testWidgets('map point and line colors follow their display switches', (
    tester,
  ) async {
    final mapType = ControlCatalog.byId('map')!;
    final control = PlacedControl.fromType(mapType, instanceId: 'map-test');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showControlSettingsSheet(
                  context,
                  control: control,
                  onChanged: () {},
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    final list = find.byType(ListView).first;
    Future<void> reveal(String label) =>
        tester.dragUntilVisible(find.text(label), list, const Offset(0, -300));

    expect(find.text('Show landing points'), findsNothing);

    await reveal('Show take-off point');
    expect(find.text('Take-off marker color'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Show take-off point'));
    await tester.pumpAndSettle();
    expect(find.text('Take-off marker color'), findsNothing);

    await reveal('Show default landing point');
    expect(find.text('Default landing marker color'), findsOneWidget);
    await tester.tap(find.text('Show default landing point'));
    await tester.pumpAndSettle();
    expect(find.text('Default landing marker color'), findsNothing);

    await reveal('Show nearest landing point');
    expect(find.text('Nearest landing marker color'), findsOneWidget);
    await tester.tap(find.text('Show nearest landing point'));
    await tester.pumpAndSettle();
    expect(find.text('Nearest landing marker color'), findsNothing);

    await reveal('Show line to take-off');
    expect(find.text('Take-off line color'), findsNothing);
    await tester.tap(find.text('Show line to take-off'));
    await tester.pumpAndSettle();
    expect(find.text('Take-off line color'), findsOneWidget);

    await reveal('Show line to default landing point');
    expect(find.text('Default landing line color'), findsNothing);
    await tester.tap(find.text('Show line to default landing point'));
    await tester.pumpAndSettle();
    expect(find.text('Default landing line color'), findsOneWidget);

    await reveal('Show line to nearest landing point');
    expect(find.text('Nearest landing line color'), findsNothing);
    await tester.tap(find.text('Show line to nearest landing point'));
    await tester.pumpAndSettle();
    expect(find.text('Nearest landing line color'), findsOneWidget);
  });

  test('old combined landing visibility migrates to both point switches', () {
    final mapType = ControlCatalog.byId('map')!;
    final control = PlacedControl.fromJson({
      'typeId': 'map',
      'instanceId': 'legacy-map',
      'settings': {'showLandingPoints': false},
    })!;

    expect(control.boolSetting('showDefaultLandingPoint'), isFalse);
    expect(control.boolSetting('showNearestLandingPoint'), isFalse);
    expect(mapType.id, control.type.id);
  });
}
