import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'flight_recorder.dart';

/// Persists and restores completed [FlightTrack]s via [SharedPreferences].
///
/// The full track is stored — summary statistics *and* the per-sample data —
/// so a completed flight can still be replayed after an app restart. Tracks
/// whose samples have been deleted persist as summary-only (their `samples`
/// array is simply omitted). Writes are debounced so a burst of changes (bulk
/// delete, etc.) results in a single write.
class FlightStore {
  FlightStore._();
  static final FlightStore instance = FlightStore._();

  // NOTE: storage key kept as `pb.tracks.v1` for backward compatibility so
  // existing users' saved flights still load after the rename.
  static const _kTracksKey = 'pb.tracks.v1';

  /// Current serialized shape. v2 adds per-sample track data; v1 payloads
  /// (summary-only) are still readable via [FlightTrack.fromJson], which
  /// transparently falls back when no `samples` array is present.
  static const _schemaVersion = 2;

  Timer? _debounce;

  /// Loads all persisted flights, newest first (matching the in-memory order
  /// used by [FlightRecorder.tracks]). Returns an empty list when nothing is
  /// stored or the payload is corrupt.
  Future<List<FlightTrack>> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kTracksKey);
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const [];
      final version = (decoded['version'] as num?)?.toInt() ?? 0;
      // Accept the current schema and any older, forward-compatible one. v1
      // stored summaries only; v2 adds an optional per-sample `samples` array.
      // [FlightTrack.fromJson] handles both shapes.
      if (version < 1 || version > _schemaVersion) {
        return const [];
      }

      final tracksJson = decoded['tracks'];
      if (tracksJson is! List) return const [];

      final tracks = <FlightTrack>[];
      for (final t in tracksJson) {
        if (t is Map<String, dynamic>) {
          final track = FlightTrack.fromJson(t);
          if (track != null) tracks.add(track);
        }
      }
      return tracks;
    } catch (_) {
      // Corrupt / incompatible data: start with an empty log rather than
      // crashing. The user can always start fresh.
      return const [];
    }
  }

  /// Schedules a debounced save of the given flight summaries.
  void save(
    List<FlightTrack> tracks, {
    Duration debounce = const Duration(milliseconds: 400),
  }) {
    _debounce?.cancel();
    // Snapshot the caller's list so a subsequent mutation before the debounce
    // fires can't produce a torn write.
    final snapshot = List<FlightTrack>.of(tracks);
    _debounce = Timer(debounce, () => _writeNow(snapshot));
  }

  /// Writes immediately, cancelling any pending debounced save.
  Future<void> flush(List<FlightTrack> tracks) async {
    _debounce?.cancel();
    _debounce = null;
    await _writeNow(List<FlightTrack>.of(tracks));
  }

  Future<void> _writeNow(List<FlightTrack> tracks) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'version': _schemaVersion,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      });
      await sp.setString(_kTracksKey, payload);
    } catch (_) {
      // Best-effort persistence; ignore storage failures.
    }
  }
}
