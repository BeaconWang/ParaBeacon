import 'dart:math' as math;

import 'flight_recorder.dart';

/// A stable, human-facing identifier for a flight, derived purely from its
/// start time. Used by the exporters and the library bundle so the same flight
/// maps to the same filename across export/import round-trips.
String flightId(FlightTrack track) =>
    'flight_${track.startTime.toUtc().millisecondsSinceEpoch}';

/// A short, filename-safe label like `2026-09-09_1435`.
String flightSlug(FlightTrack track) {
  final t = track.startTime;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}_'
      '${two(t.hour)}${two(t.minute)}';
}

/// Derived performance metrics computed from a completed [FlightTrack]'s
/// per-sample data.
///
/// This is a self-contained port of the reference project's
/// `FlightDerivedStats`, adapted to this project's [FlightTrack]/[FlightSample]
/// model (ground speed in km/h, vertical speed in m/s). All values are computed
/// in one pass over the samples; when a track carries no per-sample data (a
/// summary-only flight restored from disk) the derived fields fall back to the
/// summary statistics where possible and to zero otherwise.
class FlightDerivedStats {
  const FlightDerivedStats({
    required this.straightDistanceM,
    required this.trackDistanceM,
    required this.maxDistanceFromStartM,
    required this.avgGroundSpeedKph,
    required this.avgCruiseSpeedKph,
    required this.maxSpeedKph,
    required this.avgClimbMs,
    required this.avgSinkMs,
    required this.avgGlideRatio,
    required this.trackEfficiency,
    required this.thermalCount,
    required this.altitudeGainedM,
    required this.altitudeLostM,
    required this.climbTime,
    required this.sinkTime,
    required this.glideTime,
    required this.movingTime,
  });

  /// Straight-line (start → end) distance, meters.
  final double straightDistanceM;

  /// Total along-track distance, meters.
  final double trackDistanceM;

  /// Farthest any point strays from the launch point, meters.
  final double maxDistanceFromStartM;

  final double avgGroundSpeedKph;

  /// Average speed while gliding (not climbing in a thermal), km/h.
  final double avgCruiseSpeedKph;
  final double maxSpeedKph;

  /// Average climb rate over climbing samples, m/s (>= 0).
  final double avgClimbMs;

  /// Average sink rate over sinking samples, m/s (<= 0).
  final double avgSinkMs;

  /// Average glide ratio over gliding segments (horizontal / vertical).
  final double avgGlideRatio;

  /// straightDistance / trackDistance, in 0..1.
  final double trackEfficiency;

  /// Number of distinct climbs (thermals) detected.
  final int thermalCount;

  final double altitudeGainedM;
  final double altitudeLostM;

  final Duration climbTime;
  final Duration sinkTime;
  final Duration glideTime;
  final Duration movingTime;

  static const FlightDerivedStats zero = FlightDerivedStats(
    straightDistanceM: 0,
    trackDistanceM: 0,
    maxDistanceFromStartM: 0,
    avgGroundSpeedKph: 0,
    avgCruiseSpeedKph: 0,
    maxSpeedKph: 0,
    avgClimbMs: 0,
    avgSinkMs: 0,
    avgGlideRatio: 0,
    trackEfficiency: 0,
    thermalCount: 0,
    altitudeGainedM: 0,
    altitudeLostM: 0,
    climbTime: Duration.zero,
    sinkTime: Duration.zero,
    glideTime: Duration.zero,
    movingTime: Duration.zero,
  );

  /// A climb of at least this sustained rate is treated as a thermal core.
  static const double _thermalThresholdMs = 0.5;

  /// Below this vertical rate (either sign) the segment counts as a glide.
  static const double _glideBandMs = 0.5;

  /// Below this ground speed (km/h) a sample is treated as stationary.
  static const double _movingSpeedKph = 2.0;

  /// Computes the derived stats for [track]. Cheap enough to call on demand.
  factory FlightDerivedStats.compute(FlightTrack track) {
    final s = track.samples;
    if (s.length < 2) {
      // Summary-only or trivial track: surface what the summary already knows.
      return FlightDerivedStats(
        straightDistanceM: 0,
        trackDistanceM: track.distanceM,
        maxDistanceFromStartM: 0,
        avgGroundSpeedKph: 0,
        avgCruiseSpeedKph: 0,
        maxSpeedKph: 0,
        avgClimbMs: 0,
        avgSinkMs: 0,
        avgGlideRatio: 0,
        trackEfficiency: 0,
        thermalCount: 0,
        altitudeGainedM: 0,
        altitudeLostM: 0,
        climbTime: Duration.zero,
        sinkTime: Duration.zero,
        glideTime: Duration.zero,
        movingTime: Duration.zero,
      );
    }

    final first = s.first;
    final last = s.last;

    double trackDist = 0;
    double maxFromStart = 0;
    double maxSpeed = 0;

    double climbSum = 0;
    int climbCount = 0;
    double sinkSum = 0;
    int sinkCount = 0;

    double gained = 0;
    double lost = 0;

    // Cruise (glide) speed accumulation.
    double cruiseSpeedSum = 0;
    int cruiseSpeedCount = 0;

    // Glide-ratio accumulation over gliding steps.
    double glideHoriz = 0;
    double glideVert = 0;

    int climbMs = 0;
    int sinkMs = 0;
    int glideMs = 0;
    int movingMs = 0;

    int thermalCount = 0;
    bool inThermal = false;

    for (var i = 1; i < s.length; i++) {
      final a = s[i - 1];
      final b = s[i];
      final dtMs = b.time.difference(a.time).inMilliseconds;
      final dt = dtMs / 1000.0;

      final stepM = _haversineM(
        a.data.latitude,
        a.data.longitude,
        b.data.latitude,
        b.data.longitude,
      );
      trackDist += stepM;

      final fromStart = _haversineM(
        first.data.latitude,
        first.data.longitude,
        b.data.latitude,
        b.data.longitude,
      );
      if (fromStart > maxFromStart) maxFromStart = fromStart;

      if (b.data.groundSpeed > maxSpeed) maxSpeed = b.data.groundSpeed;

      final dAlt = b.data.altitude - a.data.altitude;
      if (dAlt > 0) {
        gained += dAlt;
      } else {
        lost += -dAlt;
      }

      final v = b.data.verticalSpeed;
      if (v > 0) {
        climbSum += v;
        climbCount++;
      } else if (v < 0) {
        sinkSum += v;
        sinkCount++;
      }

      if (dtMs > 0) {
        if (b.data.groundSpeed > _movingSpeedKph) movingMs += dtMs;

        if (v >= _thermalThresholdMs) {
          climbMs += dtMs;
          if (!inThermal) {
            inThermal = true;
            thermalCount++;
          }
        } else {
          if (v <= -_thermalThresholdMs) {
            sinkMs += dtMs;
          }
          inThermal = false;
        }

        // Glide: near-level vertical rate while still moving forward.
        if (v.abs() < _glideBandMs && b.data.groundSpeed > _movingSpeedKph) {
          glideMs += dtMs;
          cruiseSpeedSum += b.data.groundSpeed;
          cruiseSpeedCount++;
        }

        // Glide ratio: accumulate horizontal vs. vertical while descending in
        // a glide (not thermalling).
        if (v < 0 && v > -3.0 && stepM > 0) {
          glideHoriz += stepM;
          glideVert += -v * dt; // meters lost over this step
        }
      }
    }

    final straight = _haversineM(
      first.data.latitude,
      first.data.longitude,
      last.data.latitude,
      last.data.longitude,
    );

    final totalSec =
        last.time.difference(first.time).inMilliseconds / 1000.0;
    final avgGs = totalSec > 0 ? (trackDist / totalSec) * 3.6 : 0.0;

    return FlightDerivedStats(
      straightDistanceM: straight,
      trackDistanceM: trackDist,
      maxDistanceFromStartM: maxFromStart,
      avgGroundSpeedKph: avgGs,
      avgCruiseSpeedKph:
          cruiseSpeedCount > 0 ? cruiseSpeedSum / cruiseSpeedCount : 0.0,
      maxSpeedKph: maxSpeed,
      avgClimbMs: climbCount > 0 ? climbSum / climbCount : 0.0,
      avgSinkMs: sinkCount > 0 ? sinkSum / sinkCount : 0.0,
      avgGlideRatio: glideVert > 0.5 ? glideHoriz / glideVert : 0.0,
      trackEfficiency: trackDist > 0 ? (straight / trackDist).clamp(0.0, 1.0) : 0.0,
      thermalCount: thermalCount,
      altitudeGainedM: gained,
      altitudeLostM: lost,
      climbTime: Duration(milliseconds: climbMs),
      sinkTime: Duration(milliseconds: sinkMs),
      glideTime: Duration(milliseconds: glideMs),
      movingTime: Duration(milliseconds: movingMs),
    );
  }

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * (math.pi / 180.0);
}
