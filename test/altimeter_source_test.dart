import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/sensors/internal_sensor_service.dart';

void main() {
  group('InternalSensorService.altitudeFromPressurePa', () {
    final sensor = InternalSensorService.instance;

    test('returns ~0 m at the standard sea-level pressure', () {
      final altitude = sensor.altitudeFromPressurePa(
        InternalSensorService.standardSeaLevelPa,
      );
      expect(altitude, isNotNull);
      expect(altitude!.abs(), lessThan(1.0));
    });

    test('lower pressure yields higher altitude (monotonic)', () {
      final low = sensor.altitudeFromPressurePa(90000)!;
      final high = sensor.altitudeFromPressurePa(100000)!;
      expect(low, greaterThan(high));
    });

    test('rejects invalid pressure', () {
      expect(sensor.altitudeFromPressurePa(0), isNull);
      expect(sensor.altitudeFromPressurePa(-1), isNull);
      expect(sensor.altitudeFromPressurePa(double.nan), isNull);
    });

    test('hPa helper matches Pa helper', () {
      expect(
        sensor.altitudeFromPressureHpa(950),
        sensor.altitudeFromPressurePa(95000),
      );
    });
  });
}
