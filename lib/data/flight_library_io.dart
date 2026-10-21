import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'flight_derived_stats.dart';
import 'flight_recorder.dart';
import 'flight_timestamp.dart';

/// Result of importing a `.pbflights.zip` bundle.
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

/// Summary of a completed flight-library export.
class FlightExportResult {
  const FlightExportResult({
    required this.fileName,
    required this.flightCount,
    required this.byteSize,
    required this.savedToDevice,
    this.destination,
  });

  /// Name of the generated `.pbflights.zip` bundle.
  final String fileName;

  /// Number of flights written into the bundle.
  final int flightCount;

  /// Size of the generated bundle in bytes.
  final int byteSize;

  /// True when the bundle was written to a persistent device location
  /// (Android), false when it was handed to the share sheet.
  final bool savedToDevice;

  /// The document URI (Android) or file path where the bundle was written,
  /// when available.
  final String? destination;
}

/// Exports the whole flight library to a single `.pbflights.zip` bundle and imports
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
  static const int _formatVersion = 3;
  static const String _ext = 'pbflights.zip';
  static const MethodChannel _androidExportChannel = MethodChannel(
    'com.beacon.parabeacon/flight_library',
  );

  // ── Export ─────────────────────────────────────────────────────────────

  /// Builds the `.pbflights.zip` archive bytes for [tracks].
  List<int> buildBundle(List<FlightTrack> tracks) {
    final archive = Archive();

    final manifest = <String, dynamic>{
      'format': _formatId,
      'version': _formatVersion,
      'exportedAt': flightTimestampMilliseconds(DateTime.now()),
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

  /// Exports flight records. Android saves to `Downloads/ParaBeacon` unless
  /// [shareDirectly] is true. Other platforms share a temporary `.pbflights.zip`
  /// file.
  ///
  /// Returns a [FlightExportResult] describing the written bundle, or null when
  /// the Android save picker is cancelled.
  Future<FlightExportResult?> exportAndShare(
    List<FlightTrack> tracks, {
    bool shareDirectly = false,
  }) async {
    final bytes = buildBundle(tracks);
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final fileName =
        'parabeacon_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.$_ext';

    if (Platform.isAndroid && !shareDirectly) {
      final destination = await _saveAndroidDocument(bytes, fileName);
      if (destination == null) return null;
      return FlightExportResult(
        fileName: fileName,
        flightCount: tracks.length,
        byteSize: bytes.length,
        savedToDevice: true,
        destination: destination,
      );
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(path, name: fileName),
    ], subject: 'ParaBeacon flight library');
    return FlightExportResult(
      fileName: fileName,
      flightCount: tracks.length,
      byteSize: bytes.length,
      savedToDevice: false,
      destination: path,
    );
  }

  Future<String?> _saveAndroidDocument(List<int> bytes, String fileName) {
    return _androidExportChannel.invokeMethod<String>('saveFlightBundle', {
      'fileName': fileName,
      'bytes': Uint8List.fromList(bytes),
    });
  }

  // ── Import ─────────────────────────────────────────────────────────────

  /// Imports a `.pbflights.zip` (or plain `.zip`) bundle at [path] into the
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
        if (_isDuplicate(track, existing) || _isDuplicate(track, imported)) {
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
      final dtMs = (t.startTime.difference(e.startTime)).inMilliseconds.abs();
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
