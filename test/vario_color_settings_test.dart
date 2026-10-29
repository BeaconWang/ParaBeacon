import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/control_settings.dart';
import 'package:parabeacon/data/vario_color_palette.dart';
import 'package:parabeacon/data/vario_color_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Vario key-point colors are global, applied, and persisted', () async {
    SharedPreferences.setMockInitialValues({
      'pb.varioColors.keyPoint.v1.varioColorMinus7': 0xFF112233,
    });
    final settings = VarioColorSettings.instance;
    await settings.load();

    expect(settings.colorAt(1), 0xFF112233);
    expect(varioColorFor(-7), const Color(0xFF112233));
    expect(settings.colors, hasLength(VarioColorSettings.colorKeys.length));

    await settings.setColor(3, 0xFFABCDEF);
    expect(settings.colorAt(3), 0xFFABCDEF);
    expect(varioColorFor(0), const Color(0xFFABCDEF));

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getInt('pb.varioColors.keyPoint.v1.varioColorZero'),
      0xFFABCDEF,
    );

    final schema = settingsSchemaFor('vario');
    expect(
      schema.where((setting) => setting.kind == SettingKind.globalColor),
      hasLength(VarioColorSettings.colorKeys.length),
    );
    final controlDefaults = defaultSettingsFor('vario');
    for (final key in VarioColorSettings.colorKeys) {
      expect(controlDefaults, isNot(contains(key)));
    }
  });
}
