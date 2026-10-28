import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/control_settings.dart';
import 'package:parabeacon/data/decimal_places.dart';
import 'package:parabeacon/data/unit_settings.dart';

void main() {
  group('DecimalPlaceRange', () {
    test('parses bounded min/max ranges and rejects invalid values', () {
      expect(DecimalPlaceRange.parse('1-4'), const DecimalPlaceRange(1, 4));
      expect(DecimalPlaceRange.parse('auto'), isNull);
      expect(DecimalPlaceRange.parse('4-1'), isNull);
      expect(DecimalPlaceRange.parse('0-9'), isNull);
      expect(DecimalPlaceRange.parse('1;2'), isNull);
    });

    test('preserves automatic formatting and applies configured bounds', () {
      expect(formatDecimalValue(12.345, autoDecimals: 2), '12.35');
      expect(
        formatDecimalValue(
          12.345,
          autoDecimals: 2,
          range: const DecimalPlaceRange(1, 4),
        ),
        '12.345',
      );
      expect(
        formatDecimalValue(
          12.3,
          autoDecimals: 0,
          range: const DecimalPlaceRange(2, 4),
        ),
        '12.30',
      );
      expect(
        formatDecimalValue(
          12.0,
          autoDecimals: 1,
          range: const DecimalPlaceRange(0, 4),
        ),
        '12',
      );
    });
  });

  test('unit formatter preserves automatic altitude-difference output', () {
    expect(UnitValues.formatAltitudeDifference(-0.3, 'm'), '+0');
    expect(
      UnitValues.formatAltitudeDifference(
        12.345,
        'm',
        precision: const DecimalPlaceRange(1, 3),
      ),
      '+12.345',
    );
    expect(
      UnitValues.formatAltitudeDifference(
        12.345,
        'm',
        precision: const DecimalPlaceRange(1, 3),
        showPositiveSign: false,
      ),
      '12.345',
    );
  });

  test('decimal settings are independent for numeric fields', () {
    final locationKeys = settingsSchemaFor('location')
        .where((setting) => setting.kind == SettingKind.decimalRange)
        .map((setting) => setting.key)
        .toSet();
    expect(
      locationKeys,
      containsAll(['latitudeDecimals', 'longitudeDecimals']),
    );

    final waypointKeys = settingsSchemaFor('takeoff_waypoint')
        .where((setting) => setting.kind == SettingKind.decimalRange)
        .map((setting) => setting.key)
        .toSet();
    expect(
      waypointKeys,
      containsAll([
        'distanceDecimals',
        'altitudeDifferenceDecimals',
        'bearingDecimals',
      ]),
    );

    final monitorKeys = settingsSchemaFor('data_monitor')
        .where((setting) => setting.kind == SettingKind.decimalRange)
        .map((setting) => setting.key)
        .toSet();
    expect(
      monitorKeys,
      containsAll([
        'monitorVerticalSpeedDecimals',
        'monitorLatitudeDecimals',
        'monitorGlideRatioDecimals',
      ]),
    );

    final mapKeys = settingsSchemaFor('map')
        .where((setting) => setting.kind == SettingKind.decimalRange)
        .map((setting) => setting.key)
        .toSet();
    expect(
      mapKeys,
      containsAll([
        'mapHeadingDecimals',
        'mapRequiredGlideRatioDecimals',
        'mapGridDistanceDecimals',
        'mapScaleDistanceDecimals',
        'mapVarioSinkDecimals',
      ]),
    );

    expect(defaultSettingsFor('location')['latitudeDecimals'], 'default');
    expect(defaultSettingsFor('ground_speed')['valueDecimals'], 'default');
  });

  test('default precision switch applies one decimal or whole numbers', () {
    const defaults = [
      ('gps_accuracy', 'valueDecimals'),
      ('gps_altitude', 'valueDecimals'),
      ('baro_altitude', 'valueDecimals'),
      ('ground_speed', 'valueDecimals'),
      ('vertical_speed', 'valueDecimals'),
      ('wind_speed', 'valueDecimals'),
      ('data_monitor', 'monitorGpsAccuracyDecimals'),
    ];
    for (final (typeId, key) in defaults) {
      expect(defaultDecimalPlacesForControl(typeId, key, true), 1);
      expect(defaultDecimalPlacesForControl(typeId, key, false), 0);
    }
    expect(
      defaultDecimalPlacesForControl('location', 'latitudeDecimals', true),
      isNull,
    );
    expect(
      formatDecimalValue(
        12.345,
        autoDecimals: 5,
        range: DecimalPlaceRange(
          defaultDecimalPlacesForControl(
            'ground_speed',
            'valueDecimals',
            true,
          )!,
          defaultDecimalPlacesForControl(
            'ground_speed',
            'valueDecimals',
            true,
          )!,
        ),
      ),
      '12.3',
    );
    expect(
      formatDecimalValue(
        12.345,
        autoDecimals: 5,
        range: DecimalPlaceRange(
          defaultDecimalPlacesForControl(
            'ground_speed',
            'valueDecimals',
            false,
          )!,
          defaultDecimalPlacesForControl(
            'ground_speed',
            'valueDecimals',
            false,
          )!,
        ),
      ),
      '12',
    );
  });
}
