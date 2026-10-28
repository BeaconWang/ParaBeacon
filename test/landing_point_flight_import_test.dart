import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_data.dart';
import 'package:parabeacon/data/flight_recorder.dart';
import 'package:parabeacon/data/landing_point_flight_import.dart';

void main() {
  final start = DateTime.utc(2026, 10, 20, 10);

  test('uses the newest valid recorded fix and its metadata', () {
    final latestFixTime = start.add(const Duration(minutes: 2));
    final track = FlightTrack(startTime: start)
      ..add(
        FlightSample(
          time: start,
          data: const FlightData(
            latitude: 46.1,
            longitude: 6.1,
            gpsAltitude: 1200,
            hasFix: true,
          ),
        ),
      )
      ..add(
        FlightSample(
          time: latestFixTime,
          data: const FlightData(
            latitude: 47.2,
            longitude: 7.2,
            baroAltitude: 1350,
            hasFix: true,
          ),
        ),
      )
      ..add(
        FlightSample(
          time: start.add(const Duration(minutes: 3)),
          data: const FlightData(latitude: 0, longitude: 0, hasFix: false),
        ),
      );

    final location = LandingPointFlightLocation.fromTrack(track);

    expect(location?.latitude, 47.2);
    expect(location?.longitude, 7.2);
    expect(location?.altitudeM, 1350);
    expect(location?.capturedAt, latestFixTime);
  });

  test('uses stored landing summary when sample data is unavailable', () {
    final track = FlightTrack(startTime: start)
      ..add(
        FlightSample(
          time: start,
          data: const FlightData(
            latitude: 46.3,
            longitude: 6.3,
            gpsAltitude: 1250,
            hasFix: true,
          ),
        ),
      )
      ..endTime = start.add(const Duration(minutes: 5));
    track.clearSamples();

    final location = LandingPointFlightLocation.fromTrack(track);

    expect(location?.latitude, 46.3);
    expect(location?.longitude, 6.3);
    expect(location?.altitudeM, 1250);
    expect(location?.capturedAt, track.endTime);
  });

  test('returns null when no valid landing location is recorded', () {
    final track = FlightTrack(startTime: start)
      ..add(
        FlightSample(
          time: start,
          data: const FlightData(latitude: 91, longitude: 6, hasFix: true),
        ),
      );

    expect(LandingPointFlightLocation.fromTrack(track), isNull);
  });
}
