import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'flight_data.dart';

/// A set of manual overrides for individual flight-data fields.
///
/// Any non-null field replaces the corresponding value coming from the raw
/// data source. This is used by the debug bluetooth-sensor control to force
/// specific readings for testing; overridden fields take the highest priority
/// over whatever a real (or simulated) sensor reports.
@immutable
class FlightDataOverride {
  final double? verticalSpeed;
  final double? altitude;
  final double? groundSpeed;
  final double? heading;
  final double? windSpeed;
  final double? windDirection;

  const FlightDataOverride({
    this.verticalSpeed,
    this.altitude,
    this.groundSpeed,
    this.heading,
    this.windSpeed,
    this.windDirection,
  });

  static const FlightDataOverride none = FlightDataOverride();

  /// Whether any field is currently overridden.
  bool get isEmpty =>
      verticalSpeed == null &&
      altitude == null &&
      groundSpeed == null &&
      heading == null &&
      windSpeed == null &&
      windDirection == null;

  /// Returns a copy with the given fields changed. Passing `clearX: true`
  /// removes an existing override for that field.
  FlightDataOverride copyWith({
    double? verticalSpeed,
    bool clearVerticalSpeed = false,
    double? altitude,
    bool clearAltitude = false,
    double? groundSpeed,
    bool clearGroundSpeed = false,
    double? heading,
    bool clearHeading = false,
    double? windSpeed,
    bool clearWindSpeed = false,
    double? windDirection,
    bool clearWindDirection = false,
  }) {
    return FlightDataOverride(
      verticalSpeed:
          clearVerticalSpeed ? null : (verticalSpeed ?? this.verticalSpeed),
      altitude: clearAltitude ? null : (altitude ?? this.altitude),
      groundSpeed: clearGroundSpeed ? null : (groundSpeed ?? this.groundSpeed),
      heading: clearHeading ? null : (heading ?? this.heading),
      windSpeed: clearWindSpeed ? null : (windSpeed ?? this.windSpeed),
      windDirection:
          clearWindDirection ? null : (windDirection ?? this.windDirection),
    );
  }

  /// Applies these overrides on top of [base], returning the effective data.
  FlightData applyTo(FlightData base) {
    if (isEmpty) return base;
    return base.copyWith(
      verticalSpeed: verticalSpeed,
      altitude: altitude,
      groundSpeed: groundSpeed,
      heading: heading,
      windSpeed: windSpeed,
      windDirection: windDirection,
    );
  }
}

/// Priority tiers for a flight-data field, highest first.
///
/// The effective value of any field is taken from the highest-priority tier
/// that currently provides it:
///
///   1. [debugOverride]   — manual debug/bench values (ALWAYS wins).
///   2. [bluetoothSensor] — the real (or simulated) sensor feed.
///
/// i.e. **Debug > Bluetooth sensor**.
enum FlightDataPriority { debugOverride, bluetoothSensor }

/// Unified flight-data source.
///
/// Controls listen to this notifier and read [data] for the latest snapshot.
/// Concrete implementations (bluetooth sensor, simulated, external feed, ...)
/// produce the raw feed via [update]; a debug [override] can force individual
/// fields on top of it.
///
/// PRIORITY (per field, highest first):
///   [FlightDataPriority.debugOverride] > [FlightDataPriority.bluetoothSensor]
///
/// The resolution is per-field: e.g. a debug override on `verticalSpeed` wins
/// for that field even while the bluetooth sensor keeps streaming all other
/// fields at full rate.
abstract class FlightDataSource extends ChangeNotifier {
  FlightData _rawData = FlightData.empty;
  FlightDataOverride _override = FlightDataOverride.none;

  /// The latest flight-data snapshot with the priority order applied
  /// (debug override > bluetooth sensor).
  FlightData get data => _override.applyTo(_rawData);

  /// The raw snapshot as produced by the sensor feed, ignoring debug overrides
  /// (i.e. the [FlightDataPriority.bluetoothSensor] tier only).
  FlightData get rawData => _rawData;

  /// The currently installed debug override (highest priority tier).
  FlightDataOverride get override => _override;

  /// Which priority tier currently supplies the effective vertical speed.
  /// Returns [FlightDataPriority.debugOverride] when a debug vertical-speed
  /// override is active, otherwise [FlightDataPriority.bluetoothSensor].
  FlightDataPriority get verticalSpeedSource => _override.verticalSpeed != null
      ? FlightDataPriority.debugOverride
      : FlightDataPriority.bluetoothSensor;

  /// Installs a new debug [override]. Overridden fields take precedence over
  /// the raw sensor data. Notifies listeners so controls rebuild immediately.
  void setOverride(FlightDataOverride override) {
    _override = override;
    notifyListeners();
  }

  /// Removes all debug overrides, reverting to the raw sensor data.
  void clearOverride() => setOverride(FlightDataOverride.none);

  /// Replaces the current raw (bluetooth-sensor tier) snapshot and notifies
  /// listeners. Debug overrides, if any, still win over these values.
  @protected
  void update(FlightData next) {
    _rawData = next;
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
    final prev = rawData;

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

/// Bluetooth-sensor flight-data source (the [FlightDataPriority.bluetoothSensor]
/// tier).
///
/// This is the lower-priority raw feed: whatever a paired BLE vario/baro sensor
/// reports flows in via [ingestVerticalSpeed] / [ingestSnapshot] and becomes
/// [rawData]. Any active debug override still wins over these values
/// (Debug > Bluetooth sensor).
///
/// Until a physical device is wired to a BLE plugin, [connectSimulated] can be
/// used to feed plausible values so the rest of the app (and the vario audio)
/// runs end-to-end. Swap that for real BLE notifications without touching any
/// consumer — controls and the vario only read [data].
class BluetoothSensorFlightDataSource extends FlightDataSource {
  /// Optional simulator used before a real BLE device is connected.
  SimulatedFlightDataSource? _sim;

  bool _connected = false;

  /// Whether a sensor (real or simulated) is currently feeding data.
  bool get isConnected => _connected;

  /// Feeds a single vertical-speed reading from the BLE sensor (m/s), keeping
  /// all other fields as they were. This is the field the vario audio consumes.
  void ingestVerticalSpeed(double verticalSpeed) {
    if (verticalSpeed.isNaN || verticalSpeed.isInfinite) return;
    update(rawData.copyWith(verticalSpeed: verticalSpeed));
    _connected = true;
  }

  /// Feeds a full sensor snapshot from the BLE device.
  void ingestSnapshot(FlightData snapshot) {
    update(snapshot);
    _connected = true;
  }

  /// Development helper: drive the sensor tier with the built-in simulator so
  /// the app runs without a physical device. Values still sit at the
  /// bluetooth-sensor priority, so debug overrides continue to win.
  void connectSimulated({
    Duration tickInterval = const Duration(milliseconds: 100),
  }) {
    _sim ??= SimulatedFlightDataSource(tickInterval: tickInterval);
    // Mirror the simulator's raw output into this source's raw tier.
    _sim!.addListener(_onSim);
    _sim!.start();
    _connected = true;
  }

  void _onSim() {
    final sim = _sim;
    if (sim != null) update(sim.rawData);
  }

  @override
  void start() {
    // If nothing else connected a real device, fall back to the simulator so
    // there is always a bluetooth-sensor-tier feed.
    if (!_connected) connectSimulated();
  }

  @override
  void stop() {
    _sim?.removeListener(_onSim);
    _sim?.stop();
  }

  @override
  void dispose() {
    stop();
    _sim?.dispose();
    _sim = null;
    super.dispose();
  }
}
