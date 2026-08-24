import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'flight_data.dart';

/// Unified flight-data source.
///
/// Controls listen to this notifier and read [data] for the latest snapshot.
/// Concrete implementations (simulated, sensor-backed, external feed, ...) can
/// be swapped without changing any control.
abstract class FlightDataSource extends ChangeNotifier {
  FlightData _data = FlightData.empty;

  /// The latest flight-data snapshot.
  FlightData get data => _data;

  /// Replaces the current snapshot and notifies listeners.
  @protected
  void update(FlightData next) {
    _data = next;
    notifyListeners();
  }

  /// Starts producing data.
  void start() {}

  /// Stops producing data.
  void stop() {}
}

/// A simulated flight-data source that smoothly animates plausible values.
///
/// Useful for development and demos until real sensors are wired in. Emits a
/// new [FlightData] snapshot at [tickInterval].
class SimulatedFlightDataSource extends FlightDataSource {
  final Duration tickInterval;
  final math.Random _rand = math.Random();

  Timer? _timer;

  // Internal simulation targets that values ease toward.
  double _vsTarget = 0.0;
  double _headingTarget = 90.0;
  double _windDirTarget = 270.0;
  double _lat = 46.5197; // start somewhere plausible (Lausanne)
  double _lon = 6.6323;

  SimulatedFlightDataSource({this.tickInterval = const Duration(milliseconds: 100)});

  @override
  void start() {
    _timer ??= Timer.periodic(tickInterval, (_) => _tick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    final prev = data;

    // Occasionally pick new targets to create gentle, believable motion.
    if (_rand.nextDouble() < 0.03) {
      _vsTarget = (_rand.nextDouble() * 2 - 1) * 6.0; // -6..+6 m/s
    }
    if (_rand.nextDouble() < 0.02) {
      _headingTarget = _rand.nextDouble() * 360.0;
    }
    if (_rand.nextDouble() < 0.01) {
      _windDirTarget = _rand.nextDouble() * 360.0;
    }

    final vs = prev.verticalSpeed + (_vsTarget - prev.verticalSpeed) * 0.08;
    final heading = _lerpAngle(prev.heading, _headingTarget, 0.05);
    final windDir = _lerpAngle(prev.windDirection, _windDirTarget, 0.03);

    // Integrate altitude from vertical speed (dt = tickInterval).
    final dt = tickInterval.inMilliseconds / 1000.0;
    final altitude = (prev.altitude + vs * dt).clamp(0.0, 8000.0);

    final groundSpeed = 25.0 + math.sin(DateTime.now().millisecondsSinceEpoch / 5000.0) * 10.0;

    // Drift the position slightly based on ground speed + heading.
    final metersPerTick = (groundSpeed / 3.6) * dt;
    final headingRad = heading * math.pi / 180.0;
    _lat += (metersPerTick * math.cos(headingRad)) / 111320.0;
    _lon += (metersPerTick * math.sin(headingRad)) /
        (111320.0 * math.cos(_lat * math.pi / 180.0));

    update(prev.copyWith(
      verticalSpeed: vs,
      altitude: altitude,
      groundSpeed: groundSpeed,
      heading: heading,
      latitude: _lat,
      longitude: _lon,
      windSpeed: 12.0,
      windDirection: windDir,
      hasFix: true,
    ));
  }

  /// Linearly interpolates between two angles taking the shortest path.
  double _lerpAngle(double from, double to, double t) {
    var diff = (to - from) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    final result = (from + diff * t) % 360.0;
    return result < 0 ? result + 360.0 : result;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
