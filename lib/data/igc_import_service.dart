import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import 'flight_data.dart';
import 'flight_library_io.dart';
import 'flight_recorder.dart';

/// Imports FAI IGC tracklogs (as produced by XCTrack and most flight
/// instruments) into the flight library.
///
/// The pilot copies the whole `Tracklogs` folder off their device (XCTrack
/// stores one `.igc` per flight there) and points the app at it; every `.igc`
/// file found is parsed into a [FlightTrack] and merged into the
/// [FlightRecorder], skipping flights already in the library.
///
/// Only the standard, fixed-width IGC records we need are parsed:
///   * `HFDTE…` header → the flight date (UTC).
///   * `B` fix records → time, latitude, longitude, pressure + GNSS altitude.
///
/// IGC carries no vertical/ground speed or heading, so those are derived from
/// consecutive fixes (altitude delta / time, haversine distance / time, and
/// great-circle bearing) exactly like a live recording, which keeps the
/// derived statistics (max climb/sink, speeds, glide) meaningful.
class IgcImportService {
  IgcImportService._();
  static final IgcImportService instance = IgcImportService._();

  /// File extension (no dot) handled by this importer.
  static const String extension = 'igc';

  /// Scans [dirPath] (recursively) for `.igc` files, parses each into a
  /// [FlightTrack] and imports the non-duplicates into the [FlightRecorder].
  ///
  /// Works where the app can read the folder directly through `dart:io`
  /// (desktop, or Android paths the app owns). On Android, a folder picked via
  /// the system picker is usually a Storage Access Framework URI that cannot be
  /// read this way — use [importContents] with the picker's file bytes instead.
  ///
  /// Duplicates — against the existing library *and* within this batch — are
  /// skipped using the same rule as the `.pbflights` importer (start time
  /// within ±5 s and matching point count). Files that cannot be parsed are
  /// counted as failures. Returns a summary.
  Future<FlightImportResult> importDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      return const FlightImportResult(added: 0, skipped: 0, failed: 0);
    }

    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          p.extension(entity.path).toLowerCase() == '.$extension') {
        files.add(entity);
      }
    }
    // Deterministic order (XCTrack names sort chronologically).
    files.sort((a, b) => a.path.compareTo(b.path));

    final parsed = <FlightTrack?>[];
    for (final file in files) {
      try {
        parsed.add(await parseFile(file));
      } catch (_) {
        parsed.add(null);
      }
    }
    return _commit(parsed);
  }

  /// Imports IGC documents from their raw [contents] (one `List<int>` per
  /// file), parsing and de-duplicating exactly like [importDirectory].
  ///
  /// This is the path used on Android/iOS, where the user picks the `.igc`
  /// files through the system file picker (which hands back readable bytes),
  /// avoiding the storage-permission limits that block reading a picked folder
  /// directly.
  Future<FlightImportResult> importContents(List<List<int>> contents) async {
    final parsed = <FlightTrack?>[];
    for (final bytes in contents) {
      try {
        final text = const Utf8Decoder(allowMalformed: true).convert(bytes);
        parsed.add(parseString(text));
      } catch (_) {
        parsed.add(null);
      }
    }
    return _commit(parsed);
  }

  /// De-duplicates [parsed] tracks (null entries count as parse failures),
  /// commits the survivors to the [FlightRecorder] and returns a summary.
  FlightImportResult _commit(List<FlightTrack?> parsed) {
    final recorder = FlightRecorder.instance;
    final existing = recorder.tracks;
    final imported = <FlightTrack>[];
    var added = 0;
    var skipped = 0;
    var failed = 0;

    for (final track in parsed) {
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
    }

    if (imported.isNotEmpty) {
      recorder.importTracks(imported);
    }
    return FlightImportResult(added: added, skipped: skipped, failed: failed);
  }

  /// Reads and parses a single IGC [file]. Returns null when it holds no
  /// usable fixes.
  Future<FlightTrack?> parseFile(File file) async {
    // IGC is ASCII; decode leniently so a stray non-ASCII byte in a header
    // (e.g. a pilot name) never aborts the whole parse.
    final bytes = await file.readAsBytes();
    final content = const Utf8Decoder(allowMalformed: true).convert(bytes);
    return parseString(content);
  }

  /// Parses IGC document [content] into a [FlightTrack], or null when it has
  /// fewer than two valid fixes (nothing worth logging).
  FlightTrack? parseString(String content) {
    final lines = const LineSplitter().convert(content);

    DateTime? flightDate; // UTC date (midnight) from the H record.
    String? gliderType;

    // First pass: headers.
    for (final line in lines) {
      if (line.startsWith('HFDTE')) {
        flightDate ??= _parseHeaderDate(line);
      } else if (line.startsWith('HFGTYGLIDERTYPE')) {
        final idx = line.indexOf(':');
        if (idx >= 0 && idx + 1 < line.length) {
          final v = line.substring(idx + 1).trim();
          if (v.isNotEmpty) gliderType = v;
        }
      }
    }

    // Second pass: B (fix) records.
    final fixes = <_IgcFix>[];
    DateTime? prevTime;
    var dayOffset = 0;
    for (final line in lines) {
      if (line.isEmpty || line.codeUnitAt(0) != 0x42 /* 'B' */ ) continue;
      final fix = _parseBRecord(line, flightDate ?? _epochDate, dayOffset);
      if (fix == null) continue;
      // Handle UTC midnight rollover: time went backwards → next day.
      if (prevTime != null && fix.time.isBefore(prevTime)) {
        dayOffset++;
        final rolled = _parseBRecord(line, flightDate ?? _epochDate, dayOffset);
        if (rolled == null) continue;
        fixes.add(rolled);
        prevTime = rolled.time;
      } else {
        fixes.add(fix);
        prevTime = fix.time;
      }
    }

    if (fixes.length < 2) return null;

    // IGC times are UTC; present them in local wall-clock time so a flight
    // shows at the hour the pilot actually flew (same convention as live
    // recording, which stamps samples with the local clock).
    final track = FlightTrack(startTime: fixes.first.time.toLocal());

    _IgcFix? prev;
    for (final f in fixes) {
      final time = f.time.toLocal();
      final effectiveAlt = f.baroAltitude != 0
          ? f.baroAltitude.toDouble()
          : f.gnssAltitude.toDouble();

      double verticalSpeed = 0;
      double groundSpeed = 0;
      double heading = 0;
      if (prev != null) {
        final dtSec = f.time.difference(prev.time).inMilliseconds / 1000.0;
        if (dtSec > 0) {
          final prevAlt = prev.baroAltitude != 0
              ? prev.baroAltitude.toDouble()
              : prev.gnssAltitude.toDouble();
          verticalSpeed = (effectiveAlt - prevAlt) / dtSec;
          final distM = _haversineM(
            prev.lat,
            prev.lon,
            f.lat,
            f.lon,
          );
          groundSpeed = (distM / dtSec) * 3.6; // km/h
          heading = _bearingDeg(prev.lat, prev.lon, f.lat, f.lon);
        }
      }

      track.add(
        FlightSample(
          time: time,
          data: FlightData(
            verticalSpeed: verticalSpeed,
            groundSpeed: groundSpeed,
            altitude: effectiveAlt,
            baroAltitude: f.baroAltitude != 0 ? f.baroAltitude.toDouble() : null,
            gpsAltitude: f.gnssAltitude != 0 ? f.gnssAltitude.toDouble() : null,
            latitude: f.lat,
            longitude: f.lon,
            heading: heading,
            hasFix: true,
            timestamp: time,
          ),
        ),
      );
      prev = f;
    }

    track.endTime = fixes.last.time.toLocal();
    if (gliderType != null) track.gliderName = gliderType;
    return track;
  }

  // ── Header date ─────────────────────────────────────────────────────────

  /// Parses the flight date (UTC midnight) from an `HFDTE` header. Supports
  /// both the legacy `HFDTEDDMMYY` form and the current
  /// `HFDTEDATE:DDMMYY,NN` form.
  DateTime? _parseHeaderDate(String line) {
    // Collect the first 6 digits following the HFDTE / HFDTEDATE: prefix.
    final digits = StringBuffer();
    for (var i = 5; i < line.length && digits.length < 6; i++) {
      final c = line.codeUnitAt(i);
      if (c >= 0x30 && c <= 0x39) {
        digits.write(line[i]);
      } else if (digits.isNotEmpty) {
        // Stop at the first non-digit once we've started (e.g. the ',NN').
        break;
      }
    }
    if (digits.length != 6) return null;
    final s = digits.toString();
    final dd = int.tryParse(s.substring(0, 2));
    final mm = int.tryParse(s.substring(2, 4));
    final yy = int.tryParse(s.substring(4, 6));
    if (dd == null || mm == null || yy == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
    // Two-digit year: 70-99 → 1970-1999, 00-69 → 2000-2069.
    final year = yy >= 70 ? 1900 + yy : 2000 + yy;
    return DateTime.utc(year, mm, dd);
  }

  // ── B record ──────────────────────────────────────────────────────────────

  /// Parses one fixed-width IGC `B` record. [date] is the flight's UTC date
  /// (midnight); [dayOffset] accounts for UTC-midnight rollovers.
  ///
  /// Layout (bytes, 1-based): `B HHMMSS DDMMmmmN DDDMMmmmE V PPPPP GGGGG …`.
  _IgcFix? _parseBRecord(String line, DateTime date, int dayOffset) {
    if (line.length < 35) return null;
    try {
      final hh = int.parse(line.substring(1, 3));
      final mm = int.parse(line.substring(3, 5));
      final ss = int.parse(line.substring(5, 7));

      final latDeg = int.parse(line.substring(7, 9));
      final latMinThousandths = int.parse(line.substring(9, 14));
      final latHemi = line[14];
      var lat = latDeg + (latMinThousandths / 1000.0) / 60.0;
      if (latHemi == 'S' || latHemi == 's') lat = -lat;

      final lonDeg = int.parse(line.substring(15, 18));
      final lonMinThousandths = int.parse(line.substring(18, 23));
      final lonHemi = line[23];
      var lon = lonDeg + (lonMinThousandths / 1000.0) / 60.0;
      if (lonHemi == 'W' || lonHemi == 'w') lon = -lon;

      // line[24] is the fix validity (A/V); we keep the position regardless.
      final baro = int.parse(line.substring(25, 30));
      final gnss = int.parse(line.substring(30, 35));

      final time = DateTime.utc(
        date.year,
        date.month,
        date.day + dayOffset,
        hh,
        mm,
        ss,
      );

      if (lat.abs() > 90 || lon.abs() > 180) return null;
      return _IgcFix(
        time: time,
        lat: lat,
        lon: lon,
        baroAltitude: baro,
        gnssAltitude: gnss,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Duplicate detection (mirrors FlightLibraryIO) ──────────────────────────

  bool _isDuplicate(FlightTrack t, List<FlightTrack> list) {
    for (final e in list) {
      final dtMs = (t.startTime.difference(e.startTime)).inMilliseconds.abs();
      if (dtMs <= 5000 && t.pointCount == e.pointCount) return true;
    }
    return false;
  }

  // ── Geo helpers ───────────────────────────────────────────────────────────

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

  static double _bearingDeg(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _rad(lon2 - lon1);
    final y = math.sin(dLon) * math.cos(_rad(lat2));
    final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
        math.sin(_rad(lat1)) * math.cos(_rad(lat2)) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    return (brng + 360.0) % 360.0;
  }

  static double _rad(double deg) => deg * (math.pi / 180.0);

  /// Fallback used when a file has no HFDTE header: a fixed epoch date so the
  /// time-of-day is still preserved and the flight is still importable.
  static final DateTime _epochDate = DateTime.utc(1970, 1, 1);
}

/// A single parsed IGC fix (internal to the importer).
class _IgcFix {
  const _IgcFix({
    required this.time,
    required this.lat,
    required this.lon,
    required this.baroAltitude,
    required this.gnssAltitude,
  });

  final DateTime time;
  final double lat;
  final double lon;
  final int baroAltitude;
  final int gnssAltitude;
}
