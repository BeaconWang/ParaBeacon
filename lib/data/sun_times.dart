import 'dart:math' as math;

/// Sunrise / sunset computation using the standard NOAA solar equations.
///
/// Given a geographic position and a date, [SunTimes.forDate] returns the
/// sunrise and sunset instants in local time. During polar day/night (the sun
/// never crosses the horizon) the corresponding value is null.
///
/// The algorithm follows the widely used NOAA solar calculator approximation,
/// accurate to well within a minute for paragliding purposes.
class SunTimes {
  /// Local sunrise instant, or null if the sun does not rise on this date.
  final DateTime? sunrise;

  /// Local sunset instant, or null if the sun does not set on this date.
  final DateTime? sunset;

  const SunTimes(this.sunrise, this.sunset);

  static double _deg2rad(double d) => d * math.pi / 180.0;
  static double _rad2deg(double r) => r * 180.0 / math.pi;

  /// Computes sun times for [date] at ([latitude], [longitude]) (WGS-84,
  /// degrees). The result is expressed in the local time zone of [date]
  /// (its UTC offset is applied), so callers should pass a `DateTime.now()`
  /// or a date already in the desired zone.
  ///
  /// [zenith] is the solar zenith at the event; the default 90.833° accounts
  /// for atmospheric refraction and the solar disc radius (official sunrise).
  static SunTimes forDate(
    DateTime date,
    double latitude,
    double longitude, {
    double zenith = 90.833,
  }) {
    // Day of year.
    final n = _dayOfYear(date);

    // Local time-zone offset in hours (east positive).
    final tzOffsetHours = date.timeZoneOffset.inMinutes / 60.0;

    final rise = _event(n, latitude, longitude, zenith, tzOffsetHours,
        rising: true);
    final set = _event(n, latitude, longitude, zenith, tzOffsetHours,
        rising: false);

    return SunTimes(
      _toLocalDateTime(date, rise),
      _toLocalDateTime(date, set),
    );
  }

  /// Returns the event local time in hours (0..24), or null when the sun does
  /// not reach [zenith] on this date (polar day/night).
  static double? _event(
    int n,
    double lat,
    double lng,
    double zenith,
    double tzOffsetHours, {
    required bool rising,
  }) {
    // 1. Approximate time.
    final lngHour = lng / 15.0;
    final t = rising
        ? n + ((6 - lngHour) / 24.0)
        : n + ((18 - lngHour) / 24.0);

    // 2. Sun's mean anomaly.
    final m = (0.9856 * t) - 3.289;

    // 3. Sun's true longitude.
    var l = m +
        (1.916 * math.sin(_deg2rad(m))) +
        (0.020 * math.sin(_deg2rad(2 * m))) +
        282.634;
    l = _mod(l, 360.0);

    // 4. Sun's right ascension.
    var ra = _rad2deg(math.atan(0.91764 * math.tan(_deg2rad(l))));
    ra = _mod(ra, 360.0);
    // Put RA in the same quadrant as L.
    final lQuadrant = (l / 90.0).floor() * 90.0;
    final raQuadrant = (ra / 90.0).floor() * 90.0;
    ra = ra + (lQuadrant - raQuadrant);
    ra /= 15.0; // to hours

    // 5. Sun's declination.
    final sinDec = 0.39782 * math.sin(_deg2rad(l));
    final cosDec = math.cos(math.asin(sinDec));

    // 6. Sun's local hour angle.
    final cosH = (math.cos(_deg2rad(zenith)) -
            (sinDec * math.sin(_deg2rad(lat)))) /
        (cosDec * math.cos(_deg2rad(lat)));
    if (cosH > 1) return null; // sun never rises
    if (cosH < -1) return null; // sun never sets

    var h = rising
        ? 360.0 - _rad2deg(math.acos(cosH))
        : _rad2deg(math.acos(cosH));
    h /= 15.0; // to hours

    // 7. Local mean time of the event.
    final localMeanT = h + ra - (0.06571 * t) - 6.622;

    // 8. Adjust to UTC then to the requested time zone.
    var utc = localMeanT - lngHour;
    utc = _mod(utc, 24.0);
    final local = _mod(utc + tzOffsetHours, 24.0);
    return local;
  }

  static DateTime? _toLocalDateTime(DateTime date, double? hours) {
    if (hours == null) return null;
    final h = hours.floor();
    final minutesFrac = (hours - h) * 60.0;
    final m = minutesFrac.floor();
    final s = ((minutesFrac - m) * 60.0).round();
    return DateTime(date.year, date.month, date.day, h, m, s);
  }

  static int _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return d.difference(start).inDays + 1;
  }

  static double _mod(double a, double m) {
    final r = a % m;
    return r < 0 ? r + m : r;
  }
}
