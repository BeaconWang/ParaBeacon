import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_derived_stats.dart';
import 'package:parabeacon/data/flight_recorder.dart';

void main() {
  test(
    'flight-detail stats exclude extreme rates without changing the track',
    () {
      final track = _track([
        0,
        1,
        1,
        1,
        1,
        1518.3,
        -942.3,
        -1,
        -1,
        -1,
        1,
        1,
        1,
        1,
      ]);
      final sampleCount = track.samples.length;
      final storedMaxClimb = track.maxClimb;

      final unfiltered = FlightDerivedStats.compute(track);
      final filtered = FlightDerivedStats.compute(
        track,
        filterVarioOutliers: true,
      );

      expect(unfiltered.avgClimbMs, greaterThan(100));
      expect(unfiltered.avgSinkMs, lessThan(-100));
      expect(filtered.avgClimbMs, closeTo(1, 0.001));
      expect(filtered.avgSinkMs, closeTo(-1, 0.001));
      expect(track.samples, hasLength(sampleCount));
      expect(track.samples[5].data.verticalSpeed, 1518.3);
      expect(track.samples[6].data.verticalSpeed, -942.3);
      expect(track.maxClimb, storedMaxClimb);
    },
  );

  test('MAD threshold can reject a local spike below the absolute limit', () {
    final track = _track([0, 1, 1, 1, 1, 8, 1, 1, 1, 1, 1]);

    final filtered = FlightDerivedStats.compute(
      track,
      filterVarioOutliers: true,
      madMultiplier: 4,
      windowSeconds: 30,
      maximumVerticalSpeedMs: 20,
    );

    expect(filtered.avgClimbMs, closeTo(1, 0.001));
  });
}

FlightTrack _track(List<double> rates) {
  final start = DateTime.utc(2026, 10, 20, 10);
  final track = FlightTrack(startTime: start);
  for (var index = 0; index < rates.length; index++) {
    track.add(
      FlightSample(
        time: start.add(Duration(seconds: index)),
        data: FlightData(
          verticalSpeed: rates[index],
          altitude: 500,
          baroAltitude: 500,
          gpsAltitude: 500,
          latitude: 46,
          longitude: 7 + index * 0.0001,
          groundSpeed: 36,
          hasFix: true,
        ),
      ),
    );
  }
  return track;
}
