import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much information is stored per recorded track point.
enum RecordingDetail {
  /// Store the full [FlightData] snapshot per point (vario, wind, pressure,
  /// temperature, accuracy, satellites, battery, heart rate, …). This is the
  /// default and preserves the richest data for later analysis.
  full,

  /// Store only the core IGC-style fields per point (latitude, longitude,
  /// barometric altitude, GPS altitude, heading, ground speed, fix validity,
  /// timestamp) — similar to what XCTrack writes into an IGC B-record. Produces
  /// smaller tracks and drops the auxiliary sensor data.
  xctrack,
}

/// How the [FlightRecorder] decides when to store a new track point.
enum RecordingIntervalMode {
  /// Store at most once per second AND only when the aircraft moved
  /// ≥ [FlightRecorder.minDistanceM] horizontally or the altitude changed
  /// ≥ [FlightRecorder.minAltitudeDeltaM]. Skips redundant points while
  /// stationary.
  smart,

  /// Store one point every second regardless of movement (fixed 1 Hz), similar
  /// to the IGC-style continuous logging used by dedicated flight instruments.
  /// This is the default.
  fixed1s,
}

/// Persisted user preference for how the flight track is recorded.
///
/// Follows the same shape as [DebugSettings] / [VarioSoundSettings]: a shared
/// singleton [ChangeNotifier] with a lazy [load], best-effort persistence, and
/// a silent fallback to defaults when storage is unavailable.
class RecordingSettings extends ChangeNotifier {
  RecordingSettings._();

  /// Shared singleton.
  static final RecordingSettings instance = RecordingSettings._();

  // ── Persistence keys ──────────────────────────────────────────────────────
  static const _kIntervalMode = 'pb.recording.intervalMode';
  static const _kDetail = 'pb.recording.detail';
  static const _kAutoDeleteShortFlights = 'pb.recording.autoDeleteShortFlights';
  static const _kShortFlightThresholdSeconds =
      'pb.recording.shortFlightThresholdSeconds';

  /// Supported automatic-deletion thresholds, in seconds.
  static const List<int> shortFlightThresholdOptions = [30, 60, 120, 300];
  static const int defaultShortFlightThresholdSeconds = 60;

  // ── Current values (defaults) ─────────────────────────────────────────────
  RecordingIntervalMode _intervalMode = RecordingIntervalMode.fixed1s;
  RecordingDetail _detail = RecordingDetail.full;
  bool _autoDeleteShortFlights = false;
  int _shortFlightThresholdSeconds = defaultShortFlightThresholdSeconds;

  /// The active recording interval mode. Defaults to
  /// [RecordingIntervalMode.fixed1s] (one point every second).
  RecordingIntervalMode get intervalMode => _intervalMode;

  /// How much information is stored per track point. Defaults to
  /// [RecordingDetail.full] (record everything).
  RecordingDetail get detail => _detail;

  /// Convenience: whether track points should be stored in the compact,
  /// XCTrack/IGC-style field set instead of the full snapshot.
  bool get compactSamples => _detail == RecordingDetail.xctrack;

  /// Whether completed flights shorter than the configured threshold are
  /// automatically removed. Defaults to off to avoid unexpected data loss.
  bool get autoDeleteShortFlights => _autoDeleteShortFlights;

  /// Minimum duration to keep a completed flight when short-flight cleanup is
  /// enabled. Defaults to one minute.
  int get shortFlightThresholdSeconds => _shortFlightThresholdSeconds;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Loads persisted values (if any). Safe to call multiple times; only the
  /// first call reads storage.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final stored = sp.getString(_kIntervalMode);
      if (stored != null) {
        _intervalMode = _decode(stored);
      }
      final storedDetail = sp.getString(_kDetail);
      if (storedDetail != null) {
        _detail = _decodeDetail(storedDetail);
      }
      _autoDeleteShortFlights =
          sp.getBool(_kAutoDeleteShortFlights) ?? _autoDeleteShortFlights;
      final storedThreshold = sp.getInt(_kShortFlightThresholdSeconds);
      if (storedThreshold != null &&
          shortFlightThresholdOptions.contains(storedThreshold)) {
        _shortFlightThresholdSeconds = storedThreshold;
      }
    } catch (_) {
      // Storage unavailable: keep defaults.
    }
    notifyListeners();
  }

  /// Selects the recording interval mode and persists it.
  void setIntervalMode(RecordingIntervalMode mode) {
    if (_intervalMode == mode) return;
    _intervalMode = mode;
    _persistString(_kIntervalMode, _encode(mode));
    notifyListeners();
  }

  /// Selects how much information is stored per track point and persists it.
  void setDetail(RecordingDetail detail) {
    if (_detail == detail) return;
    _detail = detail;
    _persistString(_kDetail, _encodeDetail(detail));
    notifyListeners();
  }

  /// Enables or disables automatic removal of short completed flights.
  void setAutoDeleteShortFlights(bool enabled) {
    if (_autoDeleteShortFlights == enabled) return;
    _autoDeleteShortFlights = enabled;
    _persistBool(_kAutoDeleteShortFlights, enabled);
    notifyListeners();
  }

  /// Selects a supported minimum duration for keeping completed flight logs.
  void setShortFlightThresholdSeconds(int seconds) {
    if (!shortFlightThresholdOptions.contains(seconds) ||
        _shortFlightThresholdSeconds == seconds) {
      return;
    }
    _shortFlightThresholdSeconds = seconds;
    _persistInt(_kShortFlightThresholdSeconds, seconds);
    notifyListeners();
  }

  static RecordingIntervalMode _decode(String value) {
    switch (value) {
      case 'smart':
        return RecordingIntervalMode.smart;
      case 'fixed1s':
      default:
        return RecordingIntervalMode.fixed1s;
    }
  }

  static String _encode(RecordingIntervalMode mode) {
    switch (mode) {
      case RecordingIntervalMode.fixed1s:
        return 'fixed1s';
      case RecordingIntervalMode.smart:
        return 'smart';
    }
  }

  static RecordingDetail _decodeDetail(String value) {
    switch (value) {
      case 'xctrack':
        return RecordingDetail.xctrack;
      case 'full':
      default:
        return RecordingDetail.full;
    }
  }

  static String _encodeDetail(RecordingDetail detail) {
    switch (detail) {
      case RecordingDetail.xctrack:
        return 'xctrack';
      case RecordingDetail.full:
        return 'full';
    }
  }

  void _persistString(String key, String value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, value);
    } catch (_) {}
  }

  void _persistBool(String key, bool value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(key, value);
    } catch (_) {}
  }

  void _persistInt(String key, int value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(key, value);
    } catch (_) {}
  }
}
