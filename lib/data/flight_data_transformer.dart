import 'package:flutter/foundation.dart';

import 'flight_data.dart';
import 'raw_flight_data_source.dart';

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
///   * **Vertical speed** — replaced with the average of the raw vertical
///     speed over the trailing [verticalSpeedWindow] (default 2s). The raw
///     input is sampled on every update and the output is recomputed from those
///     raw samples (never fed back its own averaged output).
///
/// All other fields are passed through unchanged. Controls read the transformed
/// snapshot via [data]; debug controls that need to write overrides reach the
/// underlying raw layer through [rawSource].
class FlightDataTransformer extends ChangeNotifier implements FlightDataView {
  /// The underlying raw data layer this transformer derives from.
  final RawFlightDataSource rawSource;

  /// Trailing window over which the raw vertical speed is averaged.
  final Duration verticalSpeedWindow;

  /// Timestamped *raw input* vertical-speed samples within
  /// [verticalSpeedWindow], oldest first.
  final List<_VsSample> _vsSamples = <_VsSample>[];

  /// The latest transformed snapshot exposed to controls.
  FlightData _data = FlightData.empty;

  bool _attached = false;

  FlightDataTransformer({
    required this.rawSource,
    this.verticalSpeedWindow = const Duration(seconds: 2),
  }) {
    _attach();
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
    final avgVs = _averagedVerticalSpeed(
      raw.verticalSpeed,
      raw.timestamp ?? DateTime.now(),
    );
    _data =
        raw.verticalSpeed == avgVs ? raw : raw.copyWith(verticalSpeed: avgVs);
    notifyListeners();
  }

  /// Records the raw input [raw] at [when] and returns the mean of all raw
  /// samples in the trailing [verticalSpeedWindow], evicting stale samples.
  double _averagedVerticalSpeed(double raw, DateTime when) {
    if (raw.isNaN || raw.isInfinite) {
      // Ignore bogus readings; keep the last known average.
      if (_vsSamples.isEmpty) return 0.0;
      return _mean();
    }

    _vsSamples.add(_VsSample(when, raw));

    final cutoff = when.subtract(verticalSpeedWindow);
    while (_vsSamples.length > 1 && _vsSamples.first.time.isBefore(cutoff)) {
      _vsSamples.removeAt(0);
    }
    return _mean();
  }

  double _mean() {
    if (_vsSamples.isEmpty) return 0.0;
    var sum = 0.0;
    for (final e in _vsSamples) {
      sum += e.value;
    }
    return sum / _vsSamples.length;
  }

  @override
  void dispose() {
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
