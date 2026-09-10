import 'dart:math' as math;

/// The sun's apparent position in the sky for an observer, expressed as a
/// horizontal-coordinate pair.
class SolarPosition {
  const SolarPosition({
    required this.azimuthDeg,
    required this.elevationDeg,
  });

  /// Compass bearing to the sun, degrees clockwise from true north (0..360).
  final double azimuthDeg;

  /// Angle of the sun above the horizon, degrees (negative = below horizon).
  final double elevationDeg;

  /// Whether the sun is above the (astronomical) horizon.
  bool get isUp => elevationDeg > 0;
}

/// Computes the sun's [SolarPosition] from a geographic position and UTC time.
///
/// This is a compact implementation of the NOAA solar-position equations
/// (accurate to a fraction of a degree for the purposes of a map overlay). It
/// intentionally has no dependencies so it can be used from any widget without
/// wiring up a service — mirroring the "Show sun position" feature of
/// XCTrack's Thermal Assistant.
class SolarCalculator {
  const SolarCalculator._();

  static const double _deg2rad = math.pi / 180.0;
  static const double _rad2deg = 180.0 / math.pi;

  /// Returns the sun position for [latDeg]/[lonDeg] at [utc] (defaults to now).
  static SolarPosition at(double latDeg, double lonDeg, {DateTime? utc}) {
    final when = (utc ?? DateTime.now().toUtc());

    // Julian day / century (NOAA).
    final jd = _julianDay(when);
    final t = (jd - 2451545.0) / 36525.0;

    // Geometric mean longitude and anomaly of the sun (deg).
    final l0 = _norm360(280.46646 + t * (36000.76983 + t * 0.0003032));
    final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
    final mRad = m * _deg2rad;

    // Sun's equation of centre.
    final c = math.sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        math.sin(2 * mRad) * (0.019993 - 0.000101 * t) +
        math.sin(3 * mRad) * 0.000289;

    final trueLong = l0 + c;
    // Apparent longitude (correct for nutation/aberration).
    final omega = 125.04 - 1934.136 * t;
    final lambda =
        trueLong - 0.00569 - 0.00478 * math.sin(omega * _deg2rad);
    final lambdaRad = lambda * _deg2rad;

    // Mean obliquity of the ecliptic, with correction.
    final seconds =
        21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813));
    final e0 = 23.0 + (26.0 + seconds / 60.0) / 60.0;
    final e = (e0 + 0.00256 * math.cos(omega * _deg2rad)) * _deg2rad;

    // Declination and right ascension.
    final decl = math.asin(math.sin(e) * math.sin(lambdaRad));
    final ra = math.atan2(
      math.cos(e) * math.sin(lambdaRad),
      math.cos(lambdaRad),
    );

    // Greenwich mean sidereal time, then local hour angle.
    final gmst = _norm360(280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        t * t * (0.000387933 - t / 38710000.0));
    final lst = _norm360(gmst + lonDeg);
    var ha = (lst * _deg2rad) - ra;
    // Wrap hour angle to [-pi, pi].
    ha = math.atan2(math.sin(ha), math.cos(ha));

    final latRad = latDeg * _deg2rad;

    // Elevation (altitude) above the horizon.
    final sinAlt = math.sin(latRad) * math.sin(decl) +
        math.cos(latRad) * math.cos(decl) * math.cos(ha);
    final altitude = math.asin(sinAlt.clamp(-1.0, 1.0));

    // Azimuth measured clockwise from true north.
    final azimuth = math.atan2(
      math.sin(ha),
      math.cos(ha) * math.sin(latRad) - math.tan(decl) * math.cos(latRad),
    );
    // The formula above yields azimuth measured from south; convert to a
    // north-referenced compass bearing.
    final azDeg = _norm360(azimuth * _rad2deg + 180.0);

    return SolarPosition(
      azimuthDeg: azDeg,
      elevationDeg: altitude * _rad2deg,
    );
  }

  /// Julian day number for a UTC [when] (including fractional day).
  static double _julianDay(DateTime when) {
    var year = when.year;
    var month = when.month;
    final day = when.day +
        (when.hour +
                (when.minute + (when.second + when.millisecond / 1000.0) / 60.0) /
                    60.0) /
            24.0;
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  static double _norm360(double deg) {
    var d = deg % 360.0;
    if (d < 0) d += 360.0;
    return d;
  }
}
