import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'flight_data.dart';
import 'flight_state.dart';
import 'flight_store.dart';
import 'recording_settings.dart';

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

  /// Serializes the sample (its time plus the [FlightData] snapshot).
  ///
  /// The per-point field set honors [RecordingSettings.detail]: the full
  /// snapshot by default, or the compact XCTrack/IGC-style field set when the
  /// user selected [RecordingDetail.xctrack].
  Map<String, dynamic> toJson() => {
        't': time.toIso8601String(),
        'd': data.toJson(compact: RecordingSettings.instance.compactSamples),
      };

  /// Inverse of [toJson]. Returns null when the timestamp is missing/invalid.
  static FlightSample? fromJson(Map<String, dynamic> json) {
    final t = DateTime.tryParse(json['t'] as String? ?? '');
    if (t == null) return null;
    final d = json['d'];
    final data = d is Map<String, dynamic>
        ? FlightData.fromJson(d)
        : FlightData.empty;
    return FlightSample(time: t, data: data);
  }
}

/// A completed or in-progress flight track: the ordered samples plus rolling
/// statistics that are updated incrementally (O(1) per sample) rather than
/// recomputed over the whole list.
class FlightTrack {
  FlightTrack({required this.startTime});

  /// Restores a completed track from a persisted summary. Per-sample data
  /// (the [samples] list) is intentionally not persisted — only the summary
  /// statistics that the Flights sheet displays.
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

  /// Whether this track still carries per-sample data (and can be replayed).
  bool get hasSamples => samples.isNotEmpty;

  /// Drops the per-sample data while preserving the summary statistics
  /// (distance, altitude/vario extremes and point count). After this the track
  /// behaves like one restored from disk: it still shows in the Flights list
  /// but can no longer be replayed. No-op if there are no samples.
  void clearSamples() {
    if (samples.isEmpty) return;
    // Freeze the current point count so [pointCount] keeps reporting it once
    // the live [samples] list is emptied.
    _persistedPointCount = samples.length;
    samples.clear();
  }

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
  /// by the persistent flight store so completed flights survive an app
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

  /// Serializes the full track — summary statistics *and* every per-sample
  /// snapshot — so a completed flight can be replayed after an app restart.
  /// The [samples] array is omitted when empty (e.g. a track whose samples
  /// were deleted), in which case [fromJson] restores a summary-only track.
  Map<String, dynamic> toJson() {
    final map = toSummaryJson();
    if (samples.isNotEmpty) {
      map['samples'] = samples.map((s) => s.toJson()).toList();
    }
    return map;
  }

  /// Inverse of [toJson]. Restores the full track when a `samples` array is
  /// present (statistics are re-derived from the samples), otherwise falls
  /// back to a summary-only track via [fromSummaryJson]. Returns null on a
  /// malformed payload.
  static FlightTrack? fromJson(Map<String, dynamic> json) {
    final samplesJson = json['samples'];
    if (samplesJson is! List || samplesJson.isEmpty) {
      // No per-sample data persisted — restore summary only.
      return fromSummaryJson(json);
    }

    final start = DateTime.tryParse(json['startTime'] as String? ?? '');
    if (start == null) return null;

    final track = FlightTrack(startTime: start);
    for (final s in samplesJson) {
      if (s is Map<String, dynamic>) {
        final sample = FlightSample.fromJson(s);
        // Re-fold through [add] so distance/altitude/vario stats are rebuilt
        // exactly as they were during recording.
        if (sample != null) track.add(sample);
      }
    }

    // If, after parsing, we somehow have no usable samples, degrade to the
    // persisted summary rather than returning an empty track.
    if (track.samples.isEmpty) return fromSummaryJson(json);

    track.endTime = DateTime.tryParse(json['endTime'] as String? ?? '') ??
        track.samples.last.time;
    return track;
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
  FlightDataView? _source;
  bool _bound = false;

  FlightTrack? _current;
  bool _wasFlying = false;

  FlightSample? _lastStored;
  DateTime? _movingSince;
  DateTime? _stoppedSince;

  /// The most recently completed track (available after landing/stop).
  FlightTrack? _lastCompleted;
  FlightTrack? get lastCompletedTrack => _lastCompleted;

  /// All completed flight records, newest first. Backs the Flights screen.
  final List<FlightTrack> _tracks = [];
  List<FlightTrack> get tracks => List.unmodifiable(_tracks);

  /// Removes a completed track from the log.
  void deleteTrack(FlightTrack track) {
    if (_tracks.remove(track)) {
      if (identical(_lastCompleted, track)) {
        _lastCompleted = _tracks.isNotEmpty ? _tracks.first : null;
      }
      FlightStore.instance.save(_tracks);
      notifyListeners();
    }
  }

  /// Drops the per-sample data of a logged track while keeping the flight in
  /// the log (its summary statistics are preserved). The flight can no longer
  /// be replayed afterwards. No-op if the track isn't logged or has no samples.
  void deleteTrackSamples(FlightTrack track) {
    if (!_tracks.contains(track)) return;
    if (!track.hasSamples) return;
    track.clearSamples();
    // Samples are persisted, so re-save to make the deletion durable.
    FlightStore.instance.save(_tracks);
    notifyListeners();
  }

  /// Clears the entire flight log.
  void clearTracks() {
    if (_tracks.isEmpty) return;
    _tracks.clear();
    _lastCompleted = null;
    FlightStore.instance.save(_tracks);
    notifyListeners();
  }

  /// Merges externally-sourced [tracks] (e.g. imported from a `.pbflights`
  /// bundle) into the log, then re-sorts newest-first, persists and notifies.
  /// Callers are responsible for duplicate filtering.
  void importTracks(List<FlightTrack> tracks) {
    if (tracks.isEmpty) return;
    _tracks.addAll(tracks);
    _tracks.sort((a, b) => b.startTime.compareTo(a.startTime));
    _lastCompleted = _tracks.isNotEmpty ? _tracks.first : null;
    FlightStore.instance.save(_tracks);
    notifyListeners();
  }

  /// DEBUG ONLY — inserts a synthetic completed flight with a full, randomized
  /// per-sample track (real [FlightSample]s carrying GPS position, altitude and
  /// vertical speed) so the Flights screen *and* the replay screen can both be
  /// exercised without a real flight. Statistics are derived from the samples
  /// by [FlightTrack.add], exactly like a genuine recording.
  /// No-op in release/profile builds.
  void addRandomDebugTrack() {
    if (!kDebugMode) return;
    final rnd = math.Random();

    // Random start within the last ~30 days and a random duration.
    final now = DateTime.now();
    final start = now.subtract(Duration(
      days: rnd.nextInt(30),
      hours: rnd.nextInt(24),
      minutes: rnd.nextInt(60),
    ));
    final durationMin = 5 + rnd.nextInt(55); // 5 .. 60 min
    final sampleCount = math.max(2, durationMin * 6); // ~1 sample / 10 s

    final track = FlightTrack(startTime: start);

    // Random launch point (kept away from the poles for sane math) and a
    // random initial heading; we then do a random-walk flight path.
    var lat = -50.0 + rnd.nextDouble() * 100.0; // -50 .. 50
    var lng = -180.0 + rnd.nextDouble() * 360.0;
    var heading = rnd.nextDouble() * 360.0; // degrees
    var altitude = 300.0 + rnd.nextDouble() * 1500.0; // launch altitude (m)

    // Meters-per-degree conversions at this latitude for the step math.
    const double mPerDegLat = 111320.0;
    final double mPerDegLng =
        mPerDegLat * math.cos(lat * math.pi / 180.0).abs().clamp(1e-6, 1.0);

    final spanMs = durationMin * 60 * 1000;
    final dtMs = spanMs ~/ (sampleCount - 1); // ms between samples

    for (var i = 0; i < sampleCount; i++) {
      final t = start.add(Duration(milliseconds: dtMs * i));

      // Smooth-ish random walk: nudge heading and vertical speed each step.
      heading = (heading + (rnd.nextDouble() - 0.5) * 40.0) % 360.0;
      final groundSpeedKph = 25.0 + rnd.nextDouble() * 20.0; // 25 .. 45 km/h
      final vSpeed = (rnd.nextDouble() - 0.45) * 4.0; // ~ -1.8 .. +2.2 m/s

      // Integrate altitude over the step, clamped to a plausible band.
      altitude = (altitude + vSpeed * (dtMs / 1000.0)).clamp(0.0, 4000.0);

      // Advance position along the heading by (speed × dt).
      final stepM = (groundSpeedKph / 3.6) * (dtMs / 1000.0);
      final rad = heading * math.pi / 180.0;
      lat += (stepM * math.cos(rad)) / mPerDegLat;
      lng += (stepM * math.sin(rad)) / mPerDegLng;

      track.add(FlightSample(
        time: t,
        data: FlightData(
          verticalSpeed: vSpeed,
          groundSpeed: groundSpeedKph,
          altitude: altitude,
          baroAltitude: altitude,
          gpsAltitude: altitude,
          latitude: lat,
          longitude: lng,
          heading: heading,
          gpsAccuracy: 3.0 + rnd.nextDouble() * 5.0,
          satellites: 6 + rnd.nextInt(8),
          hasFix: true,
          timestamp: t,
        ),
      ));
    }
    track.endTime = start.add(Duration(milliseconds: spanMs));

    // Keep the log newest-first (matches _finishRecording / loadPersisted).
    _tracks.insert(0, track);
    _tracks.sort((a, b) => b.startTime.compareTo(a.startTime));
    _lastCompleted = _tracks.first;
    FlightStore.instance.save(_tracks);
    notifyListeners();
  }

  /// Loads previously-persisted flight tracks from disk (best-effort).
  /// Idempotent — calling more than once merges nothing; the on-disk list
  /// replaces the in-memory one.
  Future<void> loadPersisted() async {
    final loaded = await FlightStore.instance.load();
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

  /// Binds to the shared flight state and a data view. Idempotent.
  ///
  /// [source] is normally the data-transform layer so recorded samples use the
  /// same derived values (e.g. averaged vertical speed) the controls display.
  void bind(FlightDataView source, {FlightState? flightState}) {
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
      // Log every finished flight so the pilot can see it in the Flights
      // sheet — even if no samples were captured (e.g. no sensor / no GPS
      // fix). The summary still has meaningful start/end times.
      _tracks.insert(0, t);
      FlightStore.instance.save(_tracks);
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
  ///
  /// Two modes are supported (see [RecordingSettings.intervalMode]):
  ///  * [RecordingIntervalMode.smart] (default): store at most once per second
  ///    AND only when the aircraft moved ≥ [minDistanceM] horizontally or the
  ///    altitude changed ≥ [minAltitudeDeltaM]. Skips redundant points while
  ///    stationary.
  ///  * [RecordingIntervalMode.fixed1s]: store one point every second
  ///    regardless of movement (fixed 1 Hz).
  bool _shouldStore(FlightData data, DateTime now) {
    final last = _lastStored;
    if (last == null) return true;
    if (now.difference(last.time) < minInterval) return false;

    // Fixed 1 s mode: the 1-second gate above is the only condition.
    if (RecordingSettings.instance.intervalMode ==
        RecordingIntervalMode.fixed1s) {
      return true;
    }

    // Smart mode: also require a minimum movement or altitude change so we
    // don't pile up redundant points while stationary.
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
