import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/debug_settings.dart';
import 'package:parabeacon/data/raw_flight_data_source.dart';

void main() {
  test('GPS altitude is available only while the current fix measures it', () {
    final source = BluetoothSensorFlightDataSource(
      debugSettings: DebugSettings.instance,
    );
    addTearDown(source.dispose);

    source.ingestGpsSnapshot(
      latitude: 46.5,
      longitude: 6.6,
      heading: 90,
      groundSpeedKmh: 10,
      gpsAltitude: 1234,
    );

    expect(source.data.hasFix, isTrue);
    expect(source.data.hasAltitude, isTrue);
    expect(source.data.gpsAltitude, 1234);
    expect(source.data.altitude, 1234);

    source.ingestGpsSnapshot(
      latitude: 46.5001,
      longitude: 6.6,
      heading: 90,
      groundSpeedKmh: 10,
      gpsAltitude: null,
    );

    expect(source.data.hasFix, isTrue);
    expect(source.data.gpsAltitude, isNull);
    expect(source.data.hasAltitude, isFalse);
    expect(source.data.altitude, 0);
  });
}
