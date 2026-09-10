import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'debug_settings.dart';
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
/// The effective *raw* value of any field is taken from the highest-priority
/// tier that currently provides it:
///
///   1. [debugOverride]   — manual debug/bench values (ALWAYS wins).
///   2. [bluetoothSensor] — the real (or simulated) BLE sensor feed.
///   3. [other]           — any other/fallback feed (e.g. defaults, GPS-derived).
///
/// i.e. **Debug > Bluetooth sensor > Other**.
///
/// This ordering describes the *raw data layer*; the downstream data-transform
/// layer then derives values (e.g. an averaged vertical speed) from whatever
/// raw value won here.
enum FlightDataPriority { debugOverride, bluetoothSensor, other }

/// The **raw data layer**.
///
/// Concrete implementations (bluetooth sensor, simulated, external feed, ...)
/// produce the raw feed via [update]; a debug [override] can force individual
/// fields on top of it. The exposed [data] is the *raw* per-field resolution
/// with no transforms applied — smoothing/averaging lives in the separate
/// data-transform layer that wraps this source.
///
/// RAW PRIORITY (per field, highest first):
///   [FlightDataPriority.debugOverride] > [FlightDataPriority.bluetoothSensor]
///   > [FlightDataPriority.other]
///
/// The resolution is per-field: e.g. a debug override on `verticalSpeed` wins
/// for that field even while the bluetooth sensor keeps streaming all other
/// fields at full rate.
abstract class RawFlightDataSource extends ChangeNotifier
    implements FlightDataView {
  FlightData _rawData = FlightData.empty;
  FlightDataOverride _override = FlightDataOverride.none;

  /// The latest *raw* flight-data snapshot with the priority order applied
  /// (debug override > bluetooth sensor > other). No transforms are applied
  /// here; the data-transform layer derives smoothed values from this.
  @override
  FlightData get data => _override.applyTo(_rawData);

  /// The raw snapshot as produced by the sensor feed, ignoring debug overrides
  /// (i.e. the [FlightDataPriority.bluetoothSensor] / [FlightDataPriority.other]
  /// tiers only).
  FlightData get rawData => _rawData;

  /// The currently installed debug override (highest priority tier).
  FlightDataOverride get activeOverride => _override;

  /// Which priority tier currently supplies the effective raw vertical speed:
  /// [FlightDataPriority.debugOverride] when a debug vertical-speed override is
  /// active, [FlightDataPriority.bluetoothSensor] when a sensor/simulator feed
  /// is providing it, otherwise [FlightDataPriority.other].
  FlightDataPriority get verticalSpeedSource {
    if (_override.verticalSpeed != null) {
      return FlightDataPriority.debugOverride;
    }
    if (_hasBluetoothFeed) return FlightDataPriority.bluetoothSensor;
    return FlightDataPriority.other;
  }

  /// Whether a bluetooth-sensor-tier feed is currently supplying values.
  /// Subclasses that represent a BLE feed override this to reflect their live
  /// connection state; the default is `false` (i.e. values come from "other").
  bool get _hasBluetoothFeed => false;

  /// Installs a new debug [override]. Overridden fields take precedence over
  /// the raw sensor data. Notifies listeners so downstream layers rebuild
  /// immediately.
  void setOverride(FlightDataOverride override) {
    _override = override;
    notifyListeners();
  }

  /// Removes all debug overrides, reverting to the raw sensor data.
  void clearOverride() => setOverride(FlightDataOverride.none);

  /// Replaces the current raw (bluetooth-sensor / other tier) snapshot and
  /// notifies listeners. Debug overrides, if any, still win over these values.
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
class SimulatedFlightDataSource extends RawFlightDataSource {
  final Duration tickInterval;
  final math.Random _rand = math.Random();

  /// Debug preferences that decide where the synthetic track starts (Europe by
  /// default, or a location in China when [DebugSettings.fakeChinaLocation]).
  final DebugSettings _debug;

  Timer? _timer;

  // Internal simulation targets that values ease toward.
  double _vsTarget = 0.0;
  double _headingTarget = 90.0;
  double _windDirTarget = 270.0;

  // Default (European) start point — Lausanne, Switzerland.
  static const double _defaultLat = 46.5197;
  static const double _defaultLon = 6.6323;

  // Fake China start point — near Chengdu, Sichuan. Used when the debug
  // "fake China location" toggle is on so the synthetic flight sits over
  // Chinese territory (and aligns with the AMap/GCJ-02 tile sources).
  static const double _chinaLat = 30.6570;
  static const double _chinaLon = 104.0657;

  double _lat = _defaultLat;
  double _lon = _defaultLon;

  SimulatedFlightDataSource({
    this.tickInterval = const Duration(milliseconds: 100),
    DebugSettings? debugSettings,
  }) : _debug = debugSettings ?? DebugSettings.instance {
    _applyStartLocation();
  }

  /// Positions the initial synthetic coordinates according to the current
  /// [DebugSettings.fakeChinaLocation] preference.
  void _applyStartLocation() {
    if (_debug.fakeChinaLocation) {
      _lat = _chinaLat;
      _lon = _chinaLon;
    } else {
      _lat = _defaultLat;
      _lon = _defaultLon;
    }
  }

  @override
  void start() {
    // Re-apply the start location each time the simulator (re)starts so
    // toggling the China switch takes effect on the next run.
    _applyStartLocation();
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

    // Derive plausible maintenance data from the simulated altitude:
    //   * pressure via the International Standard Atmosphere,
    //   * temperature via a 6.5 °C/km lapse rate from 15 °C at sea level,
    //   * a slowly-draining battery and a gently varying heart rate.
    const seaLevelHpa = 1013.25;
    final pressure = seaLevelHpa * math.pow(1.0 - altitude / 44330.0, 5.255);
    final temperature = 15.0 - altitude * 0.0065;
    final now = DateTime.now();
    final battery = (100 - (now.millisecondsSinceEpoch ~/ 60000) % 100).clamp(1, 100);
    final heartRate = 70 + (math.sin(now.millisecondsSinceEpoch / 3000.0) * 15).round();

    update(prev.copyWith(
      verticalSpeed: vs,
      altitude: altitude,
      baroAltitude: altitude,
      gpsAltitude: altitude + 3.0, // GPS altitude typically differs from baro
      groundSpeed: groundSpeed,
      heading: heading,
      latitude: _lat,
      longitude: _lon,
      windSpeed: 12.0,
      windDirection: windDir,
      pressure: pressure.toDouble(),
      temperature: temperature,
      gpsAccuracy: 4.0,
      satellites: 12,
      battery: battery,
      heartRate: heartRate,
      hasFix: true,
      timestamp: now,
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
class BluetoothSensorFlightDataSource extends RawFlightDataSource {
  /// Optional simulator used before a real BLE device is connected.
  SimulatedFlightDataSource? _sim;

  bool _connected = false;

  /// Whether a *real* (physical) BLE sensor is currently feeding data. When
  /// true, the built-in simulator is suppressed so it never competes with or
  /// overwrites the live sensor readings.
  bool _realSensorActive = false;

  /// Debug preferences that gate the development simulator. The simulator only
  /// runs as a fallback feed while [DebugSettings.simulatorEnabled] is true.
  final DebugSettings _debug;

  BluetoothSensorFlightDataSource({DebugSettings? debugSettings})
      : _debug = debugSettings ?? DebugSettings.instance {
    // React to the simulator toggle being flipped at runtime.
    _lastFakeChinaLocation = _debug.fakeChinaLocation;
    _debug.addListener(_onDebugSettingsChanged);
  }

  /// Last-seen value of [DebugSettings.fakeChinaLocation] so we can detect a
  /// change and restart the simulator at the new start location.
  bool _lastFakeChinaLocation = false;

  /// A bluetooth-tier feed is considered active while a sensor (real BLE or the
  /// development simulator) is connected and streaming; this makes the raw
  /// vertical speed resolve to [FlightDataPriority.bluetoothSensor] rather than
  /// [FlightDataPriority.other].
  @override
  bool get _hasBluetoothFeed => _connected;

  void _onDebugSettingsChanged() {
    if (_realSensorActive) {
      _lastFakeChinaLocation = _debug.fakeChinaLocation;
      return;
    }
    // If the "fake China location" toggle changed while the simulator is
    // running, recreate the simulator so it starts from the new location.
    final chinaChanged = _debug.fakeChinaLocation != _lastFakeChinaLocation;
    _lastFakeChinaLocation = _debug.fakeChinaLocation;
    if (chinaChanged && _debug.simulatorEnabled) {
      _sim?.removeListener(_onSim);
      _sim?.stop();
      _sim?.dispose();
      _sim = null;
      _connected = false;
      connectSimulated();
      return;
    }
    if (_debug.simulatorEnabled) {
      // Turned on: start feeding simulated data if nothing else is.
      connectSimulated();
    } else {
      // Turned off: stop the simulator and freeze the last values.
      _sim?.removeListener(_onSim);
      _sim?.stop();
      _connected = false;
      notifyListeners();
    }
  }

  /// Whether a sensor (real or simulated) is currently feeding data.
  bool get isConnected => _connected;

  /// Whether the live feed is coming from a real BLE sensor (as opposed to the
  /// development simulator).
  bool get isRealSensorActive => _realSensorActive;

  /// Marks that a real BLE sensor is now the active source. This pauses the
  /// development simulator (if running) so the live sensor's vertical speed is
  /// the single source of truth for the bluetooth-sensor tier.
  void beginRealSensor() {
    _realSensorActive = true;
    // Pause the simulator so it stops overwriting real readings.
    _sim?.removeListener(_onSim);
    _sim?.stop();
    _connected = true;
    notifyListeners();
  }

  /// Marks that the real BLE sensor is no longer active (disconnected). By
  /// default the development simulator resumes so the app keeps producing a
  /// bluetooth-sensor-tier feed; pass [resumeSimulator] = false to leave the
  /// last values frozen instead.
  ///
  /// The simulator only actually resumes when [DebugSettings.simulatorEnabled]
  /// is true; otherwise the feed is left frozen regardless of [resumeSimulator].
  void endRealSensor({bool resumeSimulator = true}) {
    _realSensorActive = false;
    if (resumeSimulator && _debug.simulatorEnabled) {
      connectSimulated();
    } else {
      _connected = false;
    }
    notifyListeners();
  }

  /// Feeds a single vertical-speed reading from the BLE sensor (m/s), keeping
  /// all other fields as they were. This is the field the vario audio consumes.
  ///
  /// Receiving a real reading implicitly marks the real sensor as active,
  /// suppressing the simulator so the sensor's value always wins.
  void ingestVerticalSpeed(double verticalSpeed) {
    if (verticalSpeed.isNaN || verticalSpeed.isInfinite) return;
    if (!_realSensorActive) beginRealSensor();
    update(rawData.copyWith(verticalSpeed: verticalSpeed));
    _connected = true;
  }

  /// Feeds a full sensor snapshot from the BLE device.
  ///
  /// Receiving a real snapshot implicitly marks the real sensor as active,
  /// suppressing the simulator so the sensor's values always win.
  void ingestSnapshot(FlightData snapshot) {
    if (!_realSensorActive) beginRealSensor();
    update(snapshot);
    _connected = true;
  }

  /// Feeds a device-GPS reading into the *other* (lowest) raw tier.
  ///
  /// Unlike [ingestSnapshot] this does **not** flip the real-sensor flag and
  /// does **not** mark the source as connected — the GPS is not a BLE sensor,
  /// it just contributes position/heading/ground-speed/GPS-altitude/fix state
  /// that no BLE vario reports. Fields the BLE sensor owns (verticalSpeed,
  /// baroAltitude, pressure, temperature, battery, heartRate) are deliberately
  /// left untouched so BLE > GPS on those fields.
  ///
  /// The `altitude` convenience field is only updated from GPS when we have no
  /// barometric altitude — preserving the "prefer baro" rule in [FlightData].
  ///
  /// When the built-in flight-data simulator is currently running (see
  /// [connectSimulated]), GPS is suppressed so the simulated position isn't
  /// fought over — matching the map's `sim > gps > flight-data` priority.
  void ingestGpsSnapshot({
    required double latitude,
    required double longitude,
    required double heading,
    required double groundSpeedKmh,
    double? gpsAltitude,
    double? gpsAccuracy,
    int? satellites,
    DateTime? timestamp,
  }) {
    // Simulator wins on position while it's on: otherwise the fake flight
    // would jitter between the sim's synthetic track and the real device GPS.
    if (!_realSensorActive && _sim != null && _debug.simulatorEnabled) return;

    final base = rawData;
    // Only touch fields GPS legitimately provides; leave BLE-owned fields
    // (verticalSpeed / baroAltitude / pressure / temperature / battery / HR)
    // exactly as they were.
    final next = base.copyWith(
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      groundSpeed: groundSpeedKmh,
      gpsAltitude: gpsAltitude,
      // Prefer barometric altitude when we have it; only promote GPS altitude
      // into the effective `altitude` field when no baro reading exists.
      altitude: (base.baroAltitude == null && gpsAltitude != null)
          ? gpsAltitude
          : base.altitude,
      gpsAccuracy: gpsAccuracy,
      satellites: satellites,
      hasFix: true,
      timestamp: timestamp ?? DateTime.now(),
    );
    update(next);
  }

  /// Signals that the device GPS just lost its fix. Clears the fix flag so
  /// consumers stop trusting the last position, but keeps the last-known
  /// values (latitude/longitude/heading) intact for display.
  void reportGpsFixLost() {
    if (!rawData.hasFix) return;
    update(rawData.copyWith(hasFix: false));
  }

  /// Development helper: drive the sensor tier with the built-in simulator so
  /// the app runs without a physical device. Values still sit at the
  /// bluetooth-sensor priority, so debug overrides continue to win.
  ///
  /// No-op while a real sensor is active — the live feed always takes priority.
  /// Also a no-op while [DebugSettings.simulatorEnabled] is false, so the app
  /// never fabricates flight data unless the debug simulator is turned on.
  void connectSimulated({
    Duration tickInterval = const Duration(milliseconds: 100),
  }) {
    if (_realSensorActive) return;
    if (!_debug.simulatorEnabled) return;
    _sim ??= SimulatedFlightDataSource(tickInterval: tickInterval);
    // Mirror the simulator's raw output into this source's raw tier.
    _sim!.removeListener(_onSim); // avoid double-subscription
    _sim!.addListener(_onSim);
    _sim!.start();
    _connected = true;
  }

  void _onSim() {
    // Ignore simulator ticks once a real sensor has taken over.
    if (_realSensorActive) return;
    final sim = _sim;
    if (sim != null) update(sim.rawData);
  }

  @override
  void start() {
    // If a real device is not (yet) feeding data, fall back to the simulator so
    // there is always a bluetooth-sensor-tier feed — but only when the debug
    // simulator is enabled (connectSimulated is a no-op otherwise).
    if (!_realSensorActive && !_connected) connectSimulated();
  }

  @override
  void stop() {
    _sim?.removeListener(_onSim);
    _sim?.stop();
  }

  @override
  void dispose() {
    _debug.removeListener(_onDebugSettingsChanged);
    stop();
    _sim?.dispose();
    _sim = null;
    super.dispose();
  }
}
