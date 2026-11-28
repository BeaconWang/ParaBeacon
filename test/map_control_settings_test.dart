import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/control_catalog.dart';
import 'package:parabeacon/controls/control_settings.dart';
import 'package:parabeacon/controls/control_settings_sheet.dart';
import 'package:parabeacon/controls/map_control.dart';
import 'package:parabeacon/data/color_palette_settings.dart';
import 'package:parabeacon/controls/placed_control.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  test('formats pilot altitude and speed independently', () {
    expect(
      formatPilotFlightInfo(
        altitudeMeters: 1250,
        groundSpeedMetersPerSecond: 11.7,
        showAltitude: true,
        showSpeed: true,
      ),
      '1250 m · 42 km/h',
    );
    expect(
      formatPilotFlightInfo(
        altitudeMeters: 1250,
        groundSpeedMetersPerSecond: 11.7,
        showAltitude: false,
        showSpeed: true,
      ),
      '42 km/h',
    );
    expect(
      formatPilotFlightInfo(
        altitudeMeters: 1250,
        groundSpeedMetersPerSecond: 11.7,
        showAltitude: true,
        showSpeed: false,
      ),
      '1250 m',
    );
    expect(
      formatPilotFlightInfo(
        altitudeMeters: 1250,
        groundSpeedMetersPerSecond: 11.7,
        showAltitude: false,
        showSpeed: false,
      ),
      isEmpty,
    );
  });

  test('competition task setting follows the selected app language', () async {
    final setting = settingsSchemaFor(
      'map',
    ).singleWhere((setting) => setting.key == 'showTask');
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final chinese = await AppLocalizations.delegate.load(const Locale('zh'));

    expect(setting.labelOf(english), 'Show competition task');
    expect(setting.labelOf(chinese), '显示竞赛航线');
  });

  test('map zoom is no longer a configurable setting', () {
    expect(
      settingsSchemaFor('map').any((setting) => setting.key == 'zoom'),
      isFalse,
    );

    final map = PlacedControl.fromType(
      ControlCatalog.byId('map')!,
      instanceId: 'map-zoom-test',
    );
    expect(map.settings.containsKey('zoom'), isFalse);

    final restored = PlacedControl.fromJson({
      'typeId': 'map',
      'settings': {'zoom': 11.0},
    })!;
    expect(restored.settings.containsKey('zoom'), isFalse);
  });

  test('XContest pilots respect channel and pinned-task filters', () {
    expect(
      shouldShowXContestPilots(
        showOtherPilots: true,
        channelNumber: 0,
        pinnedTaskOwnerId: null,
      ),
      isTrue,
    );
    expect(
      shouldShowXContestPilots(
        showOtherPilots: true,
        channelNumber: 483920,
        pinnedTaskOwnerId: null,
      ),
      isFalse,
    );
    expect(
      shouldShowXContestPilots(
        showOtherPilots: true,
        channelNumber: -1,
        pinnedTaskOwnerId: null,
      ),
      isFalse,
      reason: 'hide pilots until a signed-in account channel is loaded',
    );
    expect(
      shouldShowXContestPilots(
        showOtherPilots: true,
        channelNumber: 0,
        pinnedTaskOwnerId: '11111111-1111-4111-8111-111111111111',
      ),
      isFalse,
    );
    expect(
      shouldShowXContestPilots(
        showOtherPilots: false,
        channelNumber: 0,
        pinnedTaskOwnerId: null,
      ),
      isFalse,
    );
  });

  test(
    'offline pilots are hidden by default and the option is localized',
    () async {
      final setting = settingsSchemaFor(
        'map',
      ).singleWhere((setting) => setting.key == 'showOfflinePilots');
      final english = await AppLocalizations.delegate.load(const Locale('en'));
      final chinese = await AppLocalizations.delegate.load(const Locale('zh'));
      final map = PlacedControl.fromType(
        ControlCatalog.byId('map')!,
        instanceId: 'map-offline-pilots-default',
      );
      final restoredMap = PlacedControl.fromJson({
        'typeId': 'map',
        'settings': <String, dynamic>{},
      })!;

      expect(setting.defaultValue, isFalse);
      expect(setting.visibleWhenKey, 'showPublicPilots');
      expect(map.boolSetting('showOfflinePilots'), isFalse);
      expect(restoredMap.boolSetting('showOfflinePilots'), isFalse);
      expect(setting.labelOf(english), 'Show offline pilots');
      expect(setting.labelOf(chinese), '显示离线飞行员');

      map.settings['showOfflinePilots'] = true;
      final savedMap = PlacedControl.fromJson({
        'typeId': 'map',
        'settings': map.settings,
      })!;
      expect(savedMap.boolSetting('showOfflinePilots'), isTrue);
    },
  );

  test('pilot flight path opacity defaults to 50% and persists', () async {
    final setting = settingsSchemaFor(
      'map',
    ).singleWhere((setting) => setting.key == 'pilotTrailOpacity');
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final chinese = await AppLocalizations.delegate.load(const Locale('zh'));
    final map = PlacedControl.fromType(
      ControlCatalog.byId('map')!,
      instanceId: 'map-pilot-trail-opacity',
    );
    final restoredMap = PlacedControl.fromJson({
      'typeId': 'map',
      'settings': <String, dynamic>{},
    })!;

    expect(setting.defaultValue, 50.0);
    expect(setting.min, 0.0);
    expect(setting.max, 100.0);
    expect(setting.unit, '%');
    expect(setting.visibleWhenKey, 'showPublicPilots');
    expect(setting.labelOf(english), 'Pilot flight path opacity');
    expect(setting.labelOf(chinese), '飞行员航迹透明度');
    expect(map.doubleSetting('pilotTrailOpacity'), 50.0);
    expect(restoredMap.doubleSetting('pilotTrailOpacity'), 50.0);

    map.settings['pilotTrailOpacity'] = 75.0;
    final savedMap = PlacedControl.fromJson({
      'typeId': 'map',
      'settings': map.settings,
    })!;
    expect(savedMap.doubleSetting('pilotTrailOpacity'), 75.0);
  });

  test('pilot trail opacity maps percent to alpha safely', () {
    expect(pilotTrailAlpha(0.5), 128);
    expect(pilotTrailAlpha(0), 0);
    expect(pilotTrailAlpha(1), 255);
    expect(pilotTrailAlpha(-1), 0);
    expect(pilotTrailAlpha(2), 255);
  });

  test('offline pilot visibility can be enabled independently', () {
    expect(
      shouldShowOfflinePilot(isOffline: false, showOfflinePilots: false),
      isTrue,
    );
    expect(
      shouldShowOfflinePilot(isOffline: true, showOfflinePilots: false),
      isFalse,
    );
    expect(
      shouldShowOfflinePilot(isOffline: true, showOfflinePilots: true),
      isTrue,
    );
  });

  test('public pilot locations are on by default and localized', () async {
    final setting = settingsSchemaFor(
      'map',
    ).singleWhere((setting) => setting.key == 'showPublicPilots');
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final chinese = await AppLocalizations.delegate.load(const Locale('zh'));
    final map = PlacedControl.fromType(
      ControlCatalog.byId('map')!,
      instanceId: 'map-public-pilots-default',
    );
    final restoredMap = PlacedControl.fromJson({
      'typeId': 'map',
      'settings': <String, dynamic>{},
    })!;

    expect(setting.defaultValue, isTrue);
    expect(map.boolSetting('showPublicPilots'), isTrue);
    expect(restoredMap.boolSetting('showPublicPilots'), isTrue);
    expect(map.settings.containsKey('competitionTaskSource'), isFalse);
    expect(restoredMap.settings.containsKey('competitionTaskSource'), isFalse);
    expect(map.boolSetting('filterOtherPilotsByTask'), isFalse);
    expect(restoredMap.boolSetting('filterOtherPilotsByTask'), isFalse);
    expect(setting.labelOf(english), 'Show public pilot locations');
    expect(setting.labelOf(chinese), '显示公开飞行员实时位置');
    for (final key in [
      'showPilotName',
      'showPilotAltitude',
      'showPilotSpeed',
    ]) {
      final labelSetting = settingsSchemaFor(
        'map',
      ).singleWhere((setting) => setting.key == key);
      expect(labelSetting.defaultValue, isTrue);
      expect(map.boolSetting(key), isTrue);
      expect(restoredMap.boolSetting(key), isTrue);
      expect(labelSetting.visibleWhenKey, 'showPublicPilots');
    }
    expect(
      settingsSchemaFor('map')
          .singleWhere((setting) => setting.key == 'showPilotName')
          .labelOf(english),
      'Show pilot name',
    );
    expect(
      settingsSchemaFor('map')
          .singleWhere((setting) => setting.key == 'showPilotAltitude')
          .labelOf(chinese),
      '显示飞行员高度',
    );
    map.settings['showPilotSpeed'] = false;
    final savedMap = PlacedControl.fromJson({
      'typeId': 'map',
      'settings': map.settings,
    })!;
    expect(savedMap.boolSetting('showPilotSpeed'), isFalse);
  });

  test('landing widgets have separately configurable arrow colors', () {
    final defaultLanding = PlacedControl.fromType(
      ControlCatalog.byId('default_landing_waypoint')!,
      instanceId: 'default-landing-color-test',
    );
    final nearestLanding = PlacedControl.fromType(
      ControlCatalog.byId('nearest_landing_waypoint')!,
      instanceId: 'nearest-landing-color-test',
    );

    expect(defaultLanding.intSetting('directionArrowColor'), 0xFFF44336);
    expect(nearestLanding.intSetting('directionArrowColor'), 0xFF9C27B0);
    for (final landing in [defaultLanding, nearestLanding]) {
      expect(landing.setting('bearingReference'), 'relative');
      expect(landing.setting('format'), 'cardinal');
      final format = settingsSchemaFor(
        landing.type.id,
      ).singleWhere((setting) => setting.key == 'format');
      expect(format.options.keys, containsAll(['bearing', 'cardinal', 'none']));
      expect(format.defaultValue, 'cardinal');
    }
    expect(
      settingsSchemaFor(
        'default_landing_waypoint',
      ).where((setting) => setting.key == 'directionArrowColor').single.kind,
      SettingKind.color,
    );
    expect(
      settingsSchemaFor(
        'nearest_landing_waypoint',
      ).where((setting) => setting.key == 'directionArrowColor').single.kind,
      SettingKind.color,
    );
  });

  test('legacy landing degree format migrates to cardinal', () {
    for (final typeId in [
      'default_landing_waypoint',
      'nearest_landing_waypoint',
    ]) {
      final control = PlacedControl.fromJson({
        'typeId': typeId,
        'settings': {'format': 'degrees', 'bearingReference': 'absolute'},
      })!;

      expect(control.setting('format'), 'cardinal');
      expect(control.setting('bearingReference'), 'absolute');
    }
  });

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
    Future<void> reveal(String label) async {
      final target = find.text(label);
      for (
        var attempt = 0;
        target.evaluate().isEmpty && attempt < 50;
        attempt++
      ) {
        await tester.drag(list, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(target, findsOneWidget, reason: 'Could not find setting: $label');
      await tester.ensureVisible(target);
      await tester.pump();
    }

    expect(find.text('Show landing points'), findsNothing);

    await reveal('Show public pilot locations');
    expect(
      find.text(
        'Shows available public pilot locations from ParaBeacon and XContest LiveTrack.',
      ),
      findsOneWidget,
    );

    await reveal('Show offline pilots');
    final offlinePilotsTile = find.ancestor(
      of: find.text('Show offline pilots'),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(offlinePilotsTile).value, isFalse);
    await tester.tap(find.text('Show offline pilots'));
    await tester.pumpAndSettle();
    expect(control.boolSetting('showOfflinePilots'), isTrue);

    for (final label in [
      'Show pilot name',
      'Show pilot altitude',
      'Show pilot speed',
    ]) {
      await reveal(label);
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(control.boolSetting('showPilotName'), isFalse);
    expect(control.boolSetting('showPilotAltitude'), isFalse);
    expect(control.boolSetting('showPilotSpeed'), isFalse);

    await reveal('Pilot flight path opacity');
    final pilotTrailOpacitySlider = find.byWidgetPredicate(
      (widget) => widget is Slider && widget.value == 50.0,
    );
    expect(pilotTrailOpacitySlider, findsOneWidget);
    tester.widget<Slider>(pilotTrailOpacitySlider).onChanged!(75.0);
    await tester.pump();
    expect(control.doubleSetting('pilotTrailOpacity'), 75.0);

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

    expect(find.text('Competition task'), findsNothing);
    await reveal('Filter pilots by current competition task');
    final taskFilterTile = find.ancestor(
      of: find.text('Filter pilots by current competition task'),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(taskFilterTile).value, isFalse);
    await tester.tap(find.text('Filter pilots by current competition task'));
    await tester.pump();
    expect(control.boolSetting('filterOtherPilotsByTask'), isTrue);
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

  test('legacy task filter migrates without a per-map task source', () {
    final selectedTask = PlacedControl.fromJson({
      'typeId': 'map',
      'settings': {
        'otherPilotTaskFilter': '11111111-1111-4111-8111-111111111111',
        'competitionTaskSource': '22222222-2222-4222-8222-222222222222',
      },
    })!;
    final allPilots = PlacedControl.fromJson({
      'typeId': 'map',
      'settings': {
        'otherPilotTaskFilter': 'all',
        'competitionTaskSource': 'local',
      },
    })!;

    expect(selectedTask.boolSetting('filterOtherPilotsByTask'), isTrue);
    expect(selectedTask.settings.containsKey('otherPilotTaskFilter'), isFalse);
    expect(selectedTask.settings.containsKey('competitionTaskSource'), isFalse);
    expect(allPilots.boolSetting('filterOtherPilotsByTask'), isFalse);
    expect(allPilots.settings.containsKey('competitionTaskSource'), isFalse);
  });

  test(
    'legacy LastLanding map setting keys migrate to NearestLanding keys',
    () {
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
    },
  );
}
