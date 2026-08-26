import 'dart:math' as math;

/// WGS-84 <-> GCJ-02 conversion ("Mars coordinates", the offset applied to
/// map data published for mainland China).
///
/// GPS reports WGS-84 (true) coordinates, while Chinese providers (AutoNavi /
/// AMap, Tencent) publish GCJ-02 tiles. Overlaying a raw WGS-84 position on a
/// GCJ-02 tile shows a visible 300~700 m offset. The Map control applies
/// [wgsToGcj] to the aircraft position (and re-center target) whenever the
/// active tile source is a GCJ-02 one, so the marker aligns with the streets.
///
/// The algorithm is the widely-used public standard (BD-09/Baidu is not
/// covered here).
class Gcj02 {
  Gcj02._();

  static const double _a = 6378245.0;
  static const double _ee = 0.00669342162296594323;

  /// Whether a coordinate is outside mainland China (skip the offset). The
  /// bounding box is intentionally a bit larger than the real border so
  /// overseas / border flights are never shifted.
  static bool outOfChina(double lat, double lon) {
    if (lon < 72.004 || lon > 137.8347) return true;
    if (lat < 0.8293 || lat > 55.8271) return true;
    return false;
  }

  /// WGS-84 -> GCJ-02 (forward). Returns `[lat, lon]`. Overseas passes through.
  static List<double> wgsToGcj(double lat, double lon) {
    if (outOfChina(lat, lon)) return [lat, lon];
    final dLat = _transformLat(lon - 105.0, lat - 35.0);
    final dLon = _transformLon(lon - 105.0, lat - 35.0);
    final radLat = lat / 180.0 * math.pi;
    var magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    final dLatFinal =
        (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
    final dLonFinal =
        (dLon * 180.0) / (_a / sqrtMagic * math.cos(radLat) * math.pi);
    return [lat + dLatFinal, lon + dLonFinal];
  }

  /// GCJ-02 -> WGS-84 (inverse, iterative). Overseas passes through.
  static List<double> gcjToWgs(double lat, double lon, {int iterations = 4}) {
    if (outOfChina(lat, lon)) return [lat, lon];
    var wgsLat = lat;
    var wgsLon = lon;
    for (int i = 0; i < iterations; i++) {
      final fwd = wgsToGcj(wgsLat, wgsLon);
      wgsLat += lat - fwd[0];
      wgsLon += lon - fwd[1];
    }
    return [wgsLat, wgsLon];
  }

  static double _transformLat(double x, double y) {
    var ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(y * math.pi) +
            40.0 * math.sin(y / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) +
            320.0 * math.sin(y * math.pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  static double _transformLon(double x, double y) {
    var ret = 300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(x * math.pi) +
            40.0 * math.sin(x / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) *
        2.0 /
        3.0;
    return ret;
  }
}
