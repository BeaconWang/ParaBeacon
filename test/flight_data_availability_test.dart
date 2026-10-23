import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/custom_announcement_rule.dart';
import 'package:parabeacon/controls/data_value_control.dart';
import 'package:parabeacon/data/debug_settings.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_data_provider.dart';
import 'package:parabeacon/data/flight_data_transformer.dart';
import 'package:parabeacon/data/geo_math.dart';
import 'package:parabeacon/data/raw_flight_data_source.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  test('derives plausible speed from consecutive accurate GPS fixes', () {
    final speed = GeoMath.groundSpeedKmhBetween(
      latitude1: 0,
      longitude1: 0,
      timestamp1: DateTime.utc(2026, 1, 1),
      accuracy1: 4,
      latitude2: 0,
      longitude2: 0.0001,
      timestamp2: DateTime.utc(2026, 1, 1, 0, 0, 1),
      accuracy2: 4,
    );

    expect(speed, closeTo(40, 0.1));
    expect(
      GeoMath.groundSpeedKmhBetween(
        latitude1: 0,
        longitude1: 0,
        timestamp1: DateTime.utc(2026, 1, 1),
        accuracy1: 60,
        latitude2: 0,
        longitude2: 0.0001,
        timestamp2: DateTime.utc(2026, 1, 1, 0, 0, 1),
        accuracy2: 4,
      ),
      isNull,
    );
  });

  test('GPS altitude availability is cleared when a fix has no altitude', () {
    const initial = FlightData(hasFix: true, gpsAltitude: 1234, altitude: 1234);
    final updated = initial.copyWith(hasFix: true, clearGpsAltitude: true);

    expect(initial.hasAltitude, isTrue);
    expect(updated.gpsAltitude, isNull);
    expect(updated.hasAltitude, isFalse);
  });

  test('custom announcements ignore unavailable GPS measurements', () {
    const data = FlightData(hasFix: true, hasGroundSpeed: false);
    expect(AnnouncementMetric.groundSpeed.valueFor(data).isNaN, isTrue);
    expect(AnnouncementMetric.altitude.valueFor(data).isNaN, isTrue);
  });

  testWidgets('ground speed, glide ratio, and altitude use live availability', (
    tester,
  ) async {
    final source = BluetoothSensorFlightDataSource(
      debugSettings: DebugSettings.instance,
    );
    final transformer = FlightDataTransformer(rawSource: source);
    addTearDown(() {
      transformer.dispose();
      source.dispose();
    });

    source.ingestVerticalSpeed(-1.2);
    source.ingestGpsSnapshot(
      latitude: 46.5,
      longitude: 6.6,
      heading: 90,
      groundSpeedKmh: 0,
      hasGroundSpeed: false,
      gpsAltitude: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FlightDataProvider(
          transformer: transformer,
          child: const Scaffold(
            body: Column(
              children: [
                SizedBox(height: 110, child: GroundSpeedControl()),
                SizedBox(height: 110, child: GlideRatioControl()),
                SizedBox(height: 110, child: AltitudeControl()),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('--'), findsNWidgets(3));

    source.ingestGpsSnapshot(
      latitude: 46.5001,
      longitude: 6.6,
      heading: 90,
      groundSpeedKmh: 36,
      hasGroundSpeed: true,
      gpsAltitude: 1250,
    );
    await tester.pump();

    expect(find.text('36'), findsOneWidget);
    expect(find.text('8.3'), findsOneWidget);
    expect(find.text('1250'), findsOneWidget);
  });
}
