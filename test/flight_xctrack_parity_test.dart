import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_derived_stats.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/igc_import_service.dart';

void main() {
  group('XCTrack-compatible flight details', () {
    test(
      'uses barometric-first altitude and 30-second climb/sink intervals',
      () {
        final start = DateTime.utc(2026, 9, 19, 12);
        final track = FlightTrack(startTime: start);
        final altitudes = [100.0, 115.0, 130.0, 120.0, 110.0, 100.0, 90.0];
        for (var i = 0; i < altitudes.length; i++) {
          track.add(
            FlightSample(
              time: start.add(Duration(seconds: i * 15)),
              data: FlightData(
                altitude: altitudes[i] + 400,
                gpsAltitude: altitudes[i],
                baroAltitude: altitudes[i] + 400,
                latitude: 0,
                longitude: i * 0.001,
                hasFix: true,
              ),
            ),
          );
        }
        track.endTime = start.add(const Duration(seconds: 90));

        expect(track.takeoffAltitude, 500);
        expect(track.landingAltitude, 490);
        expect(track.maxAltitude, 530);
        expect(track.minAltitude, 490);
        expect(track.maxAltGainM, 30);
        expect(track.elevationDropM, 10);
        expect(track.maxClimb, closeTo(1, 1e-9));
        expect(track.maxSink, closeTo(-2 / 3, 1e-9));
        expect(track.duration, const Duration(seconds: 90));
        expect(track.distanceM, closeTo(667.17, 1.0));

        final stats = FlightDerivedStats.compute(track);
        expect(stats.altitudeGainedM, 30);
        expect(stats.altitudeLostM, 40);
        expect(stats.maxAltGainM, 30);
        expect(stats.elevationDropM, 10);

        final restored = FlightTrack.fromSummaryJson(track.toSummaryJson())!;
        expect(restored.maxClimb, closeTo(track.maxClimb, 1e-9));
        expect(restored.maxSink, closeTo(track.maxSink, 1e-9));
      },
    );

    test(
      'ignores a low GPS altitude when barometric altitude is available',
      () {
        final start = DateTime.utc(2026, 9, 19, 12);
        final track = FlightTrack(startTime: start);
        final barometricAltitudes = [200.0, 201.0, 202.0];
        final gpsAltitudes = [230.0, 5.0, 232.0];
        for (var i = 0; i < barometricAltitudes.length; i++) {
          track.add(
            FlightSample(
              time: start.add(Duration(seconds: i * 15)),
              data: FlightData(
                altitude: barometricAltitudes[i],
                baroAltitude: barometricAltitudes[i],
                gpsAltitude: gpsAltitudes[i],
                latitude: 0,
                longitude: i * 0.001,
                hasFix: true,
              ),
            ),
          );
        }

        expect(track.minAltitude, 200);
        expect(track.maxAltitude, 202);
        expect(track.maxAltGainM, 2);
        expect(track.elevationDropM, -2);
        expect(track.maxClimb, closeTo(2 / 30, 1e-9));

        final stats = FlightDerivedStats.compute(track);
        expect(stats.altitudeGainedM, 2);
        expect(stats.altitudeLostM, 0);
        expect(stats.maxAltGainM, 2);
        expect(stats.elevationDropM, -2);
      },
    );

    test('falls back to GPS altitude when barometric altitude is absent', () {
      final start = DateTime.utc(2026, 9, 19, 12);
      final track = FlightTrack(startTime: start);
      for (var i = 0; i < 2; i++) {
        track.add(
          FlightSample(
            time: start.add(Duration(seconds: i * 15)),
            data: FlightData(
              altitude: 900 + i * 100,
              gpsAltitude: 100 + i * 10,
              latitude: 0,
              longitude: i * 0.001,
              hasFix: true,
            ),
          ),
        );
      }

      expect(track.minAltitude, 100);
      expect(track.maxAltitude, 110);
      expect(track.takeoffAltitude, 100);
      expect(track.landingAltitude, 110);
    });

    test('VP2 straight distance is the furthest pair of fixes', () {
      final start = DateTime.utc(2026, 9, 19, 12);
      final track = FlightTrack(startTime: start);
      final longitudes = [0.0, 0.01, 0.001];
      for (var i = 0; i < longitudes.length; i++) {
        track.add(
          FlightSample(
            time: start.add(Duration(seconds: i * 10)),
            data: FlightData(
              altitude: 1000,
              gpsAltitude: 1000,
              latitude: 0,
              longitude: longitudes[i],
              hasFix: true,
            ),
          ),
        );
      }

      expect(track.takeoffAltitude, 1000);
      expect(track.landingAltitude, 1000);

      final stats = FlightDerivedStats.compute(track);
      expect(stats.straightDistanceM, greaterThan(1100));
      expect(stats.straightDistanceM, lessThan(1120));
      expect(stats.trackDistanceM, greaterThan(stats.straightDistanceM));
    });

    test('uses the first and last records with barometric-first altitude', () {
      final start = DateTime.utc(2026, 9, 19, 12);
      final track = FlightTrack(startTime: start);
      track.add(
        FlightSample(
          time: start,
          data: const FlightData(
            altitude: 1100,
            baroAltitude: 1200,
            gpsAltitude: 1150,
          ),
        ),
      );
      track.add(
        FlightSample(
          time: start.add(const Duration(seconds: 10)),
          data: const FlightData(
            altitude: 1210,
            gpsAltitude: 1210,
            latitude: 0,
            longitude: 0,
            hasFix: true,
          ),
        ),
      );
      track.add(
        FlightSample(
          time: start.add(const Duration(seconds: 20)),
          data: const FlightData(altitude: 1250, gpsAltitude: 1250),
        ),
      );

      expect(track.takeoffAltitude, 1200);
      expect(track.landingAltitude, 1250);
    });

    test('imports XCTrack metadata and barometric endpoint altitude', () {
      final content = [
        'HFDTE190926',
        'HFPLTPILOTINCHARGE:Sample Pilot',
        'HFGTYGLIDERTYPE:Test Wing',
        'HOSITSITE:Launch Ridge',
        _bRecord('120000', longitudeMinutes: 0, pressure: 1000, gnss: 2000),
        _bRecord('120030', longitudeMinutes: 60, pressure: 1005, gnss: 2010),
      ].join('\n');

      final track = IgcImportService.instance.parseString(content)!;
      expect(track.pilotName, 'Sample Pilot');
      expect(track.aircraftModel, 'Test Wing');
      expect(track.aircraftLabel, 'Test Wing');
      expect(track.takeoffSite, 'Launch Ridge');
      expect(track.takeoffAltitude, 1000);
      expect(track.landingAltitude, 1005);
      expect(track.maxAltitude, 1005);
      expect(track.minAltitude, 1000);
      expect(track.maxClimb, closeTo(5 / 30, 1e-6));
    });
  });
}

String _bRecord(
  String time, {
  required int longitudeMinutes,
  required int pressure,
  required int gnss,
}) {
  String digits(int value, int width) => value.toString().padLeft(width, '0');
  return 'B$time${digits(47, 2)}${digits(0, 5)}N'
      '${digits(8, 3)}${digits(longitudeMinutes, 5)}EA'
      '${digits(pressure, 5)}${digits(gnss, 5)}';
}
