import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/aircraft_l10n.dart';
import '../l10n/app_localizations.dart';
import 'flight_derived_stats.dart';
import 'flight_details_settings.dart';
import 'flight_file_output_service.dart';
import 'flight_recorder.dart';
import 'gcj02.dart';
import 'map_source.dart';
import 'map_tile_cache.dart';
import 'share_card_settings.dart';

/// Renders a compact portrait PNG "share card" sized for a mobile screen and
/// saves it to the device photo gallery (falling back to the share sheet when the
/// gallery isn't available or permission is denied).
///
/// Self-contained port of the reference project's share-card generator, adapted
/// to this project's [FlightTrack] model. Everything is drawn on a
/// [ui.Canvas] — no widget-to-image capture — so it works headlessly.
class FlightShareCardService {
  FlightShareCardService._();
  static final FlightShareCardService instance = FlightShareCardService._();

  static const int _w = 1080;
  static const int _minHeight = 1920;

  /// Renders the card for [track] and returns the PNG bytes. All on-card text
  /// is localized through [l10n], so the card follows the app's current
  /// language (e.g. Chinese when the app is set to Chinese).
  Future<List<int>> renderPng(
    FlightTrack track,
    AppLocalizations l10n, {
    required ColorScheme colorScheme,
  }) async {
    final settings = FlightDetailsSettings.instance;
    final stats = FlightDerivedStats.compute(
      track,
      filterVarioOutliers: settings.filterVarioOutliers,
      madMultiplier: settings.madMultiplier,
      windowSeconds: settings.windowSeconds,
      maximumVerticalSpeedMs: settings.maximumVerticalSpeedMs,
    );
    final cardHeight = math
        .max(
          _minHeight,
          627 + _estimatedStatsHeight(track, stats, l10n).ceil() + 100,
        )
        .ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(_w.toDouble(), cardHeight.toDouble());

    _paintBackground(canvas, size, colorScheme);
    _paintHeader(canvas, size, track, colorScheme);
    final mapBottom = await _paintTrackMap(
      canvas,
      size,
      track,
      l10n,
      colorScheme,
    );
    final profileBottom = _paintAltitudeProfile(
      canvas,
      size,
      track,
      l10n,
      top: mapBottom + 12,
      colorScheme: colorScheme,
    );
    _paintStats(
      canvas,
      size,
      track,
      stats,
      l10n,
      top: profileBottom + 12,
      colorScheme: colorScheme,
    );
    _paintFooter(canvas, size, track, l10n, colorScheme);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_w, cardHeight);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Renders the card and saves it to the gallery. Returns true on success.
  /// On failure (no gallery / permission), writes a temp file and opens the
  /// share sheet instead, returning false.
  Future<bool> saveToGallery(
    FlightTrack track,
    AppLocalizations l10n, {
    required ColorScheme colorScheme,
  }) async {
    final bytes = await renderPng(track, l10n, colorScheme: colorScheme);
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

  Future<String?> saveToDownloads(
    FlightTrack track,
    AppLocalizations l10n, {
    required ColorScheme colorScheme,
  }) async {
    final bytes = await renderPng(track, l10n, colorScheme: colorScheme);
    return FlightFileOutputService.instance.saveToDownloads(
      bytes: bytes,
      fileName: '${flightSlug(track)}.png',
      mimeType: 'image/png',
    );
  }

  Future<String> shareCard(
    FlightTrack track,
    AppLocalizations l10n, {
    required ColorScheme colorScheme,
  }) async {
    final bytes = await renderPng(track, l10n, colorScheme: colorScheme);
    final fileName = '${flightSlug(track)}.png';
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    await _share(path, fileName);
    return path;
  }

  Future<void> _share(String path, String fileName) async {
    await Share.shareXFiles([
      XFile(path, mimeType: 'image/png', name: fileName),
    ], subject: 'ParaBeacon flight');
  }

  // ── Painting ───────────────────────────────────────────────────────────

  void _paintBackground(Canvas canvas, Size size, ColorScheme colorScheme) {
    if (ShareCardSettings.instance.flatDesign) {
      canvas.drawRect(Offset.zero & size, Paint()..color = colorScheme.surface);
      return;
    }
    final isDark = colorScheme.brightness == Brightness.dark;
    final accentMix = isDark ? 0.3 : 0.13;
    final secondaryMix = isDark ? 0.2 : 0.09;
    final glowAlpha = isDark ? 0.24 : 0.14;
    final rect = Offset.zero & size;
    final gradient = ui.Gradient.linear(
      rect.topLeft,
      Offset(size.width * 0.32, size.height),
      [
        Color.lerp(colorScheme.surface, colorScheme.primary, accentMix)!,
        Color.lerp(colorScheme.surface, colorScheme.surfaceContainerLow, 0.55)!,
        Color.lerp(
          colorScheme.surfaceContainer,
          colorScheme.secondary,
          secondaryMix,
        )!,
      ],
      const [0.0, 0.52, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.94, size.height * 0.04),
          size.width * 1.1,
          [
            colorScheme.primary.withValues(alpha: glowAlpha),
            colorScheme.primary.withValues(alpha: 0),
          ],
          const [0, 1],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.88, size.height * 0.48),
          size.width * 0.72,
          [
            colorScheme.secondary.withValues(alpha: glowAlpha * 0.65),
            colorScheme.secondary.withValues(alpha: 0),
          ],
          const [0, 1],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.04, size.height * 0.98),
          size.width * 0.85,
          [
            colorScheme.tertiary.withValues(alpha: glowAlpha * 0.55),
            colorScheme.tertiary.withValues(alpha: 0),
          ],
          const [0, 1],
        ),
    );
  }

  void _paintSurface(
    Canvas canvas,
    RRect rrect,
    ColorScheme colorScheme, {
    bool elevated = false,
    Color? accentColor,
  }) {
    final rect = rrect.outerRect;
    final startColor = elevated
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;
    final endColor = elevated
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainer;
    final isDark = colorScheme.brightness == Brightness.dark;
    final tintAmount = isDark ? 0.07 : 0.035;
    final glassAlpha = isDark ? 0.82 : 0.76;
    final tintedStart = accentColor == null
        ? startColor
        : Color.lerp(startColor, accentColor, tintAmount)!;
    final tintedEnd = accentColor == null
        ? endColor
        : Color.lerp(endColor, accentColor, tintAmount * 0.65)!;
    final borderColor = accentColor == null
        ? colorScheme.outlineVariant
        : Color.lerp(colorScheme.outlineVariant, accentColor, 0.18)!;
    if (ShareCardSettings.instance.flatDesign) {
      final flatTinted = accentColor == null
          ? startColor
          : Color.lerp(startColor, accentColor, isDark ? 0.14 : 0.08)!;
      canvas.drawRRect(rrect, Paint()..color = flatTinted);
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = borderColor,
      );
      return;
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
          tintedStart.withValues(alpha: glassAlpha),
          tintedEnd.withValues(alpha: glassAlpha * 0.9),
        ]),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.center, [
          Colors.white.withValues(alpha: isDark ? 0.12 : 0.2),
          Colors.white.withValues(alpha: 0),
        ]),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = borderColor.withValues(alpha: 0.62),
    );
    final insetRect = rect.deflate(2);
    final inset = RRect.fromRectAndRadius(
      insetRect,
      Radius.circular(rrect.tlRadiusX - 2),
    );
    canvas.drawRRect(
      inset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: isDark ? 0.12 : 0.34),
    );
  }

  void _paintHeader(
    Canvas canvas,
    Size size,
    FlightTrack track,
    ColorScheme colorScheme,
  ) {
    _text(
      canvas,
      'ParaBeacon',
      Offset(60, 64),
      fontSize: 44,
      color: colorScheme.primary,
      weight: FontWeight.w700,
    );

    // Full date plus the first→last tracklog clock range.
    final start = track.firstRecordedTime;
    final end = track.endTime != null ? track.lastRecordedTime : null;
    final when = end != null
        ? '${_fmtDateOnly(start)}  ·  ${_fmtClock(start)} – ${_fmtClock(end)}'
        : '${_fmtDateOnly(start)}  ·  ${_fmtClock(start)}';
    _text(
      canvas,
      when,
      Offset(60, 122),
      fontSize: 32,
      color: colorScheme.onSurface,
      weight: FontWeight.w600,
    );

    final site = [
      track.takeoffSite,
      track.landingSite,
    ].where((e) => e != null && e.isNotEmpty).cast<String>().join('  →  ');
    if (site.isNotEmpty) {
      _text(
        canvas,
        site,
        Offset(60, 170),
        fontSize: 26,
        color: colorScheme.onSurfaceVariant,
        maxWidth: _w - 120.0,
      );
    }
  }

  /// Draws the track shape into a framed box and returns its bottom Y.
  Future<double> _paintTrackMap(
    Canvas canvas,
    Size size,
    FlightTrack track,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) async {
    const left = 60.0;
    const top = 210.0;
    final boxW = _w - 120.0;
    const boxH = 290.0;
    final rect = Rect.fromLTWH(left, top, boxW, boxH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));

    _paintSurface(canvas, rrect, colorScheme);
    canvas.save();
    canvas.clipRRect(rrect);
    final samples = track.samples.where((s) => s.data.hasFix).toList();
    Offset? amapCenter;
    double? amapScale;
    var hasSatelliteTiles = false;
    if (ShareCardSettings.instance.amapSatelliteBackground &&
        samples.length >= 2) {
      final mapPoints = samples
          .map(
            (sample) => _amapWorldCoordinate(
              sample.data.latitude,
              sample.data.longitude,
            ),
          )
          .toList();
      var minX = double.infinity;
      var maxX = double.negativeInfinity;
      var minY = double.infinity;
      var maxY = double.negativeInfinity;
      for (final point in mapPoints) {
        minX = math.min(minX, point.dx);
        maxX = math.max(maxX, point.dx);
        minY = math.min(minY, point.dy);
        maxY = math.max(maxY, point.dy);
      }
      final spanX = math.max(1e-9, maxX - minX);
      final spanY = math.max(1e-9, maxY - minY);
      final satelliteScale = math.min((boxW - 96) / spanX, (boxH - 96) / spanY);
      final satelliteCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
      amapScale = satelliteScale;
      amapCenter = satelliteCenter;
      hasSatelliteTiles = await _paintAmapSatelliteTiles(
        canvas,
        rect,
        center: satelliteCenter,
        scale: satelliteScale,
      );
      if (hasSatelliteTiles) {
        canvas.drawRect(
          rect,
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );
      }
    }
    final mapForeground = hasSatelliteTiles
        ? Colors.white
        : colorScheme.onSurfaceVariant;
    final gridPaint = Paint()
      ..color = hasSatelliteTiles
          ? Colors.white.withValues(alpha: 0.18)
          : colorScheme.outlineVariant.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final x = left + boxW * i / 5;
      final y = top + boxH * i / 5;
      canvas.drawLine(Offset(x, top), Offset(x, top + boxH), gridPaint);
      canvas.drawLine(Offset(left, y), Offset(left + boxW, y), gridPaint);
    }
    _text(
      canvas,
      l10n.flightReportTrackMap.toUpperCase(),
      Offset(left + 24, top + 18),
      fontSize: 20,
      color: mapForeground,
      weight: FontWeight.w700,
    );

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

      Offset project(double lat, double lon) {
        final center = amapCenter;
        final satelliteScale = amapScale;
        if (center != null && satelliteScale != null) {
          final point = _amapWorldCoordinate(lat, lon);
          return Offset(
            rect.center.dx + (point.dx - center.dx) * satelliteScale,
            rect.center.dy + (point.dy - center.dy) * satelliteScale,
          );
        }
        return Offset(
          offX + (lon - minLon) * scale,
          offY + (maxLat - lat) * scale,
        );
      }

      // Colour the track by altitude so climbs/descents read at a glance.
      double minAlt = double.infinity, maxAlt = double.negativeInfinity;
      for (final s in samples) {
        minAlt = math.min(minAlt, s.data.altitude);
        maxAlt = math.max(maxAlt, s.data.altitude);
      }
      final altSpan = math.max(1.0, maxAlt - minAlt);

      final haloPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colorScheme.primary.withValues(alpha: 0.3);
      final segPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (var i = 1; i < samples.length; i++) {
        final a = project(
          samples[i - 1].data.latitude,
          samples[i - 1].data.longitude,
        );
        final b = project(samples[i].data.latitude, samples[i].data.longitude);
        final t = ((samples[i].data.altitude - minAlt) / altSpan).clamp(
          0.0,
          1.0,
        );
        canvas.drawLine(a, b, haloPaint);
        segPaint.color = _altitudeColor(t);
        canvas.drawLine(a, b, segPaint);
      }

      final start = project(
        samples.first.data.latitude,
        samples.first.data.longitude,
      );
      final end = project(
        samples.last.data.latitude,
        samples.last.data.longitude,
      );
      canvas.drawCircle(start, 13, Paint()..color = colorScheme.secondary);
      canvas.drawCircle(end, 13, Paint()..color = colorScheme.error);
      _text(
        canvas,
        l10n.flightDetailTakeoff,
        Offset(start.dx + 18, start.dy - 16),
        fontSize: 22,
        color: mapForeground,
        weight: FontWeight.w600,
      );
      _text(
        canvas,
        l10n.flightDetailLanding,
        Offset(end.dx + 18, end.dy - 16),
        fontSize: 22,
        color: mapForeground,
        weight: FontWeight.w600,
      );
    } else {
      _text(
        canvas,
        l10n.flightShareCardNoTrack,
        Offset(left + boxW / 2 - 70, top + boxH / 2 - 20),
        fontSize: 32,
        color: mapForeground,
      );
    }
    if (hasSatelliteTiles) {
      final attributionRect = Rect.fromLTWH(
        left + boxW - 150,
        top + 14,
        130,
        30,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(attributionRect, const Radius.circular(8)),
        Paint()..color = Colors.black.withValues(alpha: 0.56),
      );
      _text(
        canvas,
        '© AutoNavi',
        Offset(attributionRect.left + 9, attributionRect.top + 5),
        fontSize: 16,
        color: Colors.white,
        weight: FontWeight.w600,
      );
    }

    canvas.restore();
    return top + boxH;
  }

  Offset _amapWorldCoordinate(double latitude, double longitude) {
    final gcj = Gcj02.wgsToGcj(latitude, longitude);
    final lat = gcj[0].clamp(-85.05112878, 85.05112878) * math.pi / 180;
    final lon = gcj[1].clamp(-180.0, 180.0);
    final sinLatitude = math.sin(lat);
    final y =
        0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi);
    return Offset((lon + 180) / 360, y.clamp(0.0, 1.0));
  }

  Future<bool> _paintAmapSatelliteTiles(
    Canvas canvas,
    Rect rect, {
    required Offset center,
    required double scale,
  }) async {
    final source = MapSourceCatalog.byId('amap-sat');
    final zoom = (math.log(scale / 256) / math.ln2)
        .floor()
        .clamp(0, source.maxZoom.toInt())
        .toInt();
    final tileCount = 1 << zoom;
    final west = center.dx - rect.width / (2 * scale);
    final east = center.dx + rect.width / (2 * scale);
    final north = center.dy - rect.height / (2 * scale);
    final south = center.dy + rect.height / (2 * scale);
    final minX = (west * tileCount).floor().clamp(0, tileCount - 1).toInt();
    final maxX = (east * tileCount).floor().clamp(0, tileCount - 1).toInt();
    final minY = (north * tileCount).floor().clamp(0, tileCount - 1).toInt();
    final maxY = (south * tileCount).floor().clamp(0, tileCount - 1).toInt();
    if ((maxX - minX + 1) * (maxY - minY + 1) > 64) return false;

    final coordinates = [
      for (var x = minX; x <= maxX; x++)
        for (var y = minY; y <= maxY; y++) (x, y),
    ];
    final tiles = await Future.wait(
      coordinates.map((coordinate) async {
        final (x, y) = coordinate;
        final url = source.url!
            .replaceAll('{z}', '$zoom')
            .replaceAll('{x}', '$x')
            .replaceAll('{y}', '$y');
        try {
          final response = await MapTileCacheService.instance.httpClient
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 8));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            return null;
          }
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          try {
            final frame = await codec.getNextFrame();
            return (x: x, y: y, image: frame.image);
          } finally {
            codec.dispose();
          }
        } catch (_) {
          return null;
        }
      }),
    );

    var paintedAny = false;
    final tileSize = scale / tileCount;
    for (final tile in tiles) {
      if (tile == null) continue;
      final destination = Rect.fromLTWH(
        rect.center.dx + (tile.x / tileCount - center.dx) * scale,
        rect.center.dy + (tile.y / tileCount - center.dy) * scale,
        tileSize,
        tileSize,
      );
      try {
        canvas.drawImageRect(
          tile.image,
          Rect.fromLTWH(
            0,
            0,
            tile.image.width.toDouble(),
            tile.image.height.toDouble(),
          ),
          destination,
          Paint()..filterQuality = FilterQuality.medium,
        );
        paintedAny = true;
      } finally {
        tile.image.dispose();
      }
    }
    return paintedAny;
  }

  /// Draws an altitude-over-time profile (filled area chart) into a framed box
  /// and returns its bottom Y. Falls back to just the frame when there isn't
  /// enough per-sample data to plot.
  double _paintAltitudeProfile(
    Canvas canvas,
    Size size,
    FlightTrack track,
    AppLocalizations l10n, {
    required double top,
    required ColorScheme colorScheme,
  }) {
    const left = 60.0;
    final boxW = _w - 120.0;
    const boxH = 124.0;
    final rect = Rect.fromLTWH(left, top, boxW, boxH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));

    _paintSurface(canvas, rrect, colorScheme);

    _text(
      canvas,
      l10n.flightReportAltitudeProfile.toUpperCase(),
      Offset(left + 20, top + 10),
      fontSize: 18,
      color: colorScheme.onSurfaceVariant,
      weight: FontWeight.w600,
    );

    final samples = track.samples
        .where((s) => s.data.altitude.isFinite)
        .toList();
    if (samples.length >= 2) {
      final startMs = samples.first.time.millisecondsSinceEpoch;
      final spanMs = math.max(
        1,
        samples.last.time.millisecondsSinceEpoch - startMs,
      );
      double minAlt = double.infinity, maxAlt = double.negativeInfinity;
      for (final s in samples) {
        minAlt = math.min(minAlt, s.data.altitude);
        maxAlt = math.max(maxAlt, s.data.altitude);
      }
      final altSpan = math.max(1.0, maxAlt - minAlt);

      const padX = 40.0;
      const padTop = 40.0;
      const padBottom = 24.0;
      final plotLeft = left + padX;
      final plotRight = left + boxW - padX;
      final plotTop = top + padTop;
      final plotBottom = top + boxH - padBottom;
      final plotW = plotRight - plotLeft;
      final plotH = plotBottom - plotTop;

      Offset project(int ms, double alt) => Offset(
        plotLeft + (ms - startMs) / spanMs * plotW,
        plotBottom - (alt - minAlt) / altSpan * plotH,
      );

      canvas.save();
      canvas.clipRRect(rrect);
      final gridPaint = Paint()
        ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (var i = 0; i <= 3; i++) {
        final y = plotTop + plotH * i / 3;
        canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      }

      final line = Path();
      for (var i = 0; i < samples.length; i++) {
        final o = project(
          samples[i].time.millisecondsSinceEpoch,
          samples[i].data.altitude,
        );
        if (i == 0) {
          line.moveTo(o.dx, o.dy);
        } else {
          line.lineTo(o.dx, o.dy);
        }
      }

      final fill = Path.from(line)
        ..lineTo(plotRight, plotBottom)
        ..lineTo(plotLeft, plotBottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(plotLeft, plotTop),
            Offset(plotLeft, plotBottom),
            [
              colorScheme.primary.withValues(alpha: 0.3),
              colorScheme.primary.withValues(alpha: 0),
            ],
          ),
      );
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = colorScheme.primary,
      );

      canvas.restore();

      _text(
        canvas,
        '${maxAlt.toStringAsFixed(0)} m',
        Offset(plotRight - 90, plotTop - 20),
        fontSize: 16,
        color: colorScheme.onSurfaceVariant,
      );
      _text(
        canvas,
        '${minAlt.toStringAsFixed(0)} m',
        Offset(plotLeft, plotBottom + 2),
        fontSize: 16,
        color: colorScheme.onSurfaceVariant,
      );
    } else {
      _text(
        canvas,
        l10n.flightShareCardNoAltitude,
        Offset(left + boxW / 2 - 110, top + boxH / 2 - 10),
        fontSize: 26,
        color: colorScheme.onSurfaceVariant,
      );
    }

    return top + boxH;
  }

  /// Maps a normalized altitude [t] in 0..1 to a cool→warm colour ramp
  /// (blue → cyan → green → amber → red).
  Color _altitudeColor(double t) {
    const stops = <Color>[
      Color(0xFF3B82F6), // low  – blue
      Color(0xFF22D3EE), // cyan
      Color(0xFF39D98A), // green
      Color(0xFFFACC15), // amber
      Color(0xFFF97316), // high – orange
    ];
    final x = t.clamp(0.0, 1.0) * (stops.length - 1);
    final i = x.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[i], stops[i + 1], x - i)!;
  }

  /// Paints all available Flight details, grouped into the same categories as
  /// the detail screen. Returns the content bottom so the footer stays clear.
  double _paintStats(
    Canvas canvas,
    Size size,
    FlightTrack track,
    FlightDerivedStats stats,
    AppLocalizations l10n, {
    required double top,
    required ColorScheme colorScheme,
  }) {
    String km(double value) => '${(value / 1000).toStringAsFixed(2)} km';
    String m(double value) => '${value.toStringAsFixed(0)} m';
    String ms(double value) => '${value.toStringAsFixed(1)} m/s';
    String kph(double value) => '${value.toStringAsFixed(1)} km/h';

    final start = track.firstRecordedTime;
    final end = track.endTime != null ? track.lastRecordedTime : null;
    var y = _paintMetricSection(
      canvas,
      l10n.flightDetailFlight,
      [
        (l10n.flightReportDate, _fmtDateOnly(start)),
        (l10n.flightDetailStart, '${_fmtDateOnly(start)} ${_fmtTime(start)}'),
        (
          l10n.flightDetailEnd,
          end != null ? '${_fmtDateOnly(end)} ${_fmtTime(end)}' : '—',
        ),
        (l10n.flightDetailDuration, _fmtDuration(track.duration)),
        (l10n.flightDetailSamples, '${track.pointCount}'),
        if (track.pilotName?.isNotEmpty ?? false)
          (l10n.flightDetailPilot, track.pilotName!),
      ],
      left: 60,
      top: top,
      colorScheme: colorScheme,
      accentColor: colorScheme.primary,
    );

    final takeoff = _endpointText(
      track.takeoffSite,
      track.takeoffLatitude,
      track.takeoffLongitude,
    );
    final landing = _endpointText(
      track.landingSite,
      track.landingLatitude,
      track.landingLongitude,
    );
    y = _paintMetricSection(
      canvas,
      l10n.flightDetailRoute,
      [
        (l10n.flightDetailDistance, km(track.distanceM)),
        if (takeoff != null) (l10n.flightDetailTakeoff, takeoff),
        if (track.takeoffAltitude != null)
          (l10n.flightDetailTakeoffAltitude, m(track.takeoffAltitude!)),
        if (landing != null) (l10n.flightDetailLanding, landing),
        if (track.landingAltitude != null)
          (l10n.flightDetailLandingAltitude, m(track.landingAltitude!)),
      ],
      left: 60,
      top: y,
      colorScheme: colorScheme,
      accentColor: colorScheme.secondary,
    );

    y = _paintMetricSection(
      canvas,
      l10n.flightDetailAltitude,
      [
        (l10n.flightDetailMaxAltitude, m(track.maxAltitude)),
        (l10n.flightDetailMinAltitude, m(track.minAltitude)),
        (l10n.flightDetailMaxClimb, ms(track.maxClimb)),
        (l10n.flightDetailMaxSink, ms(track.maxSink)),
        if (!track.hasSamples && track.maxAltGainM != null)
          (l10n.flightDetailMaxAltGain, m(track.maxAltGainM!)),
        if (!track.hasSamples && track.elevationDropM != null)
          (l10n.flightDetailElevationDrop, m(track.elevationDropM!)),
      ],
      left: 60,
      top: y,
      colorScheme: colorScheme,
      accentColor: colorScheme.tertiary,
    );

    if (track.hasSamples) {
      y = _paintMetricSection(
        canvas,
        l10n.flightDetailRouteMetrics,
        [
          (l10n.flightDetailStraightDistance, km(stats.straightDistanceM)),
          if (stats.threeTurnpointM > 0)
            (
              l10n.flightDetailThreeTurnpoints,
              _routeText(stats.threeTurnpointM, stats.threeTurnpointLegsM, km),
            ),
          if (stats.faiTriangleM > 0)
            (
              l10n.flightDetailFaiTriangle,
              _triangleText(
                l10n,
                stats.faiTriangleM,
                stats.faiTriangleLegsM,
                stats.faiClosingM,
                stats.faiClosed,
                km,
              ),
            ),
          if (stats.flatTriangleM > 0)
            (
              l10n.flightDetailFlatTriangle,
              _triangleText(
                l10n,
                stats.flatTriangleM,
                stats.flatTriangleLegsM,
                stats.flatClosingM,
                stats.flatClosed,
                km,
              ),
            ),
          (l10n.flightDetailMaxFromStart, km(stats.maxDistanceFromStartM)),
          (
            l10n.flightDetailTrackEfficiency,
            '${(stats.trackEfficiency * 100).toStringAsFixed(0)} %',
          ),
        ],
        left: 60,
        top: y,
        colorScheme: colorScheme,
      );
      y = _paintMetricSection(
        canvas,
        l10n.flightDetailSpeedGlide,
        [
          (l10n.flightDetailAvgGroundSpeed, kph(stats.avgGroundSpeedKph)),
          (l10n.flightDetailAvgCruiseSpeed, kph(stats.avgCruiseSpeedKph)),
          (l10n.flightDetailMaxSpeed, kph(stats.maxSpeedKph)),
          (
            l10n.flightDetailAvgGlideRatio,
            stats.avgGlideRatio > 0
                ? stats.avgGlideRatio.toStringAsFixed(1)
                : '—',
          ),
        ],
        left: 60,
        top: y,
        colorScheme: colorScheme,
        accentColor: colorScheme.secondary,
      );
      y = _paintMetricSection(
        canvas,
        l10n.flightDetailClimbAltitude,
        [
          (l10n.flightDetailAvgClimb, ms(stats.avgClimbMs)),
          (l10n.flightDetailAvgSink, ms(stats.avgSinkMs)),
          (l10n.flightDetailThermals, '${stats.thermalCount}'),
          (l10n.flightDetailAltGained, m(stats.altitudeGainedM)),
          (l10n.flightDetailAltLost, m(stats.altitudeLostM)),
          (
            l10n.flightDetailMaxAltGain,
            m(track.maxAltGainM ?? stats.maxAltGainM),
          ),
          (
            l10n.flightDetailElevationDrop,
            m(track.elevationDropM ?? stats.elevationDropM),
          ),
        ],
        left: 60,
        top: y,
        colorScheme: colorScheme,
        accentColor: colorScheme.tertiary,
      );
      y = _paintMetricSection(
        canvas,
        l10n.flightDetailTimeBreakdown,
        [
          (l10n.flightDetailClimbTime, _fmtDuration(stats.climbTime)),
          (l10n.flightDetailGlideTime, _fmtDuration(stats.glideTime)),
          (l10n.flightDetailSinkTime, _fmtDuration(stats.sinkTime)),
          (l10n.flightDetailMovingTime, _fmtDuration(stats.movingTime)),
        ],
        left: 60,
        top: y,
        colorScheme: colorScheme,
      );
    }

    final aircraft = <(String, String)>[
      if (track.aircraftName?.isNotEmpty ?? false)
        (l10n.flightDetailAircraftName, track.aircraftName!),
      if (track.aircraftManufacturer?.isNotEmpty ?? false)
        (l10n.flightDetailAircraftManufacturer, track.aircraftManufacturer!),
      if (track.aircraftModel?.isNotEmpty ?? false)
        (l10n.flightDetailAircraftModel, track.aircraftModel!),
      if (track.aircraftFaiClass?.isNotEmpty ?? false)
        (
          l10n.flightDetailAircraftClass,
          aircraftFaiClassLabel(l10n, track.aircraftFaiClass!),
        ),
      if (!const {'3', '11', '12'}.contains(track.aircraftFaiClass?.trim()) &&
          (track.aircraftCategory?.isNotEmpty ?? false))
        (l10n.flightDetailAircraftCategory, track.aircraftCategory!),
      if (track.aircraftTandem != null)
        (
          l10n.flightDetailAircraftTandem,
          track.aircraftTandem!
              ? l10n.aircraftTandemYes
              : l10n.aircraftTandemNo,
        ),
      if (track.aircraftEngineType?.isNotEmpty ?? false)
        (l10n.flightDetailAircraftEngine, track.aircraftEngineType!),
      if (track.aircraftTrimSpeedKmh != null)
        (
          l10n.flightDetailAircraftTrimSpeed,
          '${track.aircraftTrimSpeedKmh!.toStringAsFixed(1)} km/h',
        ),
      if (track.aircraftGoalGlideRatio != null)
        (
          l10n.flightDetailAircraftGlideRatio,
          track.aircraftGoalGlideRatio!.toStringAsFixed(2),
        ),
    ];
    if (aircraft.isNotEmpty) {
      y = _paintMetricSection(
        canvas,
        l10n.flightDetailAircraft,
        aircraft,
        left: 60,
        top: y,
        colorScheme: colorScheme,
      );
    }

    final telemetry = _telemetryEntries(track, l10n);
    if (telemetry.isNotEmpty) {
      y = _paintMetricSection(
        canvas,
        l10n.dataMonitorTitle,
        telemetry,
        left: 60,
        top: y,
        colorScheme: colorScheme,
      );
    }
    return y;
  }

  List<(String, String)> _telemetryEntries(
    FlightTrack track,
    AppLocalizations l10n,
  ) {
    final data = track.samples.map((sample) => sample.data).toList();
    List<double> doubles(Iterable<double?> source) =>
        source.whereType<double>().where((value) => value.isFinite).toList();
    List<int> integers(Iterable<int?> source) =>
        source.whereType<int>().toList();
    String range(List<num> values, String unit, {int decimals = 0}) {
      if (values.isEmpty) return '';
      var min = values.first;
      var max = values.first;
      for (final value in values.skip(1)) {
        if (value < min) min = value;
        if (value > max) max = value;
      }
      final format = (num value) => value.toStringAsFixed(decimals);
      return min == max
          ? '${format(min)} $unit'
          : '${format(min)}-${format(max)} $unit';
    }

    final wind = data
        .map((value) => value.windSpeed)
        .where((value) => value.isFinite && value > 0)
        .toList();
    final accuracy = doubles(data.map((value) => value.gpsAccuracy));
    final temperature = doubles(data.map((value) => value.temperature));
    final pressure = doubles(data.map((value) => value.pressure));
    final heartRate = integers(data.map((value) => value.heartRate));
    final battery = integers(data.map((value) => value.battery));
    final satellites = integers(data.map((value) => value.satellites));
    final rows = <(String, String)>[
      if (wind.isNotEmpty)
        (
          l10n.dataMonitorWindSpeed,
          '${(wind.reduce((a, b) => a + b) / wind.length).toStringAsFixed(1)} km/h',
        ),
      if (temperature.isNotEmpty)
        (l10n.dataMonitorTemperature, range(temperature, '°C', decimals: 1)),
      if (pressure.isNotEmpty)
        (l10n.dataMonitorPressure, range(pressure, 'hPa', decimals: 0)),
      if (accuracy.isNotEmpty)
        (
          l10n.dataMonitorGpsAccuracy,
          '${(accuracy.reduce((a, b) => a + b) / accuracy.length).toStringAsFixed(0)} m',
        ),
      if (satellites.isNotEmpty)
        (l10n.dataMonitorSatellites, '${satellites.reduce(math.max)}'),
      if (battery.isNotEmpty) (l10n.dataMonitorBattery, range(battery, '%')),
      if (heartRate.isNotEmpty)
        (l10n.dataMonitorHeartRate, range(heartRate, 'bpm')),
    ];
    return rows;
  }

  double _estimatedStatsHeight(
    FlightTrack track,
    FlightDerivedStats stats,
    AppLocalizations l10n,
  ) {
    final takeoff = _endpointText(
      track.takeoffSite,
      track.takeoffLatitude,
      track.takeoffLongitude,
    );
    final landing = _endpointText(
      track.landingSite,
      track.landingLatitude,
      track.landingLongitude,
    );
    final counts = <int>[
      5 + (track.pilotName?.isNotEmpty ?? false ? 1 : 0),
      1 +
          (takeoff == null ? 0 : 1) +
          (track.takeoffAltitude == null ? 0 : 1) +
          (landing == null ? 0 : 1) +
          (track.landingAltitude == null ? 0 : 1),
      4 +
          (!track.hasSamples && track.maxAltGainM != null ? 1 : 0) +
          (!track.hasSamples && track.elevationDropM != null ? 1 : 0),
    ];
    if (track.hasSamples) {
      counts.add(
        3 +
            (stats.threeTurnpointM > 0 ? 1 : 0) +
            (stats.faiTriangleM > 0 ? 1 : 0) +
            (stats.flatTriangleM > 0 ? 1 : 0),
      );
      counts.addAll([4, 7, 4]);
    }
    final aircraftCount = [
      track.aircraftName?.isNotEmpty ?? false,
      track.aircraftManufacturer?.isNotEmpty ?? false,
      track.aircraftModel?.isNotEmpty ?? false,
      track.aircraftFaiClass?.isNotEmpty ?? false,
      !const {'3', '11', '12'}.contains(track.aircraftFaiClass?.trim()) &&
          (track.aircraftCategory?.isNotEmpty ?? false),
      track.aircraftTandem != null,
      track.aircraftEngineType?.isNotEmpty ?? false,
      track.aircraftTrimSpeedKmh != null,
      track.aircraftGoalGlideRatio != null,
    ].where((value) => value).length;
    if (aircraftCount > 0) counts.add(aircraftCount);
    final telemetryCount = _telemetryEntries(track, l10n).length;
    if (telemetryCount > 0) counts.add(telemetryCount);
    return counts.fold<double>(
      0,
      (height, count) => height + 33 + ((count + 3) ~/ 4) * 56,
    );
  }

  double _paintMetricSection(
    Canvas canvas,
    String label,
    List<(String, String)> entries, {
    required double left,
    required double top,
    required ColorScheme colorScheme,
    Color? accentColor,
  }) {
    if (entries.isEmpty) return top;
    final sectionAccent = Color.lerp(
      colorScheme.primary,
      accentColor ?? colorScheme.primary,
      0.26,
    )!;
    const columns = 4;
    const rowStride = 56.0;
    const headerHeight = 28.0;
    const sectionGap = 5.0;
    final sectionWidth = _w - 120.0;
    final cellWidth = sectionWidth / columns;
    final rowCount = (entries.length + columns - 1) ~/ columns;
    final sectionHeight = headerHeight + rowCount * rowStride;
    final sectionRect = Rect.fromLTWH(left, top, sectionWidth, sectionHeight);
    final section = RRect.fromRectAndRadius(
      sectionRect,
      const Radius.circular(18),
    );
    _paintSurface(
      canvas,
      section,
      colorScheme,
      elevated: true,
      accentColor: sectionAccent,
    );
    _text(
      canvas,
      label.toUpperCase(),
      Offset(left + 14, top + 4),
      fontSize: 18,
      color: sectionAccent,
      weight: FontWeight.w700,
    );

    final dividerStart = Offset(left + 12, top + 22);
    final dividerEnd = Offset(left + sectionWidth - 12, top + 22);
    canvas.drawLine(
      dividerStart,
      dividerEnd,
      Paint()
        ..shader = ui.Gradient.linear(
          dividerStart,
          dividerEnd,
          [
            sectionAccent.withValues(alpha: 0.85),
            colorScheme.secondary.withValues(alpha: 0.2),
            colorScheme.tertiary.withValues(alpha: 0.05),
          ],
          const [0, 0.58, 1],
        )
        ..strokeWidth = 1.5,
    );

    final fieldDividerPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var row = 1; row < rowCount; row++) {
      final y = top + headerHeight + row * rowStride;
      canvas.drawLine(
        Offset(left + 12, y),
        Offset(left + sectionWidth - 12, y),
        fieldDividerPaint,
      );
    }
    for (var i = 0; i < entries.length; i++) {
      final column = i % columns;
      final row = i ~/ columns;
      final x = left + column * cellWidth;
      final y = top + headerHeight + row * rowStride;
      if (column > 0) {
        canvas.drawLine(
          Offset(x, y + 5),
          Offset(x, y + rowStride - 5),
          fieldDividerPaint,
        );
      }
      _text(
        canvas,
        entries[i].$1,
        Offset(x + 10, y + 3),
        fontSize: 14,
        color: colorScheme.onSurfaceVariant,
        weight: FontWeight.w500,
        maxWidth: cellWidth - 30,
        maxLines: 1,
      );
      _text(
        canvas,
        entries[i].$2,
        Offset(x + 10, y + 20),
        fontSize: entries[i].$2.length > 18 ? 15 : 19,
        color: colorScheme.onSurface,
        weight: FontWeight.w700,
        maxWidth: cellWidth - 30,
        maxLines: 2,
      );
    }
    return top + sectionHeight + sectionGap;
  }

  void _paintFooter(
    Canvas canvas,
    Size size,
    FlightTrack track,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final footerY = size.height - 32;
    canvas.drawLine(
      Offset(60, footerY - 28),
      Offset(_w - 60.0, footerY - 28),
      Paint()
        ..color = colorScheme.outlineVariant.withValues(alpha: 0.45)
        ..strokeWidth = 1,
    );
    _text(
      canvas,
      l10n.flightShareCardFooter(track.pointCount),
      Offset(60, footerY),
      fontSize: 24,
      color: colorScheme.onSurfaceVariant,
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
    int maxLines = 2,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    );
    tp.layout(maxWidth: maxWidth ?? (_w - offset.dx - 40));
    tp.paint(canvas, offset);
  }

  static String _fmtDateOnly(DateTime t) {
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  static String _routeText(
    double totalM,
    List<double> legsM,
    String Function(double) formatKm,
  ) {
    final legs = legsM.isNotEmpty ? ' · ${_legsText(legsM, formatKm)}' : '';
    return '${formatKm(totalM)}$legs';
  }

  static String _triangleText(
    AppLocalizations l10n,
    double totalM,
    List<double> legsM,
    double closingM,
    bool closed,
    String Function(double) formatKm,
  ) {
    final legs = legsM.isNotEmpty ? ' · ${_legsText(legsM, formatKm)}' : '';
    final closing = closingM > 0
        ? ' · ${l10n.flightDetailClosing} ${closingM.round()} m'
        : '';
    final mark = closed ? ' (${l10n.flightDetailFaiClosed})' : '';
    return '${formatKm(totalM)}$legs$closing$mark';
  }

  static String _legsText(
    List<double> legsM,
    String Function(double) formatKm,
  ) => legsM
      .map((value) => value >= 1000 ? formatKm(value) : '${value.round()}m')
      .join(' / ');

  static String? _endpointText(
    String? site,
    double? latitude,
    double? longitude,
  ) {
    final coords = _formatCoordinates(latitude, longitude);
    final detail = coords ?? '';
    final hasSite = site?.isNotEmpty ?? false;
    if (hasSite && detail.isNotEmpty) return '$site ($detail)';
    if (hasSite) return site;
    return detail.isNotEmpty ? detail : null;
  }

  static String? _formatCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    final northSouth = latitude >= 0 ? 'N' : 'S';
    final eastWest = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(4)}°$northSouth, '
        '${longitude.abs().toStringAsFixed(4)}°$eastWest';
  }

  static String _fmtTime(DateTime t) {
    final local = t.toLocal();
    return '${_fmtClock(local)}.${local.millisecond.toString().padLeft(3, '0')}';
  }

  static String _fmtClock(DateTime t) {
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  static String _fmtDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${h}h ${two(m)}m' : '${m}m ${two(s)}s';
  }
}
