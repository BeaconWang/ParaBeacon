import 'dart:math' as math;

/// Great-circle calculations shared by navigation and distance controls.
abstract final class GeoMath {
  static const double _earthRadiusMeters = 6371000.0;

  static double distanceMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    double radians(double degrees) => degrees * math.pi / 180;

    final deltaLatitude = radians(latitude2 - latitude1);
    final deltaLongitude = radians(longitude2 - longitude1);
    final sinLatitude = math.sin(deltaLatitude / 2);
    final sinLongitude = math.sin(deltaLongitude / 2);
    final a =
        (sinLatitude * sinLatitude +
                math.cos(radians(latitude1)) *
                    math.cos(radians(latitude2)) *
                    sinLongitude *
                    sinLongitude)
            .clamp(0.0, 1.0)
            .toDouble();
    return 2 * _earthRadiusMeters * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double bearingDegrees(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    double radians(double degrees) => degrees * math.pi / 180;

    final deltaLongitude = radians(longitude2 - longitude1);
    final y = math.sin(deltaLongitude) * math.cos(radians(latitude2));
    final x =
        math.cos(radians(latitude1)) * math.sin(radians(latitude2)) -
        math.sin(radians(latitude1)) *
            math.cos(radians(latitude2)) *
            math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
