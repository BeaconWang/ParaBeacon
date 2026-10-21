import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import 'flight_derived_stats.dart';
import 'flight_file_output_service.dart';
import 'flight_recorder.dart';

/// Renders a portrait, content-sized 1080px-wide PNG "share card" and saves it
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
  static const int _minHeight = 1920;

  /// Renders the card for [track] and returns the PNG bytes. All on-card text
  /// is localized through [l10n], so the card follows the app's current
  /// language (e.g. Chinese when the app is set to Chinese).
  Future<List<int>> renderPng(FlightTrack track, AppLocalizations l10n) async {
    final stats = FlightDerivedStats.compute(track);
    final cardHeight = math
        .max(
          _minHeight,
          994 + _estimatedStatsHeight(track, stats, l10n).ceil() + 140,
        )
        .ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(_w.toDouble(), cardHeight.toDouble());

    _paintBackground(canvas, size);
    _paintHeader(canvas, size, track);
    final mapBottom = _paintTrackMap(canvas, size, track, l10n);
    final profileBottom = _paintAltitudeProfile(
      canvas,
      size,
      track,
      l10n,
      top: mapBottom + 28,
    );
    _paintStats(canvas, size, track, stats, l10n, top: profileBottom + 36);
    _paintFooter(canvas, size, track, l10n);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_w, cardHeight);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Renders the card and saves it to the gallery. Returns true on success.
  /// On failure (no gallery / permission), writes a temp file and opens the
  /// share sheet instead, returning false.
  Future<bool> saveToGallery(FlightTrack track, AppLocalizations l10n) async {
    final bytes = await renderPng(track, l10n);
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
    AppLocalizations l10n,
  ) async {
    final bytes = await renderPng(track, l10n);
    return FlightFileOutputService.instance.saveToDownloads(
      bytes: bytes,
      fileName: '${flightSlug(track)}.png',
      mimeType: 'image/png',
    );
  }

  Future<String> shareCard(FlightTrack track, AppLocalizations l10n) async {
    final bytes = await renderPng(track, l10n);
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

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = ui.Gradient.linear(
      rect.topCenter,
      rect.bottomCenter,
      const [Color(0xFF081521), Color(0xFF102A3D), Color(0xFF173D50)],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = gradient);
  }

  void _paintHeader(Canvas canvas, Size size, FlightTrack track) {
    _text(
      canvas,
      'ParaBeacon',
      Offset(60, 64),
      fontSize: 44,
      color: const Color(0xFF7FD1FF),
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
      color: Colors.white,
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
        color: const Color(0xFFB9D4E3),
        maxWidth: _w - 120.0,
      );
    }
  }

  /// Draws the track shape into a framed box and returns its bottom Y.
  double _paintTrackMap(
    Canvas canvas,
    Size size,
    FlightTrack track,
    AppLocalizations l10n,
  ) {
    const left = 60.0;
    const top = 230.0;
    final boxW = _w - 120.0;
    const boxH = 470.0;
    final rect = Rect.fromLTWH(left, top, boxW, boxH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));

    canvas.drawRRect(rrect, Paint()..color = const Color(0x22101B26));
    canvas.save();
    canvas.clipRRect(rrect);
    final gridPaint = Paint()
      ..color = const Color(0x14FFFFFF)
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
      color: const Color(0xFF91AFC0),
      weight: FontWeight.w700,
    );

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
        ..color = const Color(0x8848D7C0);
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
      canvas.drawCircle(start, 13, Paint()..color = const Color(0xFF4ADE80));
      canvas.drawCircle(end, 13, Paint()..color = const Color(0xFFFF6B6B));
      _text(
        canvas,
        l10n.flightDetailTakeoff,
        Offset(start.dx + 18, start.dy - 16),
        fontSize: 22,
        color: const Color(0xFFCDEFD8),
        weight: FontWeight.w600,
      );
      _text(
        canvas,
        l10n.flightDetailLanding,
        Offset(end.dx + 18, end.dy - 16),
        fontSize: 22,
        color: const Color(0xFFFFD2D2),
        weight: FontWeight.w600,
      );
    } else {
      _text(
        canvas,
        l10n.flightShareCardNoTrack,
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

  /// Draws an altitude-over-time profile (filled area chart) into a framed box
  /// and returns its bottom Y. Falls back to just the frame when there isn't
  /// enough per-sample data to plot.
  double _paintAltitudeProfile(
    Canvas canvas,
    Size size,
    FlightTrack track,
    AppLocalizations l10n, {
    required double top,
  }) {
    const left = 60.0;
    final boxW = _w - 120.0;
    const boxH = 230.0;
    final rect = Rect.fromLTWH(left, top, boxW, boxH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));

    canvas.drawRRect(rrect, Paint()..color = const Color(0x22101B26));

    _text(
      canvas,
      l10n.flightReportAltitudeProfile.toUpperCase(),
      Offset(left + 28, top + 18),
      fontSize: 24,
      color: const Color(0xFF8FB6CC),
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
      const padTop = 64.0;
      const padBottom = 36.0;
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
        ..color = const Color(0x18FFFFFF)
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
            const [Color(0x5539D98A), Color(0x0039D98A)],
          ),
      );
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF7FD1FF),
      );

      canvas.restore();

      _text(
        canvas,
        '${maxAlt.toStringAsFixed(0)} m',
        Offset(plotLeft, plotTop - 30),
        fontSize: 22,
        color: const Color(0xFFB9D4E3),
      );
      _text(
        canvas,
        '${minAlt.toStringAsFixed(0)} m',
        Offset(plotLeft, plotBottom + 4),
        fontSize: 22,
        color: const Color(0xFFB9D4E3),
      );
    } else {
      _text(
        canvas,
        l10n.flightShareCardNoAltitude,
        Offset(left + boxW / 2 - 110, top + boxH / 2 - 10),
        fontSize: 26,
        color: const Color(0x66FFFFFF),
      );
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x33FFFFFF),
    );
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
    );

    final takeoff = _endpointText(
      track.takeoffSite,
      track.takeoffLatitude,
      track.takeoffLongitude,
      track.takeoffAltitude,
    );
    final landing = _endpointText(
      track.landingSite,
      track.landingLatitude,
      track.landingLongitude,
      track.landingAltitude,
    );
    y = _paintMetricSection(
      canvas,
      l10n.flightDetailRoute,
      [
        (l10n.flightDetailDistance, km(track.distanceM)),
        if (takeoff != null) (l10n.flightDetailTakeoff, takeoff),
        if (landing != null) (l10n.flightDetailLanding, landing),
      ],
      left: 60,
      top: y,
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
      );
    }

    final equipment = <(String, String)>[
      if (track.gliderName?.isNotEmpty ?? false)
        (l10n.equipmentGlider, track.gliderName!),
      if (track.harnessName?.isNotEmpty ?? false)
        (l10n.equipmentHarness, track.harnessName!),
      if (track.helmetName?.isNotEmpty ?? false)
        (l10n.equipmentHelmet, track.helmetName!),
    ];
    if (equipment.isNotEmpty) {
      y = _paintMetricSection(
        canvas,
        l10n.equipment,
        equipment,
        left: 60,
        top: y,
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
        (l10n.flightDetailAircraftClass, track.aircraftFaiClass!),
      if (track.aircraftCategory?.isNotEmpty ?? false)
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
      track.takeoffAltitude,
    );
    final landing = _endpointText(
      track.landingSite,
      track.landingLatitude,
      track.landingLongitude,
      track.landingAltitude,
    );
    final counts = <int>[
      5 + (track.pilotName?.isNotEmpty ?? false ? 1 : 0),
      1 + (takeoff == null ? 0 : 1) + (landing == null ? 0 : 1),
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
    final equipmentCount = [
      track.gliderName,
      track.harnessName,
      track.helmetName,
    ].where((value) => value?.isNotEmpty ?? false).length;
    final aircraftCount = [
      track.aircraftName?.isNotEmpty ?? false,
      track.aircraftManufacturer?.isNotEmpty ?? false,
      track.aircraftModel?.isNotEmpty ?? false,
      track.aircraftFaiClass?.isNotEmpty ?? false,
      track.aircraftCategory?.isNotEmpty ?? false,
      track.aircraftTandem != null,
      track.aircraftEngineType?.isNotEmpty ?? false,
      track.aircraftTrimSpeedKmh != null,
      track.aircraftGoalGlideRatio != null,
    ].where((value) => value).length;
    if (equipmentCount > 0) counts.add(equipmentCount);
    if (aircraftCount > 0) counts.add(aircraftCount);
    final telemetryCount = _telemetryEntries(track, l10n).length;
    if (telemetryCount > 0) counts.add(telemetryCount);
    return counts.fold<double>(
      0,
      (height, count) => height + 50 + ((count + 2) ~/ 3) * 104,
    );
  }

  double _paintMetricSection(
    Canvas canvas,
    String label,
    List<(String, String)> entries, {
    required double left,
    required double top,
  }) {
    if (entries.isEmpty) return top;
    _text(
      canvas,
      label.toUpperCase(),
      Offset(left, top),
      fontSize: 22,
      color: const Color(0xFF5E8198),
      weight: FontWeight.w700,
    );

    const columns = 3;
    const cellHeight = 96.0;
    const rowStride = 104.0;
    final cellWidth = (_w - 120.0) / columns;
    canvas.drawLine(
      Offset(left, top + 30),
      Offset(left + _w - 120.0, top + 30),
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 1,
    );
    for (var i = 0; i < entries.length; i++) {
      final column = i % columns;
      final row = i ~/ columns;
      final x = left + column * cellWidth;
      final y = top + 42 + row * rowStride;
      final cellRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cellWidth - 10, cellHeight),
        const Radius.circular(14),
      );
      canvas.drawRRect(cellRect, Paint()..color = const Color(0x16FFFFFF));
      _text(
        canvas,
        entries[i].$1,
        Offset(x + 14, y + 9),
        fontSize: 19,
        color: const Color(0xFFA9C1CE),
        weight: FontWeight.w500,
        maxWidth: cellWidth - 38,
      );
      _text(
        canvas,
        entries[i].$2,
        Offset(x + 14, y + 37),
        fontSize: entries[i].$2.length > 22 ? 17 : 26,
        color: Colors.white,
        weight: FontWeight.w700,
        maxWidth: cellWidth - 38,
        maxLines: 2,
      );
    }
    final rowCount = (entries.length + columns - 1) ~/ columns;
    return top + 50 + rowCount * rowStride;
  }

  void _paintFooter(
    Canvas canvas,
    Size size,
    FlightTrack track,
    AppLocalizations l10n,
  ) {
    final footerY = size.height - 80;
    canvas.drawLine(
      Offset(60, footerY - 28),
      Offset(_w - 60.0, footerY - 28),
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 1,
    );
    _text(
      canvas,
      l10n.flightShareCardFooter(track.pointCount),
      Offset(60, footerY),
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
    double? altitude,
  ) {
    final coords = _formatCoordinates(latitude, longitude);
    final parts = <String>[
      if (coords != null) coords,
      if (altitude != null) '${altitude.round()} m',
    ];
    final detail = parts.join(' · ');
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
