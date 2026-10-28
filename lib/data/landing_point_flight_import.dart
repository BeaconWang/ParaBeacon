import 'flight_recorder.dart';

class LandingPointFlightLocation {
  const LandingPointFlightLocation({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.altitudeM,
  });

  final double latitude;
  final double longitude;
  final double? altitudeM;
  final DateTime capturedAt;

  static LandingPointFlightLocation? fromTrack(FlightTrack track) {
    for (final sample in track.samples.reversed) {
      final data = sample.data;
      if (!_hasValidCoordinates(data.latitude, data.longitude) ||
          !data.hasFix) {
        continue;
      }
      return LandingPointFlightLocation(
        latitude: data.latitude,
        longitude: data.longitude,
        altitudeM:
            _validAltitude(data.gpsAltitude) ??
            _validAltitude(data.baroAltitude),
        capturedAt: sample.time,
      );
    }

    final latitude = track.landingLatitude;
    final longitude = track.landingLongitude;
    if (latitude == null ||
        longitude == null ||
        !_hasValidCoordinates(latitude, longitude)) {
      return null;
    }
    return LandingPointFlightLocation(
      latitude: latitude,
      longitude: longitude,
      altitudeM: _validAltitude(track.landingAltitude),
      capturedAt: track.lastRecordedTime,
    );
  }

  static bool _hasValidCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static double? _validAltitude(double? altitude) =>
      altitude != null &&
          altitude.isFinite &&
          altitude >= -12000 &&
          altitude <= 100000
      ? altitude
      : null;
}
