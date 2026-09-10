import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'flight_derived_stats.dart';
import 'flight_recorder.dart';

/// Renders a portrait 1080×1920 PNG "share card" summarizing a flight and saves
/// it to the device photo gallery (falling back to the share sheet when the
/// gallery isn't available or permission is denied).
///
/// Self-contained port of the reference project's share-card generator, adapted
/// to this project's [FlightTrack] model. Everything is drawn on a
/// [ui.Canvas] — no widget-to-image capture — so it works headlessly.
class FlightShareCardService {
  FlightShareCardService._();
  static final FlightShareCardService instance = FlightShareCardService._();

  static const int _w = 1080;
  static const int _h = 1920;

  /// Renders the card for [track] and returns the PNG bytes.
  Future<List<int>> renderPng(FlightTrack track) async {
    final stats = FlightDerivedStats.compute(track);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(_w * 1.0, _h * 1.0);

    _paintBackground(canvas, size);
    _paintHeader(canvas, size, track);
    final mapBottom = _paintTrackMap(canvas, size, track);
    _paintStats(canvas, size, track, stats, top: mapBottom + 40);
    _paintFooter(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_w, _h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Renders the card and saves it to the gallery. Returns true on success.
  /// On failure (no gallery / permission), writes a temp file and opens the
  /// share sheet instead, returning false.
  Future<bool> saveToGallery(FlightTrack track) async {
    final bytes = await renderPng(track);
    final dir = await getTemporaryDirectory();
    final fileName = '${flightSlug(track)}.png';
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          await _share(path, fileName);
          return false;
        }
      }
      await Gal.putImage(path, album: 'ParaBeacon');
      return true;
    } catch (_) {
      await _share(path, fileName);
      return false;
    }
  }

  Future<void> _share(String path, String fileName) async {
    await Share.shareXFiles(
      [XFile(path, mimeType: 'image/png', name: fileName)],
      subject: 'ParaBeacon flight',
    );
  }

  // ── Painting ───────────────────────────────────────────────────────────

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = ui.Gradient.linear(
      rect.topCenter,
      rect.bottomCenter,
      const [Color(0xFF0B1E2D), Color(0xFF12384F)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient);
  }

  void _paintHeader(Canvas canvas, Size size, FlightTrack track) {
    _text(
      canvas,
      'ParaBeacon',
      Offset(60, 70),
      fontSize: 44,
      color: const Color(0xFF7FD1FF),
      weight: FontWeight.w700,
    );
    _text(
      canvas,
      _fmtDate(track.startTime),
      Offset(60, 130),
      fontSize: 34,
      color: Colors.white,
      weight: FontWeight.w600,
    );

    final site = [track.takeoffSite, track.landingSite]
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .join('  →  ');
    if (site.isNotEmpty) {
      _text(
        canvas,
        site,
        Offset(60, 178),
        fontSize: 26,
        color: const Color(0xFFB9D4E3),
        maxWidth: _w - 120.0,
      );
    }
  }

  /// Draws the track shape into a framed box and returns its bottom Y.
  double _paintTrackMap(Canvas canvas, Size size, FlightTrack track) {
    const left = 60.0;
    const top = 240.0;
    final boxW = _w - 120.0;
    const boxH = 720.0;
    final rect = Rect.fromLTWH(left, top, boxW, boxH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));

    canvas.drawRRect(rrect, Paint()..color = const Color(0x22000000));
    canvas.save();
    canvas.clipRRect(rrect);

    final samples = track.samples.where((s) => s.data.hasFix).toList();
    if (samples.length >= 2) {
      double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
      for (final s in samples) {
        minLat = math.min(minLat, s.data.latitude);
        maxLat = math.max(maxLat, s.data.latitude);
        minLon = math.min(minLon, s.data.longitude);
        maxLon = math.max(maxLon, s.data.longitude);
      }
      final spanLat = math.max(1e-6, maxLat - minLat);
      final spanLon = math.max(1e-6, maxLon - minLon);
      const pad = 48.0;
      final scale = math.min(
        (boxW - pad * 2) / spanLon,
        (boxH - pad * 2) / spanLat,
      );
      final offX = left + (boxW - spanLon * scale) / 2;
      final offY = top + (boxH - spanLat * scale) / 2;

      Offset project(double lat, double lon) => Offset(
            offX + (lon - minLon) * scale,
            // Flip Y so north is up.
            offY + (maxLat - lat) * scale,
          );

      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final o = project(samples[i].data.latitude, samples[i].data.longitude);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF39D98A),
      );

      final start = project(
          samples.first.data.latitude, samples.first.data.longitude);
      final end =
          project(samples.last.data.latitude, samples.last.data.longitude);
      canvas.drawCircle(start, 12, Paint()..color = const Color(0xFF4ADE80));
      canvas.drawCircle(end, 12, Paint()..color = const Color(0xFFFF6B6B));
    } else {
      _text(
        canvas,
        'No track',
        Offset(left + boxW / 2 - 70, top + boxH / 2 - 20),
        fontSize: 32,
        color: const Color(0x66FFFFFF),
      );
    }

    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x33FFFFFF),
    );
    return top + boxH;
  }

  void _paintStats(
    Canvas canvas,
    Size size,
    FlightTrack track,
    FlightDerivedStats stats, {
    required double top,
  }) {
    final entries = <(String, String)>[
      ('Duration', _fmtDuration(track.duration)),
      ('Track', '${(stats.trackDistanceM / 1000).toStringAsFixed(1)} km'),
      ('XC', '${(stats.xcDistanceM / 1000).toStringAsFixed(1)} km'),
      ('Max alt', '${track.maxAltitude.toStringAsFixed(0)} m'),
      ('Max climb', '${track.maxClimb.toStringAsFixed(1)} m/s'),
      ('Max sink', '${track.maxSink.toStringAsFixed(1)} m/s'),
      if (stats.faiTriangleM > 0)
        ('FAI', '${(stats.faiTriangleM / 1000).toStringAsFixed(1)} km'),
      ('Thermals', '${stats.thermalCount}'),
    ];

    const left = 60.0;
    final cellW = (_w - 120.0) / 2;
    const cellH = 130.0;
    for (var i = 0; i < entries.length; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      final x = left + col * cellW;
      final y = top + row * cellH;
      _text(canvas, entries[i].$1, Offset(x, y),
          fontSize: 26, color: const Color(0xFF8FB6CC), weight: FontWeight.w500);
      _text(canvas, entries[i].$2, Offset(x, y + 34),
          fontSize: 46, color: Colors.white, weight: FontWeight.w700);
    }

    // Equipment line, if present.
    if (track.hasEquipment) {
      final rows = ((entries.length + 1) ~/ 2);
      final ey = top + rows * cellH + 12;
      final equip = [track.gliderName, track.harnessName, track.helmetName]
          .where((e) => e != null && e.isNotEmpty)
          .cast<String>()
          .join('  ·  ');
      _text(canvas, equip, Offset(left, ey),
          fontSize: 26, color: const Color(0xFFB9D4E3), maxWidth: _w - 120.0);
    }
  }

  void _paintFooter(Canvas canvas, Size size) {
    _text(
      canvas,
      'Recorded with ParaBeacon',
      Offset(60, _h - 80.0),
      fontSize: 24,
      color: const Color(0x88FFFFFF),
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
    FontWeight weight = FontWeight.normal,
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    );
    tp.layout(maxWidth: maxWidth ?? (_w - offset.dx - 40));
    tp.paint(canvas, offset);
  }

  static String _fmtDate(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}  ${two(t.hour)}:${two(t.minute)}';
  }

  static String _fmtDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${h}h ${two(m)}m' : '${m}m ${two(s)}s';
  }
}
