import 'dart:math' as math;

import 'gcj02.dart';

/// WGS-84/GCJ-02 <-> BD-09 conversions used to align Baidu tiles and overlays.
class Baidu09 {
  Baidu09._();

  static const double _xPi = math.pi * 3000 / 180;

  /// Converts WGS-84 to BD-09, returning `[latitude, longitude]`.
  static List<double> wgsToBd(double latitude, double longitude) {
    final gcj = Gcj02.wgsToGcj(latitude, longitude);
    return gcjToBd(gcj[0], gcj[1]);
  }

  /// Converts BD-09 to WGS-84, returning `[latitude, longitude]`.
  static List<double> bdToWgs(double latitude, double longitude) {
    final gcj = bdToGcj(latitude, longitude);
    return Gcj02.gcjToWgs(gcj[0], gcj[1]);
  }

  /// Converts XYZ indices to Baidu's origin-centered tile index system.
  ///
  /// The upper-right tile around the map origin is `(0, 0)` in Baidu's scheme.
  /// When [convertWgsToBd] is true, the XYZ tile center is treated as WGS-84
  /// and shifted before its Baidu tile index is calculated (offline-map gaps).
  static (int x, int y) tileFromXyz({
    required int x,
    required int y,
    required int z,
    bool convertWgsToBd = false,
  }) {
    if (z <= 0) return (0, 0);
    final world = 1 << z;
    if (convertWgsToBd) {
      final longitude = (x + 0.5) / world * 360 - 180;
      final latitudeRadians =
          2 * math.atan(math.exp(math.pi * (1 - 2 * (y + 0.5) / world))) -
          math.pi / 2;
      final latitude = latitudeRadians * 180 / math.pi;
      final shifted = wgsToBd(latitude, longitude);
      final shiftedLatRadians = shifted[0] * math.pi / 180;
      x = ((shifted[1] + 180) / 360 * world).floor().clamp(0, world - 1);
      y =
          ((1 -
                      math.log(
                            math.tan(shiftedLatRadians) +
                                1 / math.cos(shiftedLatRadians),
                          ) /
                          math.pi) /
                  2 *
                  world)
              .floor()
              .clamp(0, world - 1);
    }
    final halfWorld = world >> 1;
    return (x - halfWorld, halfWorld - y - 1);
  }

  /// Converts GCJ-02 to BD-09, returning `[latitude, longitude]`.
  static List<double> gcjToBd(double latitude, double longitude) {
    final radius =
        math.sqrt(longitude * longitude + latitude * latitude) +
        0.00002 * math.sin(latitude * _xPi);
    final angle =
        math.atan2(latitude, longitude) + 0.000003 * math.cos(longitude * _xPi);
    return [
      radius * math.sin(angle) + 0.006,
      radius * math.cos(angle) + 0.0065,
    ];
  }

  /// Converts BD-09 to GCJ-02, returning `[latitude, longitude]`.
  static List<double> bdToGcj(double latitude, double longitude) {
    final x = longitude - 0.0065;
    final y = latitude - 0.006;
    final radius = math.sqrt(x * x + y * y) - 0.00002 * math.sin(y * _xPi);
    final angle = math.atan2(y, x) - 0.000003 * math.cos(x * _xPi);
    return [radius * math.sin(angle), radius * math.cos(angle)];
  }
}
