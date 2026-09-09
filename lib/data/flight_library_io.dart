import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'flight_derived_stats.dart';
import 'flight_recorder.dart';

/// Result of importing a `.pbflights` bundle.
class FlightImportResult {
  const FlightImportResult({
    required this.added,
    required this.skipped,
    required this.failed,
  });

  /// Newly added flights.
  final int added;

  /// Flights skipped as duplicates of ones already in the library.
  final int skipped;

  /// Entries that could not be parsed.
  final int failed;

  int get total => added + skipped + failed;
}

/// Exports the whole flight library to a single `.pbflights` bundle and imports
/// it back, with duplicate detection.
///
/// The bundle is a zip archive containing:
///   * `manifest.json` — format id, version, flight count, export time.
///   * `flights/<flightId>.json` — one full [FlightTrack] per file (including
///     per-sample data when present).
///
/// Self-contained port of the reference project's library export/import,
/// adapted to this project's [FlightRecorder]/[FlightTrack] model.
class FlightLibraryIO {
  FlightLibraryIO._();
  static final FlightLibraryIO instance = FlightLibraryIO._();

  static const String _formatId = 'parabeacon.flights';
  static const int _formatVersion = 1;
  static const String _ext = 'pbflights';

  // ── Export ─────────────────────────────────────────────────────────────

  /// Builds the `.pbflights` archive bytes for [tracks].
  List<int> buildBundle(List<FlightTrack> tracks) {
    final archive = Archive();

    final manifest = <String, dynamic>{
      'format': _formatId,
      'version': _formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'count': tracks.length,
    };
    _addJson(archive, 'manifest.json', manifest);

    for (final t in tracks) {
      final id = flightId(t);
      _addJson(archive, 'flights/$id.json', t.toJson());
    }

    final encoded = ZipEncoder().encode(archive);
    return encoded ?? const <int>[];
  }

  /// Exports the current library to a temp `.pbflights` file and shares it.
  /// Returns the temp file path.
  Future<String> exportAndShare(List<FlightTrack> tracks) async {
    final bytes = buildBundle(tracks);
    final dir = await getTemporaryDirectory();
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final fileName =
        'parabeacon_${now.year}${two(now.month)}${two(now.day)}.$_ext';
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(path, name: fileName)],
      subject: 'ParaBeacon flight library',
    );
    return path;
  }

  // ── Import ─────────────────────────────────────────────────────────────

  /// Imports a `.pbflights` (or plain `.zip`) bundle at [path] into the
  /// [FlightRecorder], skipping duplicates. Returns a summary.
  Future<FlightImportResult> importFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return importBytes(bytes);
  }

  /// Imports bundle [bytes] into the [FlightRecorder], skipping duplicates.
  Future<FlightImportResult> importBytes(List<int> bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return const FlightImportResult(added: 0, skipped: 0, failed: 1);
    }

    // Validate the manifest when present (tolerate plain zips without one).
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile != null) {
      try {
        final m = jsonDecode(utf8.decode(manifestFile.content as List<int>));
        if (m is Map &&
            m['format'] == _formatId &&
            (m['version'] as num?) != null &&
            (m['version'] as num).toInt() > _formatVersion) {
          // Newer format than we understand — refuse rather than corrupt data.
          return const FlightImportResult(added: 0, skipped: 0, failed: 1);
        }
      } catch (_) {
        // Ignore a malformed manifest; fall through to reading flight files.
      }
    }

    final recorder = FlightRecorder.instance;
    final existing = recorder.tracks;
    var added = 0;
    var skipped = 0;
    var failed = 0;
    final imported = <FlightTrack>[];

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (!name.startsWith('flights/') || !name.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(utf8.decode(entry.content as List<int>));
        if (decoded is! Map<String, dynamic>) {
          failed++;
          continue;
        }
        final track = FlightTrack.fromJson(decoded);
        if (track == null) {
          failed++;
          continue;
        }
        if (_isDuplicate(track, existing) ||
            _isDuplicate(track, imported)) {
          skipped++;
          continue;
        }
        imported.add(track);
        added++;
      } catch (_) {
        failed++;
      }
    }

    if (imported.isNotEmpty) {
      recorder.importTracks(imported);
    }
    return FlightImportResult(added: added, skipped: skipped, failed: failed);
  }

  /// A flight is a duplicate when its start time matches an existing one within
  /// ±5 s AND the point counts agree (mirrors the reference project's rule).
  bool _isDuplicate(FlightTrack t, List<FlightTrack> list) {
    for (final e in list) {
      final dtMs =
          (t.startTime.difference(e.startTime)).inMilliseconds.abs();
      if (dtMs <= 5000 && t.pointCount == e.pointCount) return true;
    }
    return false;
  }

  void _addJson(Archive archive, String name, Map<String, dynamic> json) {
    final data = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  /// The file extension (no dot) of the library bundle.
  static String get extension => _ext;
}
