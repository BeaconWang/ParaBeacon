import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'flight_data.dart';
import 'flight_data_source.dart';
import 'flight_state.dart';
import 'tracklog_store.dart';

/// One recorded sample of the full flight-data snapshot at a moment in time.
///
/// This captures the whole [FlightData] (position, altitudes, vario, speed,
/// heading, plus maintenance fields) so a recorded track can be replayed or
/// exported without losing information.
@immutable
class FlightSample {
  const FlightSample({required this.time, required this.data});

  final DateTime time;
  final FlightData data;
}

/// A completed or in-progress flight track: the ordered samples plus rolling
/// statistics that are updated incrementally (O(1) per sample) rather than
/// recomputed over the whole list.
class FlightTrack {
  FlightTrack({required this.startTime});

  /// Restores a completed track from a persisted summary. Per-sample data
  /// (the [samples] list) is intentionally not persisted — only the summary
  /// statistics that the Tracklogs sheet displays.
  FlightTrack._fromSummary({
    required this.startTime,
    required this.endTime,
    required double distanceM,
    required double maxAltitude,
    required double minAltitude,
    required double maxClimb,
    required double maxSink,
    required int pointCount,
  }) {
    _distanceM = distanceM;
    _maxAltitude = maxAltitude;
    _minAltitude = minAltitude;
    _maxClimb = maxClimb;
    _maxSink = maxSink;
    _persistedPointCount = pointCount;
  }

  final DateTime startTime;
  DateTime? endTime;

  /// All recorded samples (full snapshots), in chronological order. Empty for
  /// tracks restored from a persisted summary.
  final List<FlightSample> samples = [];

  // ── Incrementally-maintained statistics ────────────────────────────────────
  double _distanceM = 0.0;
  double _maxAltitude = double.negativeInfinity;
  double _minAltitude = double.infinity;
  double _maxClimb = 0.0;
  double _maxSink = 0.0;

  /// Point count carried across a persistence round-trip when [samples] is
  /// empty (i.e. the track was restored from disk).
  int? _persistedPointCount;

  /// Cumulative ground track distance in meters.
  double get distanceM => _distanceM;

  /// Highest / lowest altitude seen (meters). Zero before any sample.
  double get maxAltitude =>
      _maxAltitude == double.negativeInfinity ? 0.0 : _maxAltitude;
  double get minAltitude =>
      _minAltitude == double.infinity ? 0.0 : _minAltitude;

  /// Strongest climb (m/s, >= 0) and sink (m/s, <= 0) seen.
  double get maxClimb => _maxClimb;
  double get maxSink => _maxSink;

  int get pointCount => _persistedPointCount ?? samples.length;

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  /// Appends a sample and folds it into the running statistics.
  void add(FlightSample s) {
    final prev = samples.isNotEmpty ? samples.last : null;
    samples.add(s);

    final alt = s.data.altitude;
    if (alt > _maxAltitude) _maxAltitude = alt;
    if (alt < _minAltitude) _minAltitude = alt;

    final v = s.data.verticalSpeed;
    if (v > _maxClimb) _maxClimb = v;
    if (v < _maxSink) _maxSink = v;

    if (prev != null && s.data.hasFix && prev.data.hasFix) {
      _distanceM += _haversineM(
        prev.data.latitude,
        prev.data.longitude,
        s.data.latitude,
        s.data.longitude,
      );
    }
  }

  /// Serializes the track's summary (no per-sample data) to a JSON map. Used
  /// by the persistent tracklog store so completed flights survive an app
  /// restart.
  Map<String, dynamic> toSummaryJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'distanceM': _distanceM,
      'maxAltitude':
          _maxAltitude == double.negativeInfinity ? 0.0 : _maxAltitude,
      'minAltitude': _minAltitude == double.infinity ? 0.0 : _minAltitude,
      'maxClimb': _maxClimb,
      'maxSink': _maxSink,
      'pointCount': pointCount,
    };
  }

  /// Inverse of [toSummaryJson]. Returns null if the payload is malformed
  /// (missing/unparseable start/end times).
  static FlightTrack? fromSummaryJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startTime'] as String? ?? '');
    if (start == null) return null;
    final end = DateTime.tryParse(json['endTime'] as String? ?? '');
    if (end == null) return null;
    return FlightTrack._fromSummary(
      startTime: start,
      endTime: end,
      distanceM: (json['distanceM'] as num?)?.toDouble() ?? 0.0,
      maxAltitude: (json['maxAltitude'] as num?)?.toDouble() ?? 0.0,
      minAltitude: (json['minAltitude'] as num?)?.toDouble() ?? 0.0,
      maxClimb: (json['maxClimb'] as num?)?.toDouble() ?? 0.0,
      maxSink: (json['maxSink'] as num?)?.toDouble() ?? 0.0,
      pointCount: (json['pointCount'] as num?)?.toInt() ?? 0,
    );
  }

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * (math.pi / 180.0);
}

/// Continuously records the full flight-data feed while a flight is in progress.
///
/// Design (an optimized consolidation of the reference project's separate
/// track-recording / flight-clock / live-buffer services):
///
///  * **Single source of truth** — it observes the shared [FlightState] for
///    start/stop instead of maintaining its own recording flag, so the Flight
///    button, auto-detection and recording never disagree.
///  * **Records the whole [FlightData]** (not just GPS) so altitude/pressure/
///    temperature/vario/etc. are all preserved.
///  * **Throttled sampling** — a new sample is stored only when at least
///    [minInterval] has elapsed *and* the aircraft moved at least
///    [minDistanceM] (or altitude changed enough), which avoids piling up
///    redundant points while stationary.
///  * **Incremental statistics** — distance/altitude/vario extremes are folded
///    in per sample (O(1)) rather than recomputed over the whole track.
///  * **Auto take-off / landing** — when [FlightState.autoDetect] is on, ground
///    speed crossing thresholds for a debounce window auto-starts/stops the
///    flight (which in turn starts/stops recording).
class FlightRecorder extends ChangeNotifier {
  FlightRecorder._();
  static final FlightRecorder instance = FlightRecorder._();

  // ── Tunables ────────────────────────────────────────────────────────────
  /// Minimum time between stored samples.
  static const Duration minInterval = Duration(seconds: 1);

  /// Minimum horizontal movement (m) required to store a new sample when the
  /// [minInterval] gate would otherwise pass. Also stored if altitude changed
  /// by [minAltitudeDeltaM].
  static const double minDistanceM = 3.0;
  static const double minAltitudeDeltaM = 1.0;

  /// Auto-detection thresholds (ground speed in km/h) and debounce window.
  static const double _takeoffSpeedKph = 12.0;
  static const double _landingSpeedKph = 5.0;
  static const Duration _confirmWindow = Duration(seconds: 8);

  FlightState? _flightState;
  FlightDataSource? _source;
  bool _bound = false;

  FlightTrack? _current;
  bool _wasFlying = false;

  FlightSample? _lastStored;
  DateTime? _movingSince;
  DateTime? _stoppedSince;

  /// The most recently completed track (available after landing/stop).
  FlightTrack? _lastCompleted;
  FlightTrack? get lastCompletedTrack => _lastCompleted;

  /// All completed flight records, newest first. Backs the Tracklogs screen.
  final List<FlightTrack> _tracks = [];
  List<FlightTrack> get tracks => List.unmodifiable(_tracks);

  /// Removes a completed track from the log.
  void deleteTrack(FlightTrack track) {
    if (_tracks.remove(track)) {
      if (identical(_lastCompleted, track)) {
        _lastCompleted = _tracks.isNotEmpty ? _tracks.first : null;
      }
      TrackLogStore.instance.save(_tracks);
      notifyListeners();
    }
  }

  /// Clears the entire flight log.
  void clearTracks() {
    if (_tracks.isEmpty) return;
    _tracks.clear();
    _lastCompleted = null;
    TrackLogStore.instance.save(_tracks);
    notifyListeners();
  }

  /// Loads previously-persisted flight tracks from disk (best-effort).
  /// Idempotent — calling more than once merges nothing; the on-disk list
  /// replaces the in-memory one.
  Future<void> loadPersisted() async {
    final loaded = await TrackLogStore.instance.load();
    if (loaded.isEmpty) return;
    _tracks
      ..clear()
      ..addAll(loaded);
    _lastCompleted = _tracks.first;
    notifyListeners();
  }

  /// The in-progress track, or null when not recording.
  FlightTrack? get currentTrack => _current;

  bool get isRecording => _current != null;
  int get pointCount => _current?.pointCount ?? 0;

  /// Binds to the shared flight state and a data source. Idempotent.
  void bind(FlightDataSource source, {FlightState? flightState}) {
    final fs = flightState ?? FlightState.instance;
    if (_bound && _source == source && _flightState == fs) return;
    _unbind();
    _source = source;
    _flightState = fs;
    _wasFlying = fs.isFlying;
    source.addListener(_onData);
    fs.addListener(_onFlightStateChanged);
    _bound = true;
    if (fs.isFlying) _beginRecording();
  }

  void _unbind() {
    _source?.removeListener(_onData);
    _flightState?.removeListener(_onFlightStateChanged);
    _bound = false;
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  void _onFlightStateChanged() {
    final flying = _flightState?.isFlying ?? false;
    if (flying == _wasFlying) return;
    _wasFlying = flying;
    if (flying) {
      _beginRecording();
    } else {
      _finishRecording();
    }
    notifyListeners();
  }

  void _beginRecording() {
    _current = FlightTrack(startTime: DateTime.now());
    _lastStored = null;
  }

  void _finishRecording() {
    final t = _current;
    if (t != null) {
      t.endTime = DateTime.now();
      _lastCompleted = t;
      // Log every finished flight so the pilot can see it in the Tracklogs
      // sheet — even if no samples were captured (e.g. no sensor / no GPS
      // fix). The summary still has meaningful start/end times.
      _tracks.insert(0, t);
      TrackLogStore.instance.save(_tracks);
    }
    _current = null;
    _lastStored = null;
    _movingSince = null;
    _stoppedSince = null;
  }

  void _onData() {
    final source = _source;
    final fs = _flightState;
    if (source == null || fs == null) return;
    final data = source.data;
    final now = data.timestamp ?? DateTime.now();

    // Auto take-off / landing detection (only when enabled).
    if (fs.autoDetect) _runAutoDetect(fs, data, now);

    // Record only while a flight is in progress.
    final track = _current;
    if (track == null) return;
    if (!_shouldStore(data, now)) return;

    final sample = FlightSample(time: now, data: data);
    track.add(sample);
    _lastStored = sample;
    notifyListeners();
  }

  /// Time + distance/altitude gate to avoid redundant points.
  bool _shouldStore(FlightData data, DateTime now) {
    final last = _lastStored;
    if (last == null) return true;
    if (now.difference(last.time) < minInterval) return false;
    if (data.hasFix && last.data.hasFix) {
      final moved = FlightTrack._haversineM(
        last.data.latitude,
        last.data.longitude,
        data.latitude,
        data.longitude,
      );
      final climbed = (data.altitude - last.data.altitude).abs();
      if (moved < minDistanceM && climbed < minAltitudeDeltaM) return false;
    }
    return true;
  }

  void _runAutoDetect(FlightState fs, FlightData data, DateTime now) {
    final speed = data.groundSpeed; // km/h
    if (!fs.isFlying) {
      if (speed > _takeoffSpeedKph) {
        _movingSince ??= now;
        if (now.difference(_movingSince!) >= _confirmWindow) {
          fs.start(); // triggers _beginRecording via state listener
          _movingSince = null;
        }
      } else {
        _movingSince = null;
      }
    } else {
      if (speed < _landingSpeedKph) {
        _stoppedSince ??= now;
        if (now.difference(_stoppedSince!) >= _confirmWindow) {
          fs.stop(); // triggers _finishRecording via state listener
          _stoppedSince = null;
        }
      } else {
        _stoppedSince = null;
      }
    }
  }
}
