import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'flight_recorder.dart';

/// Persists and restores completed [FlightTrack] summaries via
/// [SharedPreferences].
///
/// Only the summary (start/end, distance, altitude range, climb/sink extremes,
/// point count) is stored — not the per-sample data — so the storage footprint
/// stays small even for hundreds of flights. Writes are debounced so a burst of
/// changes (bulk delete, etc.) results in a single write.
class TrackLogStore {
  TrackLogStore._();
  static final TrackLogStore instance = TrackLogStore._();

  static const _kTracksKey = 'pb.tracks.v1';

  /// Bump when the serialized shape changes incompatibly.
  static const _schemaVersion = 1;

  Timer? _debounce;

  /// Loads all persisted flight tracks, newest first (matching the in-memory
  /// order used by [FlightRecorder.tracks]). Returns an empty list when
  /// nothing is stored or the payload is corrupt.
  Future<List<FlightTrack>> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_kTracksKey);
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const [];
      if ((decoded['version'] as num?)?.toInt() != _schemaVersion) {
        return const [];
      }

      final tracksJson = decoded['tracks'];
      if (tracksJson is! List) return const [];

      final tracks = <FlightTrack>[];
      for (final t in tracksJson) {
        if (t is Map<String, dynamic>) {
          final track = FlightTrack.fromSummaryJson(t);
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

  /// Schedules a debounced save of the given track summaries.
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
        'tracks': tracks.map((t) => t.toSummaryJson()).toList(),
      });
      await sp.setString(_kTracksKey, payload);
    } catch (_) {
      // Best-effort persistence; ignore storage failures.
    }
  }
}
