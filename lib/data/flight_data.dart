import 'package:flutter/foundation.dart';

/// An immutable snapshot of all flight data at a point in time.
///
/// This is the single, unified shape that every control reads from, so that
/// data sources (sensors, simulators, external feeds) can be swapped without
/// touching the controls. Inspired by XCTrack's central "info" hub which
/// exposes altitude, vertical speed, position, heading, etc.
@immutable
class FlightData {
  /// Vertical speed (climb/sink) in m/s. Positive = climbing.
  final double verticalSpeed;

  /// Barometric / GPS altitude above sea level, in meters.
  final double altitude;

  /// Ground speed in km/h.
  final double groundSpeed;

  /// GPS latitude in degrees.
  final double latitude;

  /// GPS longitude in degrees.
  final double longitude;

  /// Compass heading in degrees (0..360, 0 = North).
  final double heading;

  /// Bearing to the current target in degrees (0..360), or null if none.
  final double? bearing;

  /// Wind speed in km/h.
  final double windSpeed;

  /// Wind direction in degrees (0..360, direction wind is coming from).
  final double windDirection;

  /// Whether a GPS fix is currently available.
  final bool hasFix;

  const FlightData({
    this.verticalSpeed = 0.0,
    this.altitude = 0.0,
    this.groundSpeed = 0.0,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.heading = 0.0,
    this.bearing,
    this.windSpeed = 0.0,
    this.windDirection = 0.0,
    this.hasFix = false,
  });

  static const FlightData empty = FlightData();

  FlightData copyWith({
    double? verticalSpeed,
    double? altitude,
    double? groundSpeed,
    double? latitude,
    double? longitude,
    double? heading,
    double? bearing,
    double? windSpeed,
    double? windDirection,
    bool? hasFix,
  }) {
    return FlightData(
      verticalSpeed: verticalSpeed ?? this.verticalSpeed,
      altitude: altitude ?? this.altitude,
      groundSpeed: groundSpeed ?? this.groundSpeed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      bearing: bearing ?? this.bearing,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      hasFix: hasFix ?? this.hasFix,
    );
  }
}
