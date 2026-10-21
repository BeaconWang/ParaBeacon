import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'aircraft_settings.dart';
import 'auto_flight_detector.dart';
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
    required double? maxAltGainM,
    required double? elevationDropM,
    double? gpsMaxClimb,
    double? gpsMaxSink,
    double? baroMaxClimb,
    double? baroMaxSink,
    bool? hasBaroData,
  }) {
    _distanceM = distanceM;
    _maxAltitude = maxAltitude;
    _minAltitude = minAltitude;
    _maxClimb = maxClimb;
    _maxSink = maxSink;
    _gpsMaxClimb = gpsMaxClimb;
    _gpsMaxSink = gpsMaxSink;
    _baroMaxClimb = baroMaxClimb;
    _baroMaxSink = baroMaxSink;
    _hasBaroData = hasBaroData;
    if (hasBaroData != null) {
      _maxClimb = hasBaroData
          ? (baroMaxClimb ?? maxClimb)
          : (gpsMaxClimb ?? maxClimb);
      _maxSink = hasBaroData
          ? (baroMaxSink ?? maxSink)
          : (gpsMaxSink ?? maxSink);
    }
    _maxAltGainM = maxAltGainM;
    _elevationDropM = elevationDropM;
    _persistedPointCount = pointCount;
  }

  final DateTime startTime;
  DateTime? endTime;

  /// Whether this flight was started by automatic take-off detection. Null is
  /// used only for synthetic debug tracks with independently randomized markers.
  bool? startedAutomatically;

  /// Whether this flight was ended by automatic landing detection. Null is
  /// used only for synthetic debug tracks with independently randomized markers.
  bool? endedAutomatically;

  /// True only when automatic detection started and ended this flight.
  bool get isAutoFlight =>
      startedAutomatically == true && endedAutomatically == true;

  /// Optional post-flight metadata (set from the Flights sheet, persisted with
  /// the track and included in exports / share cards).
  ///
  /// Aircraft configuration captured when this flight starts. It is stored on
  /// the flight so later edits to the active aircraft do not change history;
  /// users can correct this snapshot from the flight details screen.
  String? aircraftFaiClass;
  String? aircraftManufacturer;
  String? aircraftModel;
  String? aircraftName;
  String? aircraftCategory;
  bool? aircraftTandem;
  String? aircraftEngineType;
  double? aircraftTrimSpeedKmh;
  double? aircraftGoalGlideRatio;

  bool get hasAircraftInformation =>
      aircraftFaiClass != null ||
      aircraftManufacturer?.isNotEmpty == true ||
      aircraftModel?.isNotEmpty == true ||
      aircraftName?.isNotEmpty == true ||
      aircraftCategory?.isNotEmpty == true ||
      aircraftTandem != null ||
      aircraftEngineType != null ||
      aircraftTrimSpeedKmh != null ||
      aircraftGoalGlideRatio != null;

  /// Equipment names used for this flight (free text). Any of these may be
  /// null / empty when the pilot hasn't recorded them.
  String? gliderName;
  String? harnessName;
  String? helmetName;

  /// Reverse-geocoded place names for the launch and landing, when resolved.
  String? takeoffSite;
  String? landingSite;

  /// Pilot in command. Populated from the IGC `HFPLT` header on import; null
  /// for live recordings that carry no configured pilot.
  String? pilotName;

  /// All recorded samples (full snapshots), in chronological order. Empty for
  /// tracks restored from a persisted summary.
  final List<FlightSample> samples = [];

  /// Whether any equipment field has been recorded.
  bool get hasEquipment =>
      (gliderName?.isNotEmpty ?? false) ||
      (harnessName?.isNotEmpty ?? false) ||
      (helmetName?.isNotEmpty ?? false);

  // ── Incrementally-maintained statistics ────────────────────────────────────
  double _distanceM = 0.0;
  double _maxAltitude = double.negativeInfinity;
  double _minAltitude = double.infinity;
  double _maxClimb = 0.0;
  double _maxSink = 0.0;
  double? _gpsMaxClimb;
  double? _gpsMaxSink;
  double? _baroMaxClimb;
  double? _baroMaxSink;
  bool? _hasBaroData;
  DateTime? _gpsVarioWindowStart;
  double? _gpsVarioWindowPreviousAltitude;
  double _gpsVarioWindowChange = 0.0;
  DateTime? _baroVarioWindowStart;
  double? _baroVarioWindowPreviousAltitude;
  double _baroVarioWindowChange = 0.0;
  double? _maxAltGainM;
  double? _elevationDropM;
  double? _firstSampleAltitude;

  // Launch / landing coordinates, captured from the first and last fix so they
  // remain available even after the per-sample data has been dropped.
  double? _takeoffLat;
  double? _takeoffLon;
  double? _landingLat;
  double? _landingLon;

  // Launch / landing altitude (meters), captured the same way.
  double? _takeoffAltitude;
  double? _landingAltitude;
  FlightSample? _lastFixSample;

  /// Point count carried across a persistence round-trip when [samples] is
  /// empty (i.e. the track was restored from disk).
  int? _persistedPointCount;

  /// Cumulative distance between successive, chronologically increasing fixes.
  double get distanceM => _distanceM;

  /// Highest / lowest GNSS altitude seen (meters). Zero before any sample.
  double get maxAltitude =>
      _maxAltitude == double.negativeInfinity ? 0.0 : _maxAltitude;
  double get minAltitude =>
      _minAltitude == double.infinity ? 0.0 : _minAltitude;

  /// XCTrack's maximum 30-second climb/sink interval rates, in m/s; pressure
  /// altitude is used when available, otherwise GNSS altitude is used.
  double get maxClimb => _maxClimb;
  double get maxSink => _maxSink;

  /// Largest altitude gain from a preceding low to a later high, if known.
  double? get maxAltGainM => _maxAltGainM;

  /// First-sample altitude minus the latest sample altitude, if known.
  double? get elevationDropM => _elevationDropM;

  /// Launch / landing coordinates, or null when unknown (no fix seen).
  double? get takeoffLatitude => _takeoffLat;
  double? get takeoffLongitude => _takeoffLon;
  double? get landingLatitude => _landingLat;
  double? get landingLongitude => _landingLon;

  /// Launch / landing altitude in meters, or null when unknown.
  double? get takeoffAltitude => _takeoffAltitude;
  double? get landingAltitude => _landingAltitude;

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
    _lastFixSample = null;
  }

  /// Removes samples before [startIndex] and after [endIndex] (both inclusive
  /// retained indices), then rebuilds the summary from the remaining samples.
  /// At least two samples must remain so the flight stays replayable.
  bool trimSamples({required int startIndex, required int endIndex}) {
    if (samples.length < 2 ||
        startIndex < 0 ||
        endIndex >= samples.length ||
        endIndex - startIndex < 1) {
      return false;
    }
    if (startIndex == 0 && endIndex == samples.length - 1) return false;

    final trimmedBeginning = startIndex > 0;
    final trimmedEnd = endIndex < samples.length - 1;
    final retained = List<FlightSample>.of(
      samples.sublist(startIndex, endIndex + 1),
    );
    samples.clear();
    _distanceM = 0.0;
    _maxAltitude = double.negativeInfinity;
    _minAltitude = double.infinity;
    _maxClimb = 0.0;
    _maxSink = 0.0;
    _gpsMaxClimb = null;
    _gpsMaxSink = null;
    _baroMaxClimb = null;
    _baroMaxSink = null;
    _hasBaroData = null;
    _gpsVarioWindowStart = null;
    _gpsVarioWindowPreviousAltitude = null;
    _gpsVarioWindowChange = 0.0;
    _baroVarioWindowStart = null;
    _baroVarioWindowPreviousAltitude = null;
    _baroVarioWindowChange = 0.0;
    _maxAltGainM = null;
    _elevationDropM = null;
    _firstSampleAltitude = null;
    _takeoffLat = null;
    _takeoffLon = null;
    _landingLat = null;
    _landingLon = null;
    _takeoffAltitude = null;
    _landingAltitude = null;
    _lastFixSample = null;
    _persistedPointCount = null;
    if (trimmedBeginning) takeoffSite = null;
    if (trimmedEnd) landingSite = null;

    for (final sample in retained) {
      add(sample);
    }
    if (trimmedEnd) endTime = retained.last.time;
    return true;
  }

  DateTime get firstRecordedTime =>
      samples.isNotEmpty ? samples.first.time : startTime;

  DateTime get lastRecordedTime =>
      samples.isNotEmpty ? samples.last.time : (endTime ?? DateTime.now());

  Duration get duration => samples.isNotEmpty
      ? samples.last.time.difference(samples.first.time)
      : (endTime ?? DateTime.now()).difference(startTime);

  /// Appends a sample and folds it into XCTrack-compatible summary statistics.
  void add(FlightSample s) {
    final prev = samples.isNotEmpty ? samples.last : null;
    samples.add(s);

    final chronological = prev == null || s.time.isAfter(prev.time);
    if (!chronological) return;

    final alt = s.data.gpsAltitude ?? s.data.altitude;
    _maxAltGainM ??= 0.0;
    if (_minAltitude != double.infinity) {
      final gain = alt - _minAltitude;
      if (gain > _maxAltGainM!) _maxAltGainM = gain;
    }
    _firstSampleAltitude ??= alt;
    _elevationDropM = _firstSampleAltitude! - alt;
    if (alt > _maxAltitude) _maxAltitude = alt;
    if (alt < _minAltitude) _minAltitude = alt;

    _foldVarioWindow(time: s.time, altitude: alt, barometric: false);
    final baroAlt = s.data.baroAltitude;
    _hasBaroData = baroAlt != null && baroAlt != 0;
    if (baroAlt != null && baroAlt != 0) {
      _foldVarioWindow(time: s.time, altitude: baroAlt, barometric: true);
    }
    if (_hasBaroData == true) {
      _maxClimb = _baroMaxClimb ?? 0.0;
      _maxSink = _baroMaxSink ?? 0.0;
    } else {
      _maxClimb = _gpsMaxClimb ?? 0.0;
      _maxSink = _gpsMaxSink ?? 0.0;
    }

    if (s.data.hasFix) {
      // XCTrack uses the first and last tracklog fixes for endpoint values.
      _takeoffLat ??= s.data.latitude;
      _takeoffLon ??= s.data.longitude;
      _takeoffAltitude ??= alt;
      _landingLat = s.data.latitude;
      _landingLon = s.data.longitude;
      _landingAltitude = alt;

      final previousFix = _lastFixSample;
      if (previousFix != null) {
        _distanceM += _haversineM(
          previousFix.data.latitude,
          previousFix.data.longitude,
          s.data.latitude,
          s.data.longitude,
        );
      }
      _lastFixSample = s;
    }
  }

  void _foldVarioWindow({
    required DateTime time,
    required double altitude,
    required bool barometric,
  }) {
    final start = barometric ? _baroVarioWindowStart : _gpsVarioWindowStart;
    final previous = barometric
        ? _baroVarioWindowPreviousAltitude
        : _gpsVarioWindowPreviousAltitude;
    if (start == null || previous == null) {
      if (barometric) {
        _baroVarioWindowStart = time;
        _baroVarioWindowPreviousAltitude = altitude;
        _baroVarioWindowChange = 0.0;
      } else {
        _gpsVarioWindowStart = time;
        _gpsVarioWindowPreviousAltitude = altitude;
        _gpsVarioWindowChange = 0.0;
      }
      return;
    }

    if (barometric) {
      _baroVarioWindowChange += altitude - previous;
      _baroVarioWindowPreviousAltitude = altitude;
    } else {
      _gpsVarioWindowChange += altitude - previous;
      _gpsVarioWindowPreviousAltitude = altitude;
    }

    final elapsed = time.difference(start);
    if (elapsed < const Duration(seconds: 30)) return;
    final change = barometric ? _baroVarioWindowChange : _gpsVarioWindowChange;
    final rate = change / (elapsed.inMilliseconds / 1000.0);
    if (barometric) {
      final maxClimb = _baroMaxClimb ?? 0.0;
      final maxSink = _baroMaxSink ?? 0.0;
      if (rate > maxClimb) _baroMaxClimb = rate;
      if (rate < maxSink) _baroMaxSink = rate;
      _baroVarioWindowStart = null;
      _baroVarioWindowPreviousAltitude = null;
      _baroVarioWindowChange = 0.0;
    } else {
      final maxClimb = _gpsMaxClimb ?? 0.0;
      final maxSink = _gpsMaxSink ?? 0.0;
      if (rate > maxClimb) _gpsMaxClimb = rate;
      if (rate < maxSink) _gpsMaxSink = rate;
      _gpsVarioWindowStart = null;
      _gpsVarioWindowPreviousAltitude = null;
      _gpsVarioWindowChange = 0.0;
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
      'maxAltitude': _maxAltitude == double.negativeInfinity
          ? 0.0
          : _maxAltitude,
      'minAltitude': _minAltitude == double.infinity ? 0.0 : _minAltitude,
      'maxClimb': _maxClimb,
      'maxSink': _maxSink,
      if (_gpsMaxClimb != null) 'gpsMaxClimb': _gpsMaxClimb,
      if (_gpsMaxSink != null) 'gpsMaxSink': _gpsMaxSink,
      if (_baroMaxClimb != null) 'baroMaxClimb': _baroMaxClimb,
      if (_baroMaxSink != null) 'baroMaxSink': _baroMaxSink,
      if (_hasBaroData != null) 'hasBaroData': _hasBaroData,
      if (_maxAltGainM != null) 'maxAltGainM': _maxAltGainM,
      if (_elevationDropM != null) 'elevationDropM': _elevationDropM,
      'pointCount': pointCount,
      if (startedAutomatically != null)
        'startedAutomatically': startedAutomatically,
      if (endedAutomatically != null) 'endedAutomatically': endedAutomatically,
      // Aircraft configuration snapshot captured at takeoff.
      if (aircraftFaiClass != null) 'aircraftFaiClass': aircraftFaiClass,
      if (aircraftManufacturer?.isNotEmpty ?? false)
        'aircraftManufacturer': aircraftManufacturer,
      if (aircraftModel?.isNotEmpty ?? false) 'aircraftModel': aircraftModel,
      if (aircraftName?.isNotEmpty ?? false) 'aircraftName': aircraftName,
      if (aircraftCategory?.isNotEmpty ?? false)
        'aircraftCategory': aircraftCategory,
      if (aircraftTandem != null) 'aircraftTandem': aircraftTandem,
      if (aircraftEngineType != null) 'aircraftEngineType': aircraftEngineType,
      if (aircraftTrimSpeedKmh != null)
        'aircraftTrimSpeedKmh': aircraftTrimSpeedKmh,
      if (aircraftGoalGlideRatio != null)
        'aircraftGoalGlideRatio': aircraftGoalGlideRatio,
      // Optional post-flight metadata (omitted when unset to keep payloads lean).
      if (gliderName?.isNotEmpty ?? false) 'gliderName': gliderName,
      if (harnessName?.isNotEmpty ?? false) 'harnessName': harnessName,
      if (helmetName?.isNotEmpty ?? false) 'helmetName': helmetName,
      if (takeoffSite?.isNotEmpty ?? false) 'takeoffSite': takeoffSite,
      if (landingSite?.isNotEmpty ?? false) 'landingSite': landingSite,
      if (pilotName?.isNotEmpty ?? false) 'pilotName': pilotName,
      if (_takeoffLat != null) 'takeoffLat': _takeoffLat,
      if (_takeoffLon != null) 'takeoffLon': _takeoffLon,
      if (_landingLat != null) 'landingLat': _landingLat,
      if (_landingLon != null) 'landingLon': _landingLon,
      if (_takeoffAltitude != null) 'takeoffAlt': _takeoffAltitude,
      if (_landingAltitude != null) 'landingAlt': _landingAltitude,
    };
  }

  /// Copies the optional metadata fields out of a persisted [json] map.
  void _restoreMeta(Map<String, dynamic> json) {
    startedAutomatically = json['startedAutomatically'] as bool?;
    endedAutomatically = json['endedAutomatically'] as bool?;
    aircraftFaiClass = json['aircraftFaiClass'] as String?;
    aircraftManufacturer = json['aircraftManufacturer'] as String?;
    aircraftModel = json['aircraftModel'] as String?;
    aircraftName = json['aircraftName'] as String?;
    aircraftCategory = json['aircraftCategory'] as String?;
    aircraftTandem = json['aircraftTandem'] as bool?;
    aircraftEngineType = json['aircraftEngineType'] as String?;
    aircraftTrimSpeedKmh = (json['aircraftTrimSpeedKmh'] as num?)?.toDouble();
    aircraftGoalGlideRatio = (json['aircraftGoalGlideRatio'] as num?)
        ?.toDouble();
    gliderName = json['gliderName'] as String?;
    harnessName = json['harnessName'] as String?;
    helmetName = json['helmetName'] as String?;
    takeoffSite = json['takeoffSite'] as String?;
    landingSite = json['landingSite'] as String?;
    pilotName = json['pilotName'] as String?;
    _takeoffLat = (json['takeoffLat'] as num?)?.toDouble();
    _takeoffLon = (json['takeoffLon'] as num?)?.toDouble();
    _landingLat = (json['landingLat'] as num?)?.toDouble();
    _landingLon = (json['landingLon'] as num?)?.toDouble();
    _takeoffAltitude = (json['takeoffAlt'] as num?)?.toDouble();
    _landingAltitude = (json['landingAlt'] as num?)?.toDouble();
    _elevationDropM ??= _takeoffAltitude != null && _landingAltitude != null
        ? _takeoffAltitude! - _landingAltitude!
        : null;
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
      maxAltGainM: (json['maxAltGainM'] as num?)?.toDouble(),
      elevationDropM: (json['elevationDropM'] as num?)?.toDouble(),
      gpsMaxClimb: (json['gpsMaxClimb'] as num?)?.toDouble(),
      gpsMaxSink: (json['gpsMaxSink'] as num?)?.toDouble(),
      baroMaxClimb: (json['baroMaxClimb'] as num?)?.toDouble(),
      baroMaxSink: (json['baroMaxSink'] as num?)?.toDouble(),
      hasBaroData: json['hasBaroData'] as bool?,
    ).._restoreMeta(json);
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

    track.endTime =
        DateTime.tryParse(json['endTime'] as String? ?? '') ??
        track.samples.last.time;
    track._restoreMeta(json);
    return track;
  }

  static double _haversineM(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
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
///  * **Auto take-off / landing** — when [FlightState.autoDetect] is on, XCTrack's
///    point-speed take-off test and 30-second/altitude/wind landing test drive
///    the flight state. Landing can be automatic, manually confirmed, or
///    disabled; a take-off point within 65 seconds reopens the same track.

/// Kind of a flight start / end handled by the [FlightRecorder].
enum FlightTransitionKind {
  /// A new flight record was started.
  takeoff,

  /// An automatic takeoff within the quick-relaunch window reopened (merged
  /// into) the previous flight record.
  resumedTakeoff,

  /// The current flight record was completed.
  landing,
}

/// A flight start / end, emitted after the recorder has processed it.
@immutable
class FlightTransition {
  const FlightTransition({
    required this.kind,
    required this.automatic,
    this.track,
  });

  final FlightTransitionKind kind;

  /// Whether automatic detection (rather than the user) triggered it.
  final bool automatic;

  /// The track that was started / resumed / completed, if any.
  final FlightTrack? track;
}

class FlightRecorder extends ChangeNotifier {
  FlightRecorder._();
  static final FlightRecorder instance = FlightRecorder._();

  final StreamController<FlightTransition> _transitions =
      StreamController<FlightTransition>.broadcast();

  /// Flight starts / ends (including quick relaunches that resume the
  /// previous record), e.g. for voice announcements.
  Stream<FlightTransition> get transitions => _transitions.stream;

  // ── Tunables ────────────────────────────────────────────────────────────
  /// Minimum time between stored samples.
  static const Duration minInterval = Duration(seconds: 1);

  /// Minimum horizontal movement (m) required to store a new sample when the
  /// [minInterval] gate would otherwise pass. Also stored if altitude changed
  /// by [minAltitudeDeltaM].
  static const double minDistanceM = 3.0;
  static const double minAltitudeDeltaM = 1.0;

  final AutoFlightDetector _autoFlightDetector = AutoFlightDetector();

  FlightState? _flightState;
  FlightDataView? _source;
  bool _bound = false;

  FlightTrack? _current;
  bool _wasFlying = false;
  bool _automaticLandingTransition = false;
  bool _automaticTakeoffTransition = false;
  bool _landingConfirmationPending = false;
  DateTime? _transitionPointTime;
  FlightTrack? _quickRelaunchTrack;
  DateTime? _quickRelaunchAt;

  /// True when [_quickRelaunchTrack] was a short record discarded at landing:
  /// it is kept off the log but can still be resumed by a quick relaunch.
  bool _quickRelaunchTrackDiscarded = false;

  FlightSample? _lastStored;

  /// The most recently completed track (available after landing/stop).
  FlightTrack? _lastCompleted;
  FlightTrack? get lastCompletedTrack => _lastCompleted;

  /// All completed flight records, newest first. Backs the Flights screen.
  final List<FlightTrack> _tracks = [];
  List<FlightTrack> get tracks => List.unmodifiable(_tracks);

  /// Removes a completed track from the log.
  void deleteTrack(FlightTrack track) {
    deleteTracks([track]);
  }

  /// Removes several completed tracks from the log with a single save and
  /// notification. Returns how many tracks were actually removed.
  int deleteTracks(Iterable<FlightTrack> tracks) {
    var removed = 0;
    for (final track in tracks.toList()) {
      if (!_tracks.remove(track)) continue;
      removed++;
      if (identical(_quickRelaunchTrack, track)) {
        _quickRelaunchTrack = null;
        _quickRelaunchAt = null;
        _quickRelaunchTrackDiscarded = false;
      }
    }
    if (removed == 0) return 0;
    if (_lastCompleted != null && !_tracks.contains(_lastCompleted)) {
      _lastCompleted = _tracks.isNotEmpty ? _tracks.first : null;
    }
    FlightStore.instance.save(_tracks);
    notifyListeners();
    return removed;
  }

  /// Whether [track]'s recorded session lasted less than [threshold].
  static bool isShorterThan(FlightTrack track, Duration threshold) {
    final end = track.endTime;
    final duration = end != null
        ? end.difference(track.startTime)
        : track.duration;
    return !duration.isNegative && duration < threshold;
  }

  /// Logged flights whose recorded session lasted less than [threshold].
  List<FlightTrack> tracksShorterThan(Duration threshold) =>
      _tracks.where((track) => isShorterThan(track, threshold)).toList();

  /// Whether a just-completed recording should be discarded silently because
  /// short-flight cleanup is enabled and it falls below the threshold.
  bool _shouldDiscardNewRecord(FlightTrack track) {
    final settings = RecordingSettings.instance;
    return settings.autoDeleteShortFlights &&
        isShorterThan(
          track,
          Duration(seconds: settings.shortFlightThresholdSeconds),
        );
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

  /// Trims a logged track to the inclusive sample range and persists the
  /// rebuilt summary. At least two samples must remain.
  bool trimTrackSamples(
    FlightTrack track, {
    required int startIndex,
    required int endIndex,
  }) {
    if (!_tracks.contains(track)) return false;
    if (!track.trimSamples(startIndex: startIndex, endIndex: endIndex)) {
      return false;
    }
    FlightStore.instance.save(_tracks);
    notifyListeners();
    return true;
  }

  /// Clears the entire flight log.
  void clearTracks() {
    _quickRelaunchTrack = null;
    _quickRelaunchAt = null;
    _quickRelaunchTrackDiscarded = false;
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

  /// Persists in-place edits to a logged [track]'s optional metadata (aircraft,
  /// equipment names, reverse-geocoded site names) and notifies listeners.
  /// No-op if the track isn't in the log.
  void persistTrackMeta(FlightTrack track) {
    if (!_tracks.contains(track)) return;
    FlightStore.instance.save(_tracks);
    notifyListeners();
  }

  /// DEBUG ONLY — inserts a synthetic completed flight with a full, randomized
  /// per-sample track (real [FlightSample]s carrying GPS position, altitude and
  /// vertical speed) so the Flights screen *and* the replay screen can both be
  /// exercised without a real flight. Statistics are derived from the samples
  /// by [FlightTrack.add], exactly like a genuine recording.
  /// The start/end automation markers are randomized independently so the
  /// Flights list can exercise AUTO and non-AUTO appearances.
  /// No-op in release/profile builds.
  void addRandomDebugTrack() {
    if (!kDebugMode) return;
    final rnd = math.Random();

    // Random start within the last ~30 days and a random duration.
    final now = DateTime.now();
    final start = now.subtract(
      Duration(
        days: rnd.nextInt(30),
        hours: rnd.nextInt(24),
        minutes: rnd.nextInt(60),
      ),
    );
    final durationMin = 5 + rnd.nextInt(55); // 5 .. 60 min
    final sampleCount = math.max(2, durationMin * 6); // ~1 sample / 10 s

    final track = FlightTrack(startTime: start)
      ..startedAutomatically = rnd.nextBool()
      ..endedAutomatically = rnd.nextBool();

    // Keep the generated replay in an interior-China region. The bounds are
    // deliberately conservative so the random walk cannot enter a neighboring
    // country or drift into the sea during the longest generated flight.
    const minChinaLat = 28.5;
    const maxChinaLat = 33.5;
    const minChinaLng = 100.0;
    const maxChinaLng = 108.0;
    var lat = 30.25 + rnd.nextDouble() * 0.8; // Chengdu / Sichuan vicinity
    var lng = 103.6 + rnd.nextDouble() * 1.0;
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
      // Enforce the regional guarantee for every generated sample.
      lat = lat.clamp(minChinaLat, maxChinaLat);
      lng = lng.clamp(minChinaLng, maxChinaLng);

      track.add(
        FlightSample(
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
        ),
      );
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
  bool get hasPendingLandingConfirmation => _landingConfirmationPending;

  /// Resolves the manual landing prompt. A negative answer leaves the flight
  /// running and puts the detector into its anti-repeat cooldown.
  void resolveLandingConfirmation(bool landed) {
    if (!_landingConfirmationPending) return;
    _landingConfirmationPending = false;
    _autoFlightDetector.resolveLandingConfirmation();
    if (landed) _flightState?.stop();
    notifyListeners();
  }

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
    final transitionPointTime = _transitionPointTime;
    _transitionPointTime = null;
    if (flying) {
      final automaticTakeoff = _automaticTakeoffTransition;
      _automaticTakeoffTransition = false;
      final resumed = _beginRecording(
        allowQuickRelaunch: automaticTakeoff,
        automaticTakeoff: automaticTakeoff,
        at: transitionPointTime,
      );
      _transitions.add(
        FlightTransition(
          kind: resumed
              ? FlightTransitionKind.resumedTakeoff
              : FlightTransitionKind.takeoff,
          automatic: automaticTakeoff,
          track: _current,
        ),
      );
    } else {
      final automaticLanding = _automaticLandingTransition;
      _automaticLandingTransition = false;
      final completed = _current;
      final logged = _finishRecording(automaticLanding: automaticLanding);
      _transitions.add(
        FlightTransition(
          kind: FlightTransitionKind.landing,
          automatic: automaticLanding,
          track: completed,
        ),
      );
      if (automaticLanding && completed != null) {
        // A discarded short record stays resumable (off the log) during the
        // quick-relaunch window so a brief touch-and-go is not split.
        _quickRelaunchTrack = completed;
        _quickRelaunchAt = transitionPointTime;
        _quickRelaunchTrackDiscarded = !logged;
      } else {
        _quickRelaunchTrack = null;
        _quickRelaunchAt = null;
        _quickRelaunchTrackDiscarded = false;
      }
    }
    notifyListeners();
  }

  /// Starts (or, for a quick relaunch, resumes) the current track. Returns
  /// true when the previous track was resumed instead of starting a new one.
  bool _beginRecording({
    bool allowQuickRelaunch = false,
    bool automaticTakeoff = false,
    DateTime? at,
  }) {
    final relaunchTrack = _quickRelaunchTrack;
    final relaunchAt = _quickRelaunchAt;
    final relaunchDelta = at != null && relaunchAt != null
        ? at.difference(relaunchAt)
        : null;
    if (allowQuickRelaunch &&
        relaunchTrack != null &&
        relaunchAt != null &&
        relaunchDelta != null &&
        !relaunchDelta.isNegative &&
        relaunchDelta < AutoFlightDetector.quickRelaunchWindow &&
        (_quickRelaunchTrackDiscarded || _tracks.remove(relaunchTrack))) {
      _quickRelaunchTrackDiscarded = false;
      relaunchTrack.endTime = null;
      relaunchTrack.endedAutomatically = false;
      _current = relaunchTrack;
      _lastStored = relaunchTrack.samples.isEmpty
          ? null
          : relaunchTrack.samples.last;
      _quickRelaunchTrack = null;
      _quickRelaunchAt = null;
      _lastCompleted = _tracks.isNotEmpty ? _tracks.first : null;
      FlightStore.instance.save(_tracks);
      return true;
    }

    _quickRelaunchTrack = null;
    _quickRelaunchAt = null;
    _quickRelaunchTrackDiscarded = false;
    final aircraft = AircraftSettings.instance;
    _current = FlightTrack(startTime: DateTime.now())
      ..aircraftFaiClass = aircraft.faiClass
      ..aircraftManufacturer = aircraft.manufacturer
      ..aircraftModel = aircraft.model
      ..aircraftName = aircraft.name
      ..aircraftCategory = aircraft.isParagliderClass
          ? aircraft.paragliderCategory
          : aircraft.isHangGliderClass
          ? aircraft.hangGliderCategory
          : null
      ..aircraftTandem = aircraft.tandem
      ..aircraftEngineType = aircraft.engineType
      ..aircraftTrimSpeedKmh = aircraft.trimSpeedKmh
      ..aircraftGoalGlideRatio = aircraft.goalGlideRatio
      ..startedAutomatically = automaticTakeoff
      ..endedAutomatically = false
      // Keep the legacy equipment field aligned with the same takeoff snapshot.
      ..gliderName = aircraft.displayName;
    _lastStored = null;
    return false;
  }

  /// Completes the current recording. Returns true when it was added to the
  /// log, false when there was none or it was silently discarded as short.
  bool _finishRecording({bool automaticLanding = false}) {
    final t = _current;
    _current = null;
    _lastStored = null;
    if (t == null) return false;
    t.endedAutomatically = automaticLanding;
    t.endTime = DateTime.now();
    if (_shouldDiscardNewRecord(t)) return false;
    _lastCompleted = t;
    // Keep empty-but-valid sessions visible even if no sensor sample arrived.
    _tracks.insert(0, t);
    FlightStore.instance.save(_tracks);
    return true;
  }

  void _onData() {
    final source = _source;
    final fs = _flightState;
    if (source == null || fs == null) return;
    final data = source.data;
    final observedAt = DateTime.now();
    final sampleTime = data.gpsTimestamp ?? data.timestamp ?? observedAt;
    final action = _autoFlightDetector.update(
      data: data,
      observedAt: observedAt,
      isFlying: fs.isFlying,
      flightStartedAt: fs.startedAt,
      autoDetectEnabled: fs.autoDetect,
      landingMode: fs.landingMode,
      takeoffSpeedKph: fs.takeoffSpeedKph,
      trimSpeedKph: AircraftSettings.instance.trimSpeedKmh,
    );
    switch (action) {
      case AutoFlightAction.takeoff:
        _automaticTakeoffTransition = true;
        _transitionPointTime = sampleTime;
        fs.start(at: sampleTime);
      case AutoFlightAction.automaticLanding:
        _automaticLandingTransition = true;
        _transitionPointTime = sampleTime;
        fs.stop();
      case AutoFlightAction.requestLandingConfirmation:
        _landingConfirmationPending = true;
        notifyListeners();
      case null:
        break;
    }
    final now = sampleTime;

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
}
