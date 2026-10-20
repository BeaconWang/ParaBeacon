import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import 'flight_derived_stats.dart';
import 'flight_recorder.dart';

/// Generates a multi-page PDF summary report for a completed [FlightTrack] and
/// shares it via the platform share sheet.
///
/// Self-contained port of the reference project's flight PDF report, adapted to
/// this project's model. The report mirrors the share card's completeness: a
/// track-map and altitude-profile visual plus every headline, distance,
/// altitude and performance metric from [FlightDerivedStats], followed by the
/// recorded sites, equipment and aircraft configuration.
class FlightReportService {
  FlightReportService._();
  static final FlightReportService instance = FlightReportService._();

  static const double _pageMargin = 32.0;

  /// Builds the PDF bytes for [track]. All text is localized through [l10n];
  /// when the app locale needs non-Latin glyphs (e.g. Chinese) a matching
  /// font is loaded so the content renders in the current language.
  Future<List<int>> buildPdf(FlightTrack track, AppLocalizations l10n) async {
    final stats = FlightDerivedStats.compute(track);
    final theme = await _themeFor(l10n);
    final doc = pw.Document();

    final title = 'Flight ${flightSlug(track)}';
    final contentW = PdfPageFormat.a4.width - _pageMargin * 2;

    // ── Optional sections, built only when they carry information ───────────
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
    final routeRows = <List<String>>[
      [l10n.flightDetailDistance, _km(track.distanceM)],
      if (takeoff != null) [l10n.flightDetailTakeoff, takeoff],
      if (landing != null) [l10n.flightDetailLanding, landing],
    ];

    final equipRows = <List<String>>[
      if (track.gliderName?.isNotEmpty ?? false)
        [l10n.equipmentGlider, track.gliderName!],
      if (track.harnessName?.isNotEmpty ?? false)
        [l10n.equipmentHarness, track.harnessName!],
      if (track.helmetName?.isNotEmpty ?? false)
        [l10n.equipmentHelmet, track.helmetName!],
    ];

    final aircraftRows = <List<String>>[
      if (track.aircraftName?.isNotEmpty ?? false)
        [l10n.flightDetailAircraftName, track.aircraftName!],
      if (track.aircraftManufacturer?.isNotEmpty ?? false)
        [l10n.flightDetailAircraftManufacturer, track.aircraftManufacturer!],
      if (track.aircraftModel?.isNotEmpty ?? false)
        [l10n.flightDetailAircraftModel, track.aircraftModel!],
      if (track.aircraftFaiClass?.isNotEmpty ?? false)
        [l10n.flightDetailAircraftClass, track.aircraftFaiClass!],
      if (track.aircraftCategory?.isNotEmpty ?? false)
        [l10n.flightDetailAircraftCategory, track.aircraftCategory!],
      if (track.aircraftTandem != null)
        [
          l10n.flightDetailAircraftTandem,
          track.aircraftTandem!
              ? l10n.aircraftTandemYes
              : l10n.aircraftTandemNo,
        ],
      if (track.aircraftEngineType?.isNotEmpty ?? false)
        [l10n.flightDetailAircraftEngine, track.aircraftEngineType!],
      if (track.aircraftTrimSpeedKmh != null)
        [
          l10n.flightDetailAircraftTrimSpeed,
          '${track.aircraftTrimSpeedKmh!.toStringAsFixed(1)} km/h',
        ],
      if (track.aircraftGoalGlideRatio != null)
        [
          l10n.flightDetailAircraftGlideRatio,
          track.aircraftGoalGlideRatio!.toStringAsFixed(2),
        ],
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(_pageMargin),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                l10n.flightReportGeneratedBy,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                l10n.flightReportPage(context.pageNumber, context.pagesCount),
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) {
          final end = track.endTime != null ? track.lastRecordedTime : null;
          final start = track.firstRecordedTime;
          final when = end != null
              ? '${_fmtDate(start)}  ·  '
                    '${_fmtTime(start)} - ${_fmtTime(end)}'
              : _fmtDate(start);

          final visualWidth = (contentW - 12) / 2;
          final sensorRows = _telemetryRows(track, l10n);
          return [
            pw.Container(
              width: contentW,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    l10n.flightReportTitle,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '$title  ·  $when',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey100,
                    ),
                  ),
                  if (track.pilotName?.isNotEmpty ?? false) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      track.pilotName!,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blueGrey100,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 12),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _summaryMetric(
                          l10n.flightDetailDuration,
                          _fmtDuration(track.duration),
                        ),
                      ),
                      pw.Expanded(
                        child: _summaryMetric(
                          l10n.flightDetailDistance,
                          _km(track.distanceM),
                        ),
                      ),
                      pw.Expanded(
                        child: _summaryMetric(
                          l10n.flightDetailMaxAltitude,
                          '${track.maxAltitude.toStringAsFixed(0)} m',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // ── Visuals ─────────────────────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _caption(l10n.flightReportTrackMap),
                      _trackMap(track, visualWidth, l10n),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _caption(l10n.flightReportAltitudeProfile),
                      _altitudeProfile(track, visualWidth, l10n),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // ── Flight and route details ────────────────────────────────────
            _section(l10n.flightDetailFlight),
            _table([
              [l10n.flightReportDate, _fmtDate(start)],
              [l10n.flightDetailStart, '${_fmtDate(start)} ${_fmtTime(start)}'],
              [
                l10n.flightDetailEnd,
                end != null ? '${_fmtDate(end)} ${_fmtTime(end)}' : '-',
              ],
              [l10n.flightDetailDuration, _fmtDuration(track.duration)],
              [l10n.flightDetailSamples, '${track.pointCount}'],
              if (track.pilotName?.isNotEmpty ?? false)
                [l10n.flightDetailPilot, track.pilotName!],
            ]),
            pw.SizedBox(height: 12),
            _section(l10n.flightDetailRoute),
            _table(routeRows),
            pw.SizedBox(height: 12),
            _section(l10n.flightDetailAltitude),
            _table([
              [
                l10n.flightDetailMaxAltitude,
                '${track.maxAltitude.toStringAsFixed(0)} m',
              ],
              [
                l10n.flightDetailMinAltitude,
                '${track.minAltitude.toStringAsFixed(0)} m',
              ],
              [
                l10n.flightDetailMaxClimb,
                '${track.maxClimb.toStringAsFixed(1)} m/s',
              ],
              [
                l10n.flightDetailMaxSink,
                '${track.maxSink.toStringAsFixed(1)} m/s',
              ],
              if (!track.hasSamples && track.maxAltGainM != null)
                [
                  l10n.flightDetailMaxAltGain,
                  '${track.maxAltGainM!.toStringAsFixed(0)} m',
                ],
              if (!track.hasSamples && track.elevationDropM != null)
                [
                  l10n.flightDetailElevationDrop,
                  '${track.elevationDropM!.toStringAsFixed(0)} m',
                ],
            ]),
            if (sensorRows.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              _section(l10n.dataMonitorTitle),
              _table(sensorRows),
            ],
            if (track.hasSamples) ...[
              pw.SizedBox(height: 12),
              _section(l10n.flightDetailPerformance),
              _caption(l10n.flightDetailRouteMetrics),
              _table([
                [
                  l10n.flightDetailStraightDistance,
                  _routeText(stats.straightDistanceM, const []),
                ],
                if (stats.threeTurnpointM > 0)
                  [
                    l10n.flightDetailThreeTurnpoints,
                    _routeText(
                      stats.threeTurnpointM,
                      stats.threeTurnpointLegsM,
                    ),
                  ],
                if (stats.faiTriangleM > 0)
                  [
                    l10n.flightDetailFaiTriangle,
                    _triangleText(
                      l10n,
                      stats.faiTriangleM,
                      stats.faiTriangleLegsM,
                      stats.faiClosingM,
                      stats.faiClosed,
                    ),
                  ],
                if (stats.flatTriangleM > 0)
                  [
                    l10n.flightDetailFlatTriangle,
                    _triangleText(
                      l10n,
                      stats.flatTriangleM,
                      stats.flatTriangleLegsM,
                      stats.flatClosingM,
                      stats.flatClosed,
                    ),
                  ],
                [
                  l10n.flightDetailMaxFromStart,
                  _km(stats.maxDistanceFromStartM),
                ],
                [
                  l10n.flightDetailTrackEfficiency,
                  '${(stats.trackEfficiency * 100).toStringAsFixed(0)} %',
                ],
              ]),
              pw.SizedBox(height: 8),
              _caption(l10n.flightDetailSpeedGlide),
              _table([
                [
                  l10n.flightDetailAvgGroundSpeed,
                  '${stats.avgGroundSpeedKph.toStringAsFixed(1)} km/h',
                ],
                [
                  l10n.flightDetailAvgCruiseSpeed,
                  '${stats.avgCruiseSpeedKph.toStringAsFixed(1)} km/h',
                ],
                [
                  l10n.flightDetailMaxSpeed,
                  '${stats.maxSpeedKph.toStringAsFixed(1)} km/h',
                ],
                [
                  l10n.flightDetailAvgGlideRatio,
                  stats.avgGlideRatio > 0
                      ? stats.avgGlideRatio.toStringAsFixed(1)
                      : '-',
                ],
              ]),
              pw.SizedBox(height: 8),
              _caption(l10n.flightDetailClimbAltitude),
              _table([
                [
                  l10n.flightDetailAvgClimb,
                  '${stats.avgClimbMs.toStringAsFixed(1)} m/s',
                ],
                [
                  l10n.flightDetailAvgSink,
                  '${stats.avgSinkMs.toStringAsFixed(1)} m/s',
                ],
                [l10n.flightDetailThermals, '${stats.thermalCount}'],
                [
                  l10n.flightDetailAltGained,
                  '${stats.altitudeGainedM.toStringAsFixed(0)} m',
                ],
                [
                  l10n.flightDetailAltLost,
                  '${stats.altitudeLostM.toStringAsFixed(0)} m',
                ],
                [
                  l10n.flightDetailMaxAltGain,
                  '${(track.maxAltGainM ?? stats.maxAltGainM).toStringAsFixed(0)} m',
                ],
                [
                  l10n.flightDetailElevationDrop,
                  '${(track.elevationDropM ?? stats.elevationDropM).toStringAsFixed(0)} m',
                ],
              ]),
              pw.SizedBox(height: 8),
              _caption(l10n.flightDetailTimeBreakdown),
              _table([
                [l10n.flightDetailClimbTime, _fmtDuration(stats.climbTime)],
                [l10n.flightDetailGlideTime, _fmtDuration(stats.glideTime)],
                [l10n.flightDetailSinkTime, _fmtDuration(stats.sinkTime)],
                [l10n.flightDetailMovingTime, _fmtDuration(stats.movingTime)],
              ]),
            ],
            if (equipRows.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _section(l10n.equipment),
              _table(equipRows),
            ],
            if (aircraftRows.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              _section(l10n.flightDetailAircraft),
              _table(aircraftRows),
            ],
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Builds the report and shares it as a `.pdf` file. Returns the temp path.
  Future<String> sharePdf(FlightTrack track, AppLocalizations l10n) async {
    final bytes = await buildPdf(track, l10n);
    final dir = await getTemporaryDirectory();
    final fileName = '${flightSlug(track)}.pdf';
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(path, mimeType: 'application/pdf', name: fileName),
    ], subject: 'ParaBeacon flight ${flightSlug(track)}');
    return path;
  }

  /// Builds a [pw.ThemeData] whose base/bold fonts can render the current
  /// locale's glyphs. Latin locales use the PDF defaults; CJK locales load a
  /// Noto font (fetched on demand by the printing package). Falls back to the
  /// default theme if the font can't be loaded (e.g. offline).
  Future<pw.ThemeData?> _themeFor(AppLocalizations l10n) async {
    final locale = l10n.localeName.toLowerCase();
    try {
      if (locale.startsWith('zh')) {
        final base = await PdfGoogleFonts.notoSansSCRegular();
        final bold = await PdfGoogleFonts.notoSansSCBold();
        return pw.ThemeData.withFont(base: base, bold: bold);
      }
    } catch (_) {
      // Network/font load failed — degrade to the default Latin theme.
    }
    return null;
  }

  // ── Visuals (drawn with the PDF graphics canvas) ──────────────────────────

  /// A framed top-down track map, coloured by altitude, with launch/landing
  /// markers. Falls back to a "No track" note when there's too little data.
  static pw.Widget _trackMap(
    FlightTrack track,
    double width,
    AppLocalizations l10n,
  ) {
    final samples = track.samples.where((s) => s.data.hasFix).toList();
    const height = 172.0;
    if (samples.length < 2) {
      return _emptyBox(width, height, l10n.flightShareCardNoTrack);
    }
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (canvas, size) => _paintTrack(canvas, size, samples),
    );
  }

  static void _paintTrack(
    PdfGraphics canvas,
    PdfPoint size,
    List<FlightSample> samples,
  ) {
    final w = size.x, h = size.y;
    _paintFrame(canvas, w, h);
    for (var i = 1; i < 5; i++) {
      final x = w * i / 5;
      final y = h * i / 5;
      canvas
        ..setStrokeColor(PdfColors.blueGrey100)
        ..setLineWidth(0.45)
        ..moveTo(x, 0)
        ..lineTo(x, h)
        ..strokePath()
        ..moveTo(0, y)
        ..lineTo(w, y)
        ..strokePath();
    }

    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    double minAlt = double.infinity, maxAlt = double.negativeInfinity;
    for (final s in samples) {
      minLat = math.min(minLat, s.data.latitude);
      maxLat = math.max(maxLat, s.data.latitude);
      minLon = math.min(minLon, s.data.longitude);
      maxLon = math.max(maxLon, s.data.longitude);
      minAlt = math.min(minAlt, s.data.altitude);
      maxAlt = math.max(maxAlt, s.data.altitude);
    }
    final spanLat = math.max(1e-6, maxLat - minLat);
    final spanLon = math.max(1e-6, maxLon - minLon);
    const pad = 16.0;
    final scale = math.min((w - pad * 2) / spanLon, (h - pad * 2) / spanLat);
    final offX = (w - spanLon * scale) / 2;
    final offY = (h - spanLat * scale) / 2;
    // PDF Y grows upward, so higher latitude maps to a higher Y (north up).
    PdfPoint project(double lat, double lon) =>
        PdfPoint(offX + (lon - minLon) * scale, offY + (lat - minLat) * scale);

    final altSpan = math.max(1.0, maxAlt - minAlt);
    canvas
      ..setLineWidth(1.8)
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round);
    for (var i = 1; i < samples.length; i++) {
      final a = project(
        samples[i - 1].data.latitude,
        samples[i - 1].data.longitude,
      );
      final b = project(samples[i].data.latitude, samples[i].data.longitude);
      final t = ((samples[i].data.altitude - minAlt) / altSpan).clamp(0.0, 1.0);
      canvas
        ..setStrokeColor(PdfColors.white)
        ..setLineWidth(4.6)
        ..moveTo(a.x, a.y)
        ..lineTo(b.x, b.y)
        ..strokePath()
        ..setStrokeColor(_altColor(t))
        ..setLineWidth(1.8)
        ..moveTo(a.x, a.y)
        ..lineTo(b.x, b.y)
        ..strokePath();
    }

    final start = project(
      samples.first.data.latitude,
      samples.first.data.longitude,
    );
    final end = project(
      samples.last.data.latitude,
      samples.last.data.longitude,
    );
    canvas
      ..setFillColor(PdfColors.white)
      ..drawEllipse(start.x, start.y, 7, 7)
      ..fillPath()
      ..setFillColor(const PdfColor(0.29, 0.87, 0.50))
      ..drawEllipse(start.x, start.y, 4.5, 4.5)
      ..fillPath()
      ..setFillColor(PdfColors.white)
      ..drawEllipse(end.x, end.y, 7, 7)
      ..fillPath()
      ..setFillColor(const PdfColor(1.0, 0.42, 0.42))
      ..drawEllipse(end.x, end.y, 4.5, 4.5)
      ..fillPath();
  }

  /// A framed altitude-over-time area chart, with min/max labels overlaid.
  static pw.Widget _altitudeProfile(
    FlightTrack track,
    double width,
    AppLocalizations l10n,
  ) {
    final samples = track.samples
        .where((s) => s.data.altitude.isFinite)
        .toList();
    const height = 150.0;
    if (samples.length < 2) {
      return _emptyBox(width, height, l10n.flightShareCardNoAltitude);
    }
    double minAlt = double.infinity, maxAlt = double.negativeInfinity;
    for (final s in samples) {
      minAlt = math.min(minAlt, s.data.altitude);
      maxAlt = math.max(maxAlt, s.data.altitude);
    }
    const labelStyle = pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey700);
    return pw.Stack(
      children: [
        pw.CustomPaint(
          size: PdfPoint(width, height),
          painter: (canvas, size) => _paintAltitude(canvas, size, samples),
        ),
        pw.Positioned(
          left: 6,
          top: 6,
          child: pw.Text('${maxAlt.toStringAsFixed(0)} m', style: labelStyle),
        ),
        pw.Positioned(
          left: 6,
          bottom: 6,
          child: pw.Text('${minAlt.toStringAsFixed(0)} m', style: labelStyle),
        ),
      ],
    );
  }

  static void _paintAltitude(
    PdfGraphics canvas,
    PdfPoint size,
    List<FlightSample> samples,
  ) {
    final w = size.x, h = size.y;
    _paintFrame(canvas, w, h);

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

    const padX = 34.0;
    const padY = 16.0;
    final plotLeft = padX;
    final plotRight = w - padX;
    final plotBottom = padY;
    final plotTop = h - padY;
    final plotW = plotRight - plotLeft;
    final plotH = plotTop - plotBottom;

    PdfPoint project(int ms, double alt) => PdfPoint(
      plotLeft + (ms - startMs) / spanMs * plotW,
      plotBottom + (alt - minAlt) / altSpan * plotH,
    );

    for (var i = 0; i <= 3; i++) {
      final y = plotBottom + plotH * i / 3;
      canvas
        ..setStrokeColor(PdfColors.blueGrey100)
        ..setLineWidth(0.45)
        ..moveTo(plotLeft, y)
        ..lineTo(plotRight, y)
        ..strokePath();
    }

    // Filled area under the curve.
    canvas.setFillColor(const PdfColor(0.22, 0.85, 0.54, 0.25));
    canvas.moveTo(plotLeft, plotBottom);
    for (final s in samples) {
      final o = project(s.time.millisecondsSinceEpoch, s.data.altitude);
      canvas.lineTo(o.x, o.y);
    }
    canvas
      ..lineTo(plotRight, plotBottom)
      ..fillPath();

    // Curve on top.
    canvas
      ..setStrokeColor(const PdfColor(0.50, 0.82, 1.0))
      ..setLineWidth(1.6)
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round);
    for (var i = 0; i < samples.length; i++) {
      final o = project(
        samples[i].time.millisecondsSinceEpoch,
        samples[i].data.altitude,
      );
      if (i == 0) {
        canvas.moveTo(o.x, o.y);
      } else {
        canvas.lineTo(o.x, o.y);
      }
    }
    canvas.strokePath();
  }

  static void _paintFrame(PdfGraphics canvas, double w, double h) {
    canvas
      ..setFillColor(PdfColors.blueGrey50)
      ..drawRect(0, 0, w, h)
      ..fillPath()
      ..setStrokeColor(PdfColors.blueGrey200)
      ..setLineWidth(0.8)
      ..drawRect(0, 0, w, h)
      ..strokePath();
  }

  static pw.Widget _emptyBox(double width, double height, String label) =>
      pw.Container(
        width: width,
        height: height,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.8),
        ),
        child: pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey500),
        ),
      );

  /// Maps a normalized altitude [t] in 0..1 to a cool→warm colour ramp.
  static PdfColor _altColor(double t) {
    const stops = <PdfColor>[
      PdfColor(0.23, 0.51, 0.96), // blue
      PdfColor(0.13, 0.83, 0.93), // cyan
      PdfColor(0.22, 0.85, 0.54), // green
      PdfColor(0.98, 0.80, 0.08), // amber
      PdfColor(0.98, 0.45, 0.09), // orange
    ];
    final x = t.clamp(0.0, 1.0) * (stops.length - 1);
    final i = x.floor().clamp(0, stops.length - 2);
    final f = x - i;
    final a = stops[i], b = stops[i + 1];
    return PdfColor(
      a.red + (b.red - a.red) * f,
      a.green + (b.green - a.green) * f,
      a.blue + (b.blue - a.blue) * f,
    );
  }

  // ── Small PDF helpers ─────────────────────────────────────────────────────

  static pw.Widget _summaryMetric(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey100),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    ],
  );

  static List<List<String>> _telemetryRows(
    FlightTrack track,
    AppLocalizations l10n,
  ) {
    final samples = track.samples.map((sample) => sample.data).toList();
    List<double> doubles(Iterable<double?> source) =>
        source.whereType<double>().where((value) => value.isFinite).toList();
    List<int> integers(Iterable<int?> source) =>
        source.whereType<int>().toList();
    String range(Iterable<num> source, String unit, {int decimals = 0}) {
      final values = source.toList();
      if (values.isEmpty) return '';
      var min = values.first;
      var max = values.first;
      for (final value in values.skip(1)) {
        if (value < min) min = value;
        if (value > max) max = value;
      }
      String format(num value) => value.toStringAsFixed(decimals);
      return min == max
          ? '${format(min)} $unit'
          : '${format(min)}-${format(max)} $unit';
    }

    final wind = samples
        .map((value) => value.windSpeed)
        .where((value) => value.isFinite && value > 0)
        .toList();
    final temperature = doubles(samples.map((value) => value.temperature));
    final pressure = doubles(samples.map((value) => value.pressure));
    final accuracy = doubles(samples.map((value) => value.gpsAccuracy));
    final satellites = integers(samples.map((value) => value.satellites));
    final battery = integers(samples.map((value) => value.battery));
    final heartRate = integers(samples.map((value) => value.heartRate));
    return [
      if (wind.isNotEmpty)
        [
          l10n.dataMonitorWindSpeed,
          '${(wind.reduce((a, b) => a + b) / wind.length).toStringAsFixed(1)} km/h',
        ],
      if (temperature.isNotEmpty)
        [l10n.dataMonitorTemperature, range(temperature, '°C', decimals: 1)],
      if (pressure.isNotEmpty)
        [l10n.dataMonitorPressure, range(pressure, 'hPa')],
      if (accuracy.isNotEmpty)
        [
          l10n.dataMonitorGpsAccuracy,
          '${(accuracy.reduce((a, b) => a + b) / accuracy.length).toStringAsFixed(0)} m',
        ],
      if (satellites.isNotEmpty)
        [
          l10n.dataMonitorSatellites,
          '${satellites.reduce((a, b) => a > b ? a : b)}',
        ],
      if (battery.isNotEmpty) [l10n.dataMonitorBattery, range(battery, '%')],
      if (heartRate.isNotEmpty)
        [l10n.dataMonitorHeartRate, range(heartRate, 'bpm')],
    ];
  }

  static pw.Widget _caption(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey600,
      ),
    ),
  );

  static pw.Widget _section(String title) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 4),
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      color: PdfColors.blueGrey50,
      border: pw.Border(
        left: pw.BorderSide(color: PdfColors.teal600, width: 2),
      ),
    ),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blueGrey800,
      ),
    ),
  );

  static pw.Widget _table(List<List<String>> rows) {
    return pw.Table(
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
      children: [
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : PdfColors.blueGrey50,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 3,
                ),
                child: pw.Text(
                  rows[i][0],
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 3,
                ),
                child: pw.Text(
                  rows[i][1],
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static String _km(double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(2)} km'
      : '${m.toStringAsFixed(0)} m';

  static String _routeText(double totalM, List<double> legsM) {
    final legs = legsM.isNotEmpty ? ' · ${_legsText(legsM)}' : '';
    return '${_km(totalM)}$legs';
  }

  static String _triangleText(
    AppLocalizations l10n,
    double totalM,
    List<double> legsM,
    double closingM,
    bool closed,
  ) {
    final legs = legsM.isNotEmpty ? ' · ${_legsText(legsM)}' : '';
    final closing = closingM > 0
        ? ' · ${l10n.flightDetailClosing} ${closingM.round()} m'
        : '';
    final mark = closed ? ' (${l10n.flightDetailFaiClosed})' : '';
    return '${_km(totalM)}$legs$closing$mark';
  }

  static String _legsText(List<double> legsM) => legsM
      .map((value) {
        return value >= 1000
            ? '${(value / 1000).toStringAsFixed(2)}km'
            : '${value.round()}m';
      })
      .join(' / ');

  static String? _endpointText(
    String? site,
    double? latitude,
    double? longitude,
    double? altitude,
  ) {
    final coords = _fmtCoords(latitude, longitude);
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

  static String? _fmtCoords(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    final northSouth = latitude >= 0 ? 'N' : 'S';
    final eastWest = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(4)}°$northSouth, '
        '${longitude.abs().toStringAsFixed(4)}°$eastWest';
  }

  static String _fmtDate(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}';

  static String _fmtTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${_two(m)}m';
    return '${m}m ${_two(s)}s';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
