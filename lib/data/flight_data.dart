import 'package:flutter/foundation.dart';

/// A read-only, observable view of the latest [FlightData].
///
/// Both the *raw data layer* (`RawFlightDataSource`) and the *data-transform
/// layer* (`FlightDataTransformer`) implement this, so consumers (vario audio,
/// flight recorder, ...) can depend on whichever layer is appropriate without
/// caring about the concrete type. Being a [Listenable], callers can subscribe
/// to be notified whenever [data] changes.
abstract class FlightDataView implements Listenable {
  /// The latest flight-data snapshot.
  FlightData get data;
}

/// An immutable snapshot of all flight data at a point in time.
///
/// This is the single, unified shape that every control reads from, so that
/// data sources (sensors, simulators, external feeds) can be swapped without
/// touching the controls. Inspired by XCTrack's central "info" hub which
/// exposes altitude, vertical speed, position, heading, etc.
///
/// Fields are grouped into:
///   * Motion:    [verticalSpeed], [groundSpeed].
///   * Altitude:  [altitude] (effective), [baroAltitude], [gpsAltitude].
///   * Position:  [latitude], [longitude], [heading], [bearing], GPS quality.
///   * Air/wind:  [windSpeed], [windDirection], [pressure], [temperature].
///   * Housekeeping / maintenance: [battery], [heartRate], [timestamp].
///
/// Newer "maintenance" fields are nullable so an absent sensor simply reports
/// `null` (rather than a misleading 0), while the original always-present
/// fields keep their defaults for backward compatibility.
@immutable
class FlightData {
  // ── Motion ────────────────────────────────────────────────────────────────

  /// Vertical speed (climb/sink) in m/s. Positive = climbing.
  final double verticalSpeed;

  /// Ground speed in km/h.
  final double groundSpeed;

  /// Whether the current position supplied a measured ground speed.
  final bool hasGroundSpeed;

  // ── Altitude ────────────────────────────────────────────────────────────

  /// The effective altitude above sea level, in meters. Prefers the
  /// barometric altitude when available, otherwise the GPS altitude. Kept as a
  /// non-null convenience value for controls that just want "the altitude".
  final double altitude;

  /// Barometric altitude in meters (derived from [pressure]), or null when no
  /// pressure sensor is contributing.
  final double? baroAltitude;

  /// GPS (geometric) altitude in meters, or null without a 3D GPS fix.
  final double? gpsAltitude;

  /// Terrain elevation at the current position, in meters, when available.
  /// Null follows XCTrack's fallback for an unavailable terrain query.
  final double? terrainElevationM;

  // ── Position / navigation ─────────────────────────────────────────────────

  /// GPS latitude in degrees.
  final double latitude;

  /// GPS longitude in degrees.
  final double longitude;

  /// Compass heading in degrees (0..360, 0 = North).
  final double heading;

  /// Whether [heading] is a measured GPS course suitable for wind estimation.
  final bool hasHeading;

  /// Bearing to the current target in degrees (0..360), or null if none.
  final double? bearing;

  /// Horizontal GPS accuracy in meters, or null when unknown.
  final double? gpsAccuracy;

  /// Number of satellites used in the current fix, or null when unknown.
  final int? satellites;

  /// Whether a GPS fix is currently available.
  final bool hasFix;

  /// Whether the GPS location is marked as a mock location by the platform.
  final bool isMockLocation;

  // ── Air / wind ──────────────────────────────────────────────────────────

  /// Wind speed in km/h.
  final double windSpeed;

  /// Wind direction in degrees (0..360, direction wind is coming from).
  final double windDirection;

  /// Barometric pressure in hectopascals (hPa), or null without a baro sensor.
  final double? pressure;

  /// Outside air temperature in degrees Celsius, or null when unknown.
  final double? temperature;

  // ── Housekeeping / maintenance ────────────────────────────────────────────

  /// Connected-sensor battery level, 0..100 percent, or null when unknown.
  final int? battery;

  /// Pilot heart rate in bpm (from a paired HR strap), or null when unknown.
  final int? heartRate;

  /// When this snapshot was produced or last updated by a sensor.
  final DateTime? timestamp;

  /// When the GPS position/fix was measured. Kept separate from [timestamp]
  /// because non-GPS sensors may refresh the snapshot while GPS is stale.
  final DateTime? gpsTimestamp;

  const FlightData({
    this.verticalSpeed = 0.0,
    this.groundSpeed = 0.0,
    this.hasGroundSpeed = true,
    this.altitude = 0.0,
    this.baroAltitude,
    this.gpsAltitude,
    this.terrainElevationM,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.heading = 0.0,
    this.hasHeading = true,
    this.bearing,
    this.gpsAccuracy,
    this.satellites,
    this.hasFix = false,
    this.isMockLocation = false,
    this.windSpeed = 0.0,
    this.windDirection = 0.0,
    this.pressure,
    this.temperature,
    this.battery,
    this.heartRate,
    this.timestamp,
    this.gpsTimestamp,
  });

  static const FlightData empty = FlightData();

  FlightData copyWith({
    double? verticalSpeed,
    double? groundSpeed,
    bool? hasGroundSpeed,
    double? altitude,
    double? baroAltitude,
    double? gpsAltitude,
    double? terrainElevationM,
    double? latitude,
    double? longitude,
    double? heading,
    bool? hasHeading,
    double? bearing,
    double? gpsAccuracy,
    int? satellites,
    bool? hasFix,
    bool? isMockLocation,
    double? windSpeed,
    double? windDirection,
    double? pressure,
    double? temperature,
    int? battery,
    int? heartRate,
    DateTime? timestamp,
    DateTime? gpsTimestamp,
  }) {
    return FlightData(
      verticalSpeed: verticalSpeed ?? this.verticalSpeed,
      groundSpeed: groundSpeed ?? this.groundSpeed,
      hasGroundSpeed: hasGroundSpeed ?? this.hasGroundSpeed,
      altitude: altitude ?? this.altitude,
      baroAltitude: baroAltitude ?? this.baroAltitude,
      gpsAltitude: gpsAltitude ?? this.gpsAltitude,
      terrainElevationM: terrainElevationM ?? this.terrainElevationM,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      hasHeading: hasHeading ?? this.hasHeading,
      bearing: bearing ?? this.bearing,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      satellites: satellites ?? this.satellites,
      hasFix: hasFix ?? this.hasFix,
      isMockLocation: isMockLocation ?? this.isMockLocation,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      pressure: pressure ?? this.pressure,
      temperature: temperature ?? this.temperature,
      battery: battery ?? this.battery,
      heartRate: heartRate ?? this.heartRate,
      timestamp: timestamp ?? this.timestamp,
      gpsTimestamp: gpsTimestamp ?? this.gpsTimestamp,
    );
  }

  /// Serializes this snapshot to a compact JSON map. Nullable fields are
  /// omitted when absent to keep the payload small; [fromJson] treats missing
  /// keys as their default/null. Used to persist per-sample flight tracks.
  ///
  /// When [compact] is true, only the core, XCTrack/IGC-style fields are
  /// written per point (position, barometric + GPS altitude, heading, ground
  /// speed, fix validity, timestamp). The auxiliary sensor data (vario, wind,
  /// pressure, temperature, accuracy, satellites, battery, heart rate) is
  /// dropped to produce smaller tracks. [fromJson] restores the omitted fields
  /// to their defaults/null.
  Map<String, dynamic> toJson({bool compact = false}) {
    if (compact) {
      final map = <String, dynamic>{
        'gs': groundSpeed,
        'hasGs': hasGroundSpeed,
        'alt': altitude,
        'lat': latitude,
        'lng': longitude,
        'hdg': heading,
        'hasHdg': hasHeading,
        'fix': hasFix,
        'mock': isMockLocation,
      };
      if (baroAltitude != null) map['balt'] = baroAltitude;
      if (gpsAltitude != null) map['galt'] = gpsAltitude;
      if (terrainElevationM != null) map['terrain'] = terrainElevationM;
      if (timestamp != null) map['ts'] = timestamp!.toIso8601String();
      if (gpsTimestamp != null) map['gpsTs'] = gpsTimestamp!.toIso8601String();
      return map;
    }
    final map = <String, dynamic>{
      've': verticalSpeed,
      'gs': groundSpeed,
      'hasGs': hasGroundSpeed,
      'alt': altitude,
      'lat': latitude,
      'lng': longitude,
      'hdg': heading,
      'hasHdg': hasHeading,
      'fix': hasFix,
      'mock': isMockLocation,
      'ws': windSpeed,
      'wd': windDirection,
    };
    if (baroAltitude != null) map['balt'] = baroAltitude;
    if (gpsAltitude != null) map['galt'] = gpsAltitude;
    if (terrainElevationM != null) map['terrain'] = terrainElevationM;
    if (bearing != null) map['brg'] = bearing;
    if (gpsAccuracy != null) map['acc'] = gpsAccuracy;
    if (satellites != null) map['sat'] = satellites;
    if (pressure != null) map['prs'] = pressure;
    if (temperature != null) map['tmp'] = temperature;
    if (battery != null) map['bat'] = battery;
    if (heartRate != null) map['hr'] = heartRate;
    if (timestamp != null) map['ts'] = timestamp!.toIso8601String();
    if (gpsTimestamp != null) map['gpsTs'] = gpsTimestamp!.toIso8601String();
    return map;
  }

  /// Inverse of [toJson]. Missing keys fall back to constructor defaults.
  static FlightData fromJson(Map<String, dynamic> json) {
    double? d(String k) => (json[k] as num?)?.toDouble();
    int? i(String k) => (json[k] as num?)?.toInt();
    return FlightData(
      verticalSpeed: d('ve') ?? 0.0,
      groundSpeed: d('gs') ?? 0.0,
      hasGroundSpeed: json['hasGs'] as bool? ?? true,
      altitude: d('alt') ?? 0.0,
      baroAltitude: d('balt'),
      gpsAltitude: d('galt'),
      terrainElevationM: d('terrain'),
      latitude: d('lat') ?? 0.0,
      longitude: d('lng') ?? 0.0,
      heading: d('hdg') ?? 0.0,
      hasHeading: json['hasHdg'] as bool? ?? true,
      bearing: d('brg'),
      gpsAccuracy: d('acc'),
      satellites: i('sat'),
      hasFix: json['fix'] as bool? ?? false,
      isMockLocation: json['mock'] as bool? ?? false,
      windSpeed: d('ws') ?? 0.0,
      windDirection: d('wd') ?? 0.0,
      pressure: d('prs'),
      temperature: d('tmp'),
      battery: i('bat'),
      heartRate: i('hr'),
      timestamp: DateTime.tryParse(json['ts'] as String? ?? ''),
      gpsTimestamp: DateTime.tryParse(json['gpsTs'] as String? ?? ''),
    );
  }
}
