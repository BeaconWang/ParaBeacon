import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_derived_stats.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/igc_import_service.dart';

void main() {
  group('XCTrack-compatible flight details', () {
    test('uses GNSS altitude and 30-second climb/sink intervals', () {
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

      expect(track.maxAltitude, 130);
      expect(track.minAltitude, 90);
      expect(track.maxAltGainM, 30);
      expect(track.elevationDropM, 10);
      expect(track.maxClimb, closeTo(1, 1e-9));
      expect(track.maxSink, closeTo(-2 / 3, 1e-9));
      expect(track.duration, const Duration(seconds: 90));
      expect(track.distanceM, closeTo(667.17, 1.0));

      final restored = FlightTrack.fromSummaryJson(track.toSummaryJson())!;
      expect(restored.maxClimb, closeTo(track.maxClimb, 1e-9));
      expect(restored.maxSink, closeTo(track.maxSink, 1e-9));
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

      final stats = FlightDerivedStats.compute(track);
      expect(stats.straightDistanceM, greaterThan(1100));
      expect(stats.straightDistanceM, lessThan(1120));
      expect(stats.trackDistanceM, greaterThan(stats.straightDistanceM));
    });

    test('imports XCTrack pilot, glider, site, and GNSS endpoint altitude', () {
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
      expect(track.takeoffAltitude, 2000);
      expect(track.landingAltitude, 2010);
      expect(track.maxAltitude, 2010);
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
