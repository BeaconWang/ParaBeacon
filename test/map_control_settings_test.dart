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
    expect(highSaturation.saturation, 0.82);
    for (final preset in ColorPaletteSettings.presets) {
      expect(preset.saturation, inInclusiveRange(0.4, 0.82));
      expect(preset.lightness, inInclusiveRange(0.5, 0.75));
      final hues = preset
          .colorsForCount(3, includeNeutralColors: false)
          .map((color) => HSLColor.fromColor(Color(color)).hue)
          .toList();
      expect(hues, hasLength(3));
      for (var i = 0; i < hues.length; i++) {
        final next = hues[(i + 1) % hues.length];
        final gap = (next - hues[i] + 360) % 360;
        expect((gap - 120).abs(), lessThan(1.5));
      }
    }
    final highSaturationColors = highSaturation.colorsForCount(20);
    expect(highSaturationColors, hasLength(20));
    expect(ColorPaletteSettings.maxColorCount, 20);
    expect(highSaturationColors.sublist(17), ColorPalettePreset.neutralColors);
    final darkVariant = HSLColor.fromColor(Color(highSaturationColors[15]));
    final brightVariant = HSLColor.fromColor(Color(highSaturationColors[16]));
    expect(darkVariant.lightness, closeTo(0.28, 0.01));
    expect(darkVariant.saturation, greaterThanOrEqualTo(0.85));
    expect(brightVariant.lightness, closeTo(0.76, 0.01));
    expect(brightVariant.saturation, greaterThanOrEqualTo(0.85));
    final withoutNeutrals = highSaturation.colorsForCount(
      20,
      includeNeutralColors: false,
    );
    expect(withoutNeutrals, hasLength(20));
    expect(
      withoutNeutrals[17],
      isNot(anyOf(0xFF000000, 0xFFFFFFFF, 0xFF808080)),
    );
    final neutralFreeColors = highSaturation.colorsForCount(
      6,
      includeNeutralColors: false,
    );
    expect(neutralFreeColors, hasLength(6));
    expect(
      neutralFreeColors,
      isNot(
        anyOf(contains(0xFF000000), contains(0xFFFFFFFF), contains(0xFF808080)),
      ),
    );
    expect(highSaturation.colorsForCount(3), ColorPalettePreset.neutralColors);
    final presetHues =
        ColorPaletteSettings.presets
            .map(
              (preset) => HSLColor.fromColor(
                Color(
                  preset.colorsForCount(3, includeNeutralColors: false).first,
                ),
              ).hue,
            )
            .toSet()
            .toList()
          ..sort();
    for (var i = 0; i < presetHues.length; i++) {
      final next = presetHues[(i + 1) % presetHues.length];
      final gap = (next - presetHues[i] + 360) % 360;
      expect(gap, greaterThanOrEqualTo(26.5));
    }

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

  test('legacy LastLanding map setting keys migrate to NearestLanding keys', () {
    final control = PlacedControl.fromJson({
      'typeId': 'map',
      'settings': {
        'showLastLandingLine': true,
        'showNearestLandingLine': false,
        'lastLandingPointColor': 0xFF123456,
        'lastLandingLineColor': 0xFF654321,
      },
    })!;

    expect(control.boolSetting('showNearestLandingLine'), isFalse);
    expect(control.settings['nearestLandingPointColor'], 0xFF123456);
    expect(control.settings['nearestLandingLineColor'], 0xFF654321);
    expect(control.settings.containsKey('showLastLandingLine'), isFalse);
    expect(control.settings.containsKey('lastLandingPointColor'), isFalse);
    expect(control.settings.containsKey('lastLandingLineColor'), isFalse);
  });
}
