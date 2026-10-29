import 'package:flutter/foundation.dart';

import 'aircraft_settings.dart';
import 'flight_data.dart';
import 'raw_flight_data_source.dart';
import 'wind_estimator.dart';

/// The **data-transform layer**.
///
/// Pipeline:
/// ```
/// [control] <- [FlightDataTransformer] <- [RawFlightDataSource] <- [raw data]
/// ```
///
/// This layer sits between the *raw data layer* ([RawFlightDataSource], which
/// resolves each field by priority: Debug > Bluetooth > Other) and the
/// controls. It listens to the raw source and derives display-ready values,
/// re-emitting whenever new raw data arrives.
///
/// Current transform:
///   * **Vertical speed** — replaced with the *time-weighted* average of the
///     raw vertical speed over the trailing [verticalSpeedWindow] (default 2s).
///     Each raw sample is weighted by how long it stays in effect (zero-order
///     hold: it holds until the next sample arrives, and the newest sample
///     extends to "now"), so uneven sampling rates do not bias the result. The
///     raw input is sampled on every update and the output is recomputed from
///     those raw samples (never fed back its own averaged output).
///
/// All other fields are passed through unchanged. Controls read the transformed
/// snapshot via [data]; debug controls that need to write overrides reach the
/// underlying raw layer through [rawSource].
class FlightDataTransformer extends ChangeNotifier implements FlightDataView {
  /// The underlying raw data layer this transformer derives from.
  final RawFlightDataSource rawSource;

  /// Trailing window over which the raw vertical speed is averaged.
  Duration _verticalSpeedWindow;

  Duration get verticalSpeedWindow => _verticalSpeedWindow;

  /// Timestamped *raw input* vertical-speed samples within
  /// [verticalSpeedWindow], oldest first.
  final List<_VsSample> _vsSamples = <_VsSample>[];

  /// Derives a wind estimate from fresh GPS ground-velocity fixes when the raw
  /// feed carries no sensor wind reading.
  late final WindEstimator _windEstimator;

  final AircraftSettings _aircraftSettings = AircraftSettings.instance;

  /// The latest transformed snapshot exposed to controls.
  FlightData _data = FlightData.empty;

  /// The priority tier that supplied the vertical speed on the previous update.
  /// Used to detect when the source switches (e.g. Bluetooth → debug override)
  /// so stale samples from the old source do not pollute the new average.
  FlightDataPriority? _lastVsSource;

  bool _attached = false;

  FlightDataTransformer({
    required this.rawSource,
    Duration verticalSpeedWindow = const Duration(seconds: 2),
  }) : _verticalSpeedWindow = _clampVerticalSpeedWindow(verticalSpeedWindow) {
    _windEstimator = WindEstimator(
      trimSpeedKmh: _aircraftSettings.trimSpeedKmh,
    );
    _aircraftSettings.addListener(_onAircraftSettingsChanged);
    _attach();
  }

  static Duration _clampVerticalSpeedWindow(Duration window) =>
      Duration(milliseconds: window.inMilliseconds.clamp(500, 3000));

  void setVerticalSpeedWindow(Duration window) {
    final normalized = _clampVerticalSpeedWindow(window);
    if (_verticalSpeedWindow == normalized) return;
    _verticalSpeedWindow = normalized;

    final now = DateTime.now();
    _discardExpiredSamples(now.subtract(_verticalSpeedWindow));
    _data = _data.copyWith(verticalSpeed: _timeWeightedMean(now));
    notifyListeners();
  }

  void _onAircraftSettingsChanged() {
    final trimSpeedKmh = _aircraftSettings.trimSpeedKmh;
    if (trimSpeedKmh.isFinite && trimSpeedKmh > 0.0) {
      _windEstimator.trimSpeedKmh = trimSpeedKmh;
    }
  }

  /// The latest transformed [FlightData] (raw data with derived values applied,
  /// e.g. the trailing-average vertical speed).
  @override
  FlightData get data => _data;

  void _attach() {
    if (_attached) return;
    _attached = true;
    rawSource.addListener(_onRawData);
    // Seed with whatever the raw layer already has.
    _onRawData();
  }

  /// Recomputes the transformed snapshot from the current raw data. Invoked on
  /// every raw-layer notification so the output tracks the latest input.
  void _onRawData() {
    final raw = rawSource.data;

    // Detect a change of the vertical-speed source tier (e.g. Bluetooth sensor
    // → debug override after a disconnect). When the source switches, the
    // trailing window must not blend the old source's samples into the new
    // one's average, so drop the buffered history and start fresh.
    final vsSource = rawSource.verticalSpeedSource;
    if (_lastVsSource != null && vsSource != _lastVsSource) {
      _vsSamples.clear();
    }
    _lastVsSource = vsSource;

    // Use a wall-clock "now" rather than the raw snapshot's timestamp: a frozen
    // feed (e.g. Bluetooth just disconnected) keeps reporting its last, stale
    // timestamp, which would corrupt trailing-window eviction and time weights.
    // Debug-override input in particular is a live "now" user action.
    final avgVs = _averagedVerticalSpeed(raw.verticalSpeed, DateTime.now());
    var next = raw.verticalSpeed == avgVs
        ? raw
        : raw.copyWith(verticalSpeed: avgVs);

    // Wind: prefer a real sensor reading. When the feed carries none, derive it
    // from GPS ground-velocity while circling so every control (compass, map,
    // etc.) sees a consistent, non-zero wind. Only confident estimates (enough
    // of a circle flown) are published; otherwise wind stays unknown (0).
    next = _withDerivedWind(next);

    _data = next;
    notifyListeners();
  }

  /// Returns [snapshot] with a derived wind reading applied when it has a GPS
  /// fix but no sensor-provided wind. Valid GPS course and speed samples are
  /// processed at their fix timestamps, matching XCTrack's rolling velocity
  /// circle. A sensor wind (windSpeed > 0.1) is left intact and resets the
  /// estimator so it does not blend stale pre-sensor samples.
  FlightData _withDerivedWind(FlightData snapshot) {
    if (snapshot.windSpeed > 0.1) {
      _windEstimator.reset();
      return snapshot;
    }
    if (!snapshot.hasFix) {
      _windEstimator.reset();
      return snapshot;
    }

    final est = snapshot.hasGroundSpeed && snapshot.hasHeading
        ? _windEstimator.add(
            groundSpeedMps: snapshot.groundSpeed / 3.6,
            headingDeg: snapshot.heading,
            time: snapshot.gpsTimestamp ?? snapshot.timestamp ?? DateTime.now(),
          )
        : _windEstimator.latestEstimate;
    if (est == null || !est.confident) return snapshot;
    return snapshot.copyWith(
      windSpeed: est.speedKmh,
      windDirection: est.fromDirectionDeg,
    );
  }

  /// Records the raw input [raw] at [when] and returns the *time-weighted* mean
  /// of all raw samples in the trailing [verticalSpeedWindow], evicting stale
  /// samples.
  double _averagedVerticalSpeed(double raw, DateTime when) {
    if (raw.isNaN || raw.isInfinite) {
      // Ignore bogus readings; keep the last known average.
      if (_vsSamples.isEmpty) return 0.0;
      return _timeWeightedMean(when);
    }

    _vsSamples.add(_VsSample(when, raw));

    _discardExpiredSamples(when.subtract(verticalSpeedWindow));
    return _timeWeightedMean(when);
  }

  void _discardExpiredSamples(DateTime cutoff) {
    while (_vsSamples.length > 1 && _vsSamples.first.time.isBefore(cutoff)) {
      _vsSamples.removeAt(0);
    }
  }

  /// Time-weighted (zero-order hold) mean of the buffered samples up to [now].
  ///
  /// Each sample's weight is the duration it stays in effect: the gap until the
  /// next sample, and for the newest sample the gap until [now]. Falls back to a
  /// plain value when all weights are zero (e.g. a single instantaneous sample).
  double _timeWeightedMean(DateTime now) {
    if (_vsSamples.isEmpty) return 0.0;
    if (_vsSamples.length == 1) return _vsSamples.first.value;

    var weightedSum = 0.0;
    var totalWeight = 0.0;
    final cutoff = now.subtract(verticalSpeedWindow);
    for (var i = 0; i < _vsSamples.length; i++) {
      final current = _vsSamples[i];
      final from = current.time.isBefore(cutoff) ? cutoff : current.time;
      final until = i + 1 < _vsSamples.length ? _vsSamples[i + 1].time : now;
      var dtMicros = until.difference(from).inMicroseconds;
      if (dtMicros < 0) dtMicros = 0; // guard against out-of-order timestamps
      final w = dtMicros.toDouble();
      weightedSum += current.value * w;
      totalWeight += w;
    }

    // All samples share the same instant (zero span): fall back to the newest.
    if (totalWeight <= 0.0) return _vsSamples.last.value;
    return weightedSum / totalWeight;
  }

  @override
  void dispose() {
    _aircraftSettings.removeListener(_onAircraftSettingsChanged);
    if (_attached) {
      rawSource.removeListener(_onRawData);
      _attached = false;
    }
    super.dispose();
  }
}

/// A single timestamped raw vertical-speed input used for trailing-window
/// averaging in [FlightDataTransformer].
class _VsSample {
  final DateTime time;
  final double value;
  const _VsSample(this.time, this.value);
}
