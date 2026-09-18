import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'aircraft_settings.dart';
import 'flight_derived_stats.dart';
import 'flight_recorder.dart';

/// Builds and shares standard track exports (GPX and signed IGC) from a
/// completed [FlightTrack].
///
/// Self-contained port of the reference project's IGC/GPX exporters, adapted to
/// this project's [FlightTrack]/[FlightSample] model. Only tracks that still
/// carry per-sample data ([FlightTrack.hasSamples]) can be exported.
class FlightExportService {
  FlightExportService._();
  static final FlightExportService instance = FlightExportService._();

  /// Free-text producer id embedded in exports.
  static const String _producer = 'ParaBeacon';

  // ── GPX ───────────────────────────────────────────────────────────────────

  /// Builds a GPX 1.1 document string for [track].
  String buildGpx(FlightTrack track) {
    final b = StringBuffer();
    b.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    b.writeln(
      '<gpx version="1.1" creator="$_producer" '
      'xmlns="http://www.topografix.com/GPX/1/1">',
    );
    b.writeln('  <metadata>');
    b.writeln('    <name>${_xml(flightSlug(track))}</name>');
    b.writeln('    <time>${track.startTime.toUtc().toIso8601String()}</time>');
    b.writeln('  </metadata>');
    b.writeln('  <trk>');
    b.writeln('    <name>${_xml(flightSlug(track))}</name>');
    b.writeln('    <trkseg>');
    for (final s in track.samples) {
      if (!s.data.hasFix) continue;
      final lat = s.data.latitude.toStringAsFixed(7);
      final lon = s.data.longitude.toStringAsFixed(7);
      b.writeln('      <trkpt lat="$lat" lon="$lon">');
      b.writeln('        <ele>${s.data.altitude.toStringAsFixed(1)}</ele>');
      b.writeln('        <time>${s.time.toUtc().toIso8601String()}</time>');
      b.writeln('      </trkpt>');
    }
    b.writeln('    </trkseg>');
    b.writeln('  </trk>');
    b.writeln('</gpx>');
    return b.toString();
  }

  // ── IGC ─────────────────────────────────────────────────────────────────

  /// Builds an IGC document string for [track], terminated by a SHA-256
  /// "G-record" signature over the body (a lightweight integrity check — not a
  /// certified FAI security record).
  String buildIgc(FlightTrack track) {
    final body = _buildIgcBody(track);
    final digest = sha256.convert(utf8.encode(body)).toString().toUpperCase();
    final g = StringBuffer(body);
    // Chunk the digest across G-records (max ~75 chars/line is plenty here).
    g.writeln('G$digest');
    return g.toString();
  }

  String _buildIgcBody(FlightTrack track) {
    final b = StringBuffer();
    final start = track.startTime.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');

    // A record: manufacturer + unique id.
    b.writeln('AXXX$_producer');
    // H records: date + basic headers.
    b.writeln(
      'HFDTE${two(start.day)}${two(start.month)}${two(start.year % 100)}',
    );
    b.writeln('HFFXA035');
    b.writeln('HFPLTPILOTINCHARGE:');
    final configuredAircraft = AircraftSettings.instance.displayName;
    final trackAircraft = track.gliderName?.trim();
    final snapshotAircraft = [
      track.aircraftManufacturer?.trim() ?? '',
      track.aircraftModel?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join(' ');
    final aircraftType = trackAircraft == null || trackAircraft.isEmpty
        ? (snapshotAircraft.isEmpty ? configuredAircraft : snapshotAircraft)
        : trackAircraft;
    b.writeln('HFGTYGLIDERTYPE:${_igcHeaderValue(aircraftType)}');
    b.writeln('HFDTMGPSDATUM:WGS84');
    b.writeln('HFRFWFIRMWAREVERSION:1.0');
    b.writeln('HFRHWHARDWAREVERSION:1.0');
    b.writeln('HFFTYFRTYPE:$_producer');

    for (final s in track.samples) {
      if (!s.data.hasFix) continue;
      b.writeln(_igcBRecord(s));
    }
    return b.toString();
  }

  String _igcHeaderValue(String value) =>
      value.replaceAll(RegExp(r'[\r\n]'), ' ').trim();

  /// One IGC "B" fix record.
  String _igcBRecord(FlightSample s) {
    final t = s.time.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(t.hour)}${two(t.minute)}${two(t.second)}';

    final lat = _igcLat(s.data.latitude);
    final lon = _igcLon(s.data.longitude);

    // Pressure altitude (baro) and GNSS altitude, 5 digits, zero-padded,
    // clamped to non-negative for the fixed-width field.
    final baro = (s.data.baroAltitude ?? s.data.altitude).round().clamp(
      0,
      99999,
    );
    final gnss = (s.data.gpsAltitude ?? s.data.altitude).round().clamp(
      0,
      99999,
    );
    final baroS = baro.toString().padLeft(5, '0');
    final gnssS = gnss.toString().padLeft(5, '0');

    return 'B$time$lat${lon}A$baroS$gnssS';
  }

  /// Latitude as DDMMmmmN/S (degrees, minutes, thousandths of a minute).
  String _igcLat(double lat) {
    final hemi = lat >= 0 ? 'N' : 'S';
    final a = lat.abs();
    final deg = a.floor();
    final minTh = ((a - deg) * 60 * 1000).round();
    return '${deg.toString().padLeft(2, '0')}'
        '${minTh.toString().padLeft(5, '0')}$hemi';
  }

  /// Longitude as DDDMMmmmE/W.
  String _igcLon(double lon) {
    final hemi = lon >= 0 ? 'E' : 'W';
    final a = lon.abs();
    final deg = a.floor();
    final minTh = ((a - deg) * 60 * 1000).round();
    return '${deg.toString().padLeft(3, '0')}'
        '${minTh.toString().padLeft(5, '0')}$hemi';
  }

  // ── Save + share ──────────────────────────────────────────────────────────

  /// Writes [content] to a temp file named [fileName] and opens the platform
  /// share sheet. Returns the temp file path.
  Future<String> _shareText(
    String content,
    String fileName, {
    String? mimeType,
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, fileName);
    final file = File(path);
    await file.writeAsString(content, flush: true);
    await Share.shareXFiles([
      XFile(path, mimeType: mimeType, name: fileName),
    ], subject: subject);
    return path;
  }

  /// Exports [track] as a `.gpx` file and shares it.
  Future<String> shareGpx(FlightTrack track) {
    return _shareText(
      buildGpx(track),
      '${flightSlug(track)}.gpx',
      mimeType: 'application/gpx+xml',
      subject: 'ParaBeacon flight ${flightSlug(track)}',
    );
  }

  /// Exports [track] as a signed `.igc` file and shares it.
  Future<String> shareIgc(FlightTrack track) {
    return _shareText(
      buildIgc(track),
      '${flightSlug(track)}.igc',
      mimeType: 'text/plain',
      subject: 'ParaBeacon flight ${flightSlug(track)}',
    );
  }

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// Small helper used by callers to decide whether export actions apply.
extension FlightExportability on FlightTrack {
  bool get canExport => hasSamples && samples.any((s) => s.data.hasFix);
}
