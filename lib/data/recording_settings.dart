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
  /// Historical behavior: store at most once per second AND only when the
  /// aircraft moved ≥ [FlightRecorder.minDistanceM] horizontally or the
  /// altitude changed ≥ [FlightRecorder.minAltitudeDeltaM]. Skips redundant
  /// points while stationary. This is the default.
  smart,

  /// Store one point every second regardless of movement (fixed 1 Hz), similar
  /// to the IGC-style continuous logging used by dedicated flight instruments.
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

  // ── Current values (defaults) ─────────────────────────────────────────────
  RecordingIntervalMode _intervalMode = RecordingIntervalMode.smart;
  RecordingDetail _detail = RecordingDetail.full;

  /// The active recording interval mode. Defaults to
  /// [RecordingIntervalMode.smart] (the current logic).
  RecordingIntervalMode get intervalMode => _intervalMode;

  /// How much information is stored per track point. Defaults to
  /// [RecordingDetail.full] (record everything).
  RecordingDetail get detail => _detail;

  /// Convenience: whether track points should be stored in the compact,
  /// XCTrack/IGC-style field set instead of the full snapshot.
  bool get compactSamples => _detail == RecordingDetail.xctrack;

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

  static RecordingIntervalMode _decode(String value) {
    switch (value) {
      case 'fixed1s':
        return RecordingIntervalMode.fixed1s;
      case 'smart':
      default:
        return RecordingIntervalMode.smart;
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
}
