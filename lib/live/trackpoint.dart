/// LiveTrackpoint / LiveTrackpointHP + the GPS fix record.
///
/// smali_classes3/org/xcontest/XCTrack/live/LiveTrackpoint.smali
/// smali_classes3/org/xcontest/XCTrack/live/LiveTrackpointHP.smali
library;

import 'timeutil.dart';

/// Java `Math.round` semantics (half up), not Dart's `round()` (half away from
/// zero is the same here, but `roundToDouble` is not available on all ints).
int javaRound(double x) => (x + 0.5).floor();

/// One GPS fix, standing in for `org/xcontest/XCTrack/j`.
class Fix {
  final double lat;
  final double lon;
  final DateTime time;
  final double gpsAlt;
  final int baroAlt;
  final bool baroValid;
  final double elevation;
  final bool timeValid;
  final double speed;
  final double vspeed;

  const Fix({
    required this.lat,
    required this.lon,
    required this.time,
    this.gpsAlt = 0,
    this.baroAlt = 0,
    this.baroValid = false,
    this.elevation = 0,
    this.timeValid = true,
    this.speed = 0,
    this.vspeed = 0,
  });
}

class LiveTrackpoint {
  final double lat;
  final double lon;
  final DateTime timestamp;
  final int gpsAlt;
  final int baroAlt;
  final int elevation;

  /// ints are 1e-5 degrees / metres
  static const double scale = 100000.0;

  /// coordinates snapped to 1/60000 deg (~1.8 m)
  static const double grid = 60000.0;

  const LiveTrackpoint({
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.gpsAlt = 0,
    this.baroAlt = 0,
    this.elevation = 0,
  });

  factory LiveTrackpoint.fromFix(Fix fix) {
    final baro = (fix.baroValid && fix.baroAlt.abs() <= 10000) ? fix.baroAlt : 0;
    return LiveTrackpoint(
      lat: fix.lat,
      lon: fix.lon,
      timestamp: utc(fix.time), // truncated to whole seconds, GMT
      gpsAlt: javaRound(fix.gpsAlt),
      baroAlt: baro,
      elevation: javaRound(fix.elevation),
    );
  }

  double _snap(double deg) => javaRound(deg * grid) / grid;

  /// `b()` - the wire form: [lat, lon, tstamp(s), gpsAlt, baroAlt, elevation].
  List<int> toInts() => <int>[
        javaRound(_snap(lat) * scale),
        javaRound(_snap(lon) * scale),
        epochSeconds(timestamp),
        gpsAlt,
        baroAlt,
        elevation,
      ];

  factory LiveTrackpoint.fromInts(List<int> raw) => LiveTrackpoint(
        lat: raw[0] / scale,
        lon: raw[1] / scale,
        timestamp: fromEpochSeconds(raw[2]),
        gpsAlt: raw[3],
        baroAlt: raw[4],
        elevation: raw[5],
      );

  /// live/LiveTrackpoint - the field is `timestamp`, annotated
  /// `@JsonAdapter(UTCTimeAdapter.class)` (live/LiveTrackpoint.smali:20-24).
  /// (`tstamp` is only used by `LiveProto$XCSendMessage`.)
  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': lat,
        'lon': lon,
        'timestamp': utcToJson(timestamp),
        'gpsAlt': gpsAlt,
        'baroAlt': baroAlt,
        'elevation': elevation,
      };

  factory LiveTrackpoint.fromJson(Map<String, dynamic> m) => LiveTrackpoint(
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        timestamp: utcFromJson((m['timestamp'] ?? m['tstamp']) as String),
        gpsAlt: (m['gpsAlt'] as num?)?.toInt() ?? 0,
        baroAlt: (m['baroAlt'] as num?)?.toInt() ?? 0,
        elevation: (m['elevation'] as num?)?.toInt() ?? 0,
      );

  /// Tolerant equality: quantisation introduces sub-decimetre noise.
  bool sameAs(LiveTrackpoint o) =>
      (lat - o.lat).abs() < 1e-4 &&
      (lon - o.lon).abs() < 1e-4 &&
      timestamp == o.timestamp &&
      gpsAlt == o.gpsAlt &&
      baroAlt == o.baroAlt &&
      elevation == o.elevation;

  @override
  String toString() =>
      'LiveTrackpoint(${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}, '
      '${utcToJson(timestamp)}, gps=$gpsAlt baro=$baroAlt elev=$elevation)';
}

/// High-precision variant: 1e6 scaling, 1/600000 deg (~0.18 m).
class LiveTrackpointHP extends LiveTrackpoint {
  static const double hpScale = 1000000.0;
  static const double hpGrid = 600000.0;

  const LiveTrackpointHP({
    required super.lat,
    required super.lon,
    required super.timestamp,
    super.gpsAlt,
    super.baroAlt,
    super.elevation,
  });

  factory LiveTrackpointHP.fromFix(Fix fix) {
    final base = LiveTrackpoint.fromFix(fix);
    return LiveTrackpointHP(
      lat: base.lat,
      lon: base.lon,
      timestamp: base.timestamp,
      gpsAlt: base.gpsAlt,
      baroAlt: base.baroAlt,
      elevation: base.elevation,
    );
  }

  @override
  double _snap(double deg) => javaRound(deg * hpGrid) / hpGrid;

  @override
  List<int> toInts() => <int>[
        javaRound(_snap(lat) * hpScale),
        javaRound(_snap(lon) * hpScale),
        epochSeconds(timestamp),
        gpsAlt,
        baroAlt,
        elevation,
      ];

  factory LiveTrackpointHP.fromInts(List<int> raw) => LiveTrackpointHP(
        lat: raw[0] / hpScale,
        lon: raw[1] / hpScale,
        timestamp: fromEpochSeconds(raw[2]),
        gpsAlt: raw[3],
        baroAlt: raw[4],
        elevation: raw[5],
      );
}
