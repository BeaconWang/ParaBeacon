import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import 'flight_file_output_service.dart';
import 'flight_recorder.dart';
import 'flight_statistics.dart';
import 'share_card_settings.dart';

class FlightStatisticsShareCardService {
  FlightStatisticsShareCardService._();
  static final FlightStatisticsShareCardService instance =
      FlightStatisticsShareCardService._();

  static const int _width = 1080;

  Future<List<int>> renderPng(
    FlightStatistics stats,
    AppLocalizations l10n, {
    required bool selected,
    required String locale,
    required ColorScheme colorScheme,
  }) async {
    final painter = _StatisticsCardPainter(
      stats: stats,
      l10n: l10n,
      selected: selected,
      locale: locale,
      colorScheme: colorScheme,
      flatDesign: ShareCardSettings.instance.flatDesign,
    );
    final picture = painter.paint();
    final image = await picture.toImage(_width, painter.height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Could not encode statistics card.');
    return data.buffer.asUint8List();
  }

  Future<bool> saveToGallery(
    FlightStatistics stats,
    AppLocalizations l10n, {
    required bool selected,
    required String locale,
    required ColorScheme colorScheme,
  }) async {
    final bytes = await renderPng(
      stats,
      l10n,
      selected: selected,
      locale: locale,
      colorScheme: colorScheme,
    );
    final dir = await getTemporaryDirectory();
    final fileName = _fileName(stats);
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);

    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        await _share(path, fileName, l10n);
        return false;
      }
      await Gal.putImage(path, album: 'ParaBeacon');
      return true;
    } catch (_) {
      await _share(path, fileName, l10n);
      return false;
    }
  }

  Future<String?> saveToDownloads(
    FlightStatistics stats,
    AppLocalizations l10n, {
    required bool selected,
    required String locale,
    required ColorScheme colorScheme,
  }) async {
    final bytes = await renderPng(
      stats,
      l10n,
      selected: selected,
      locale: locale,
      colorScheme: colorScheme,
    );
    return FlightFileOutputService.instance.saveToDownloads(
      bytes: bytes,
      fileName: _fileName(stats),
      mimeType: 'image/png',
    );
  }

  Future<String> shareCard(
    FlightStatistics stats,
    AppLocalizations l10n, {
    required bool selected,
    required String locale,
    required ColorScheme colorScheme,
  }) async {
    final bytes = await renderPng(
      stats,
      l10n,
      selected: selected,
      locale: locale,
      colorScheme: colorScheme,
    );
    final fileName = _fileName(stats);
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    await _share(path, fileName, l10n);
    return path;
  }

  Future<void> _share(
    String path,
    String fileName,
    AppLocalizations l10n,
  ) async {
    await Share.shareXFiles([
      XFile(path, mimeType: 'image/png', name: fileName),
    ], subject: l10n.statsTitle);
  }

  String _fileName(FlightStatistics stats) {
    final first = stats.firstFlight?.toLocal();
    final last = stats.lastFlight?.toLocal();
    if (first == null || last == null) return 'flight-statistics.png';
    return 'flight-statistics-${first.year}-${last.year}.png';
  }
}

class _StatisticsCardPainter {
  _StatisticsCardPainter({
    required this.stats,
    required this.l10n,
    required this.selected,
    required this.locale,
    required this.colorScheme,
    required this.flatDesign,
  }) {
    _prepareSections();
  }

  static const double _width = 1080;
  static const double _margin = 56;
  static const double _contentWidth = _width - (_margin * 2);
  final FlightStatistics stats;
  final AppLocalizations l10n;
  final bool selected;
  final String locale;
  final ColorScheme colorScheme;
  final bool flatDesign;
  Color get _surfaceAlt => colorScheme.surfaceContainerHigh;
  List<Color> get _groupAccents => [
    colorScheme.primary,
    Color.lerp(colorScheme.primary, colorScheme.secondary, 0.26)!,
    Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.26)!,
  ];
  Color get _muted => colorScheme.onSurfaceVariant;
  Color get _white => colorScheme.onSurface;
  final List<_CardSection> _sections = [];
  late final List<String> _months;
  late final String _dateRange;
  late final int height;

  void _prepareSections() {
    _months = [
      for (var month = 1; month <= 12; month++)
        DateFormat.MMM(locale).format(DateTime(2020, month)),
    ];
    final firstDate = _date(stats.firstFlight);
    final lastDate = _date(stats.lastFlight);
    _dateRange = firstDate == lastDate ? firstDate : '$firstDate → $lastDate';

    _sections.addAll([
      _CardSection(
        l10n.statsSectionOverview,
        rows: [
          _CardRow(l10n.statsDateRange, _dateRange),
          _CardRow(l10n.statsFirstFlight, firstDate),
          _CardRow(l10n.statsLastFlight, lastDate),
          _CardRow(l10n.statsActiveDays, '${stats.activeDays}'),
          _CardRow(
            l10n.statsFlightsPerDay,
            stats.flightsPerActiveDay.toStringAsFixed(1),
          ),
          _CardRow(
            l10n.statsSampledFlights,
            '${stats.flightsWithSamples} / ${stats.flightCount}',
          ),
        ],
      ),
      _CardSection(
        l10n.statsSectionRecords,
        rows: [
          _recordRow(
            l10n.statsLongestFlight,
            stats.longestDuration == null
                ? null
                : _duration(stats.longestDuration!.value),
            stats.longestDuration?.track,
          ),
          _recordRow(
            l10n.statsLongestDistance,
            stats.longestTrackDistanceM == null
                ? null
                : _km(stats.longestTrackDistanceM!.value, 2),
            stats.longestTrackDistanceM?.track,
          ),
          _recordRow(
            l10n.statsLongestXc,
            stats.longestStraightDistanceM == null
                ? null
                : _km(stats.longestStraightDistanceM!.value, 2),
            stats.longestStraightDistanceM?.track,
          ),
          _recordRow(
            l10n.statsBestFaiTriangle,
            stats.bestFaiTriangleM == null
                ? null
                : _km(stats.bestFaiTriangleM!.value, 2),
            stats.bestFaiTriangleM?.track,
          ),
          _recordRow(
            l10n.statsMaxDistanceFromStart,
            stats.maxDistanceFromStartM == null
                ? null
                : _km(stats.maxDistanceFromStartM!.value, 2),
            stats.maxDistanceFromStartM?.track,
          ),
          _recordRow(
            l10n.statsHighestAltitude,
            stats.highestAltitudeM == null
                ? null
                : '${stats.highestAltitudeM!.value.toStringAsFixed(0)} m',
            stats.highestAltitudeM?.track,
          ),
          _recordRow(
            l10n.statsLowestAltitude,
            stats.lowestAltitudeM == null
                ? null
                : '${stats.lowestAltitudeM!.value.toStringAsFixed(0)} m',
            stats.lowestAltitudeM?.track,
          ),
          _recordRow(
            l10n.statsMaxClimb,
            stats.maxClimbMs == null
                ? null
                : '${stats.maxClimbMs!.value.toStringAsFixed(1)} m/s',
            stats.maxClimbMs?.track,
          ),
          _recordRow(
            l10n.statsMaxSink,
            stats.maxSinkMs == null
                ? null
                : '${stats.maxSinkMs!.value.toStringAsFixed(1)} m/s',
            stats.maxSinkMs?.track,
          ),
          _recordRow(
            l10n.statsMaxSpeed,
            stats.maxSpeedKph == null
                ? null
                : '${stats.maxSpeedKph!.value.toStringAsFixed(1)} km/h',
            stats.maxSpeedKph?.track,
          ),
          _recordRow(
            l10n.statsBestGlide,
            stats.bestGlideRatio?.value.toStringAsFixed(1),
            stats.bestGlideRatio?.track,
          ),
        ],
        rowHeight: 68,
      ),
      _CardSection(
        l10n.statsSectionAverages,
        rows: [
          _CardRow(l10n.statsAvgDuration, _duration(stats.avgDuration)),
          _CardRow(l10n.statsAvgDistance, _km(stats.avgTrackDistanceM, 2)),
          _CardRow(l10n.statsAvgXcDistance, _km(stats.avgStraightDistanceM, 2)),
          _CardRow(
            l10n.statsAvgMaxAltitude,
            '${stats.avgMaxAltitudeM.toStringAsFixed(0)} m',
          ),
          _CardRow(
            l10n.statsAvgSpeed,
            '${stats.avgSpeedKph.toStringAsFixed(1)} km/h',
          ),
          _CardRow(
            l10n.statsAvgGlide,
            stats.avgGlideRatio > 0
                ? stats.avgGlideRatio.toStringAsFixed(1)
                : '—',
          ),
        ],
      ),
      _CardSection(
        l10n.statsSectionTotals,
        rows: [
          _CardRow(
            l10n.statsTotalAltGained,
            '${stats.totalAltitudeGainedM.toStringAsFixed(0)} m',
          ),
          _CardRow(
            l10n.statsTotalAltLost,
            '${stats.totalAltitudeLostM.toStringAsFixed(0)} m',
          ),
          _CardRow(l10n.statsTotalThermals, '${stats.totalThermals}'),
          _CardRow(
            l10n.statsTotalMovingTime,
            _duration(stats.totalAirtimeMoving),
          ),
          _CardRow(l10n.statsTotalSamples, '${stats.totalSamples}'),
        ],
      ),
    ]);

    _sections.addAll([
      _distributionSection(l10n.statsSectionByYear, stats.byYear),
      _distributionSection(
        l10n.statsSectionByMonth,
        stats.monthsLabeled(_months),
        hideEmpty: false,
      ),
      if (stats.byAircraft.isNotEmpty)
        _distributionSection(l10n.statsSectionByAircraft, stats.byAircraft),
      if (stats.byTakeoffSite.isNotEmpty)
        _distributionSection(l10n.statsSectionBySite, stats.byTakeoffSite),
    ]);

    final sectionsHeight = _sections.fold<double>(0, (sum, section) {
      final rows = section.rows?.length ?? section.buckets?.length ?? 1;
      return sum + 118 + rows * section.rowHeight;
    });
    height = (650 + sectionsHeight).ceil();
  }

  _CardRow _recordRow(String label, String? value, FlightTrack? track) {
    final detail = value == null || track == null
        ? null
        : l10n.statsRecordOn(_date(track.startTime));
    return _CardRow(label, value ?? '—', detail: detail);
  }

  _CardSection _distributionSection(
    String title,
    List<FlightBucket> buckets, {
    bool hideEmpty = true,
  }) {
    final rows = hideEmpty
        ? buckets.where((bucket) => bucket.count > 0).toList()
        : buckets;
    return _CardSection(
      title,
      buckets: rows,
      emptyMessage: rows.isEmpty ? l10n.statsNotEnoughData : null,
      rowHeight: 78,
    );
  }

  ui.Picture paint() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(_width, height.toDouble());
    _paintBackground(canvas, size);
    _paintHeader(canvas);
    var top = 300.0;
    _paintHeroGrid(canvas, top);
    top += 272;
    final sectionAccents = _groupAccents;
    for (var index = 0; index < _sections.length; index++) {
      top =
          _paintSection(
            canvas,
            _sections[index],
            top,
            sectionAccents[index % sectionAccents.length],
          ) +
          20;
    }
    _paintFooter(canvas, top);
    return recorder.endRecording();
  }

  void _paintBackground(Canvas canvas, Size size) {
    if (flatDesign) {
      canvas.drawRect(Offset.zero & size, Paint()..color = colorScheme.surface);
      return;
    }
    final isDark = colorScheme.brightness == Brightness.dark;
    final accentMix = isDark ? 0.3 : 0.13;
    final secondaryMix = isDark ? 0.2 : 0.09;
    final glowAlpha = isDark ? 0.24 : 0.14;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width * 0.3, size.height),
          [
            Color.lerp(colorScheme.surface, colorScheme.primary, accentMix)!,
            Color.lerp(
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
              0.55,
            )!,
            Color.lerp(
              colorScheme.surfaceContainer,
              colorScheme.secondary,
              secondaryMix,
            )!,
          ],
          const [0, 0.52, 1],
        ),
    );
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

  void _paintCardSurface(
    Canvas canvas,
    Rect rect, {
    required double radius,
    required Color startColor,
    required Color endColor,
    Color? accentColor,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final tintAmount = isDark ? 0.08 : 0.04;
    final glassAlpha = isDark ? 0.8 : 0.76;
    final tintedStart = accentColor == null
        ? startColor
        : Color.lerp(startColor, accentColor, tintAmount)!;
    final tintedEnd = accentColor == null
        ? endColor
        : Color.lerp(endColor, accentColor, tintAmount * 0.65)!;
    final borderColor = accentColor == null
        ? colorScheme.outlineVariant
        : Color.lerp(colorScheme.outlineVariant, accentColor, 0.18)!;
    if (flatDesign) {
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
      Radius.circular(radius - 2),
    );
    canvas.drawRRect(
      inset,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: isDark ? 0.12 : 0.34),
    );
  }

  void _paintHeader(Canvas canvas) {
    _text(
      canvas,
      'ParaBeacon',
      const Offset(_margin, 54),
      fontSize: 44,
      color: colorScheme.primary,
      weight: FontWeight.w700,
      maxWidth: _contentWidth,
    );
    _text(
      canvas,
      l10n.statsTitle,
      const Offset(_margin, 116),
      fontSize: 48,
      color: _white,
      weight: FontWeight.w700,
      maxWidth: _contentWidth,
    );
    _text(
      canvas,
      selected
          ? l10n.statsScopeSelected(stats.flightCount)
          : l10n.statsScopeAll(stats.flightCount),
      const Offset(_margin, 180),
      fontSize: 30,
      color: _muted,
      weight: FontWeight.w600,
      maxWidth: _contentWidth,
    );
    _text(
      canvas,
      _dateRange,
      const Offset(_margin, 224),
      fontSize: 27,
      color: _white,
      maxWidth: _contentWidth,
    );
  }

  void _paintHeroGrid(Canvas canvas, double top) {
    final values = <(String, String)>[
      (l10n.statsFlights, '${stats.flightCount}'),
      (l10n.statsTotalAirtime, _duration(stats.totalDuration)),
      (l10n.statsTotalDistance, _km(stats.totalTrackDistanceM, 1)),
      (l10n.statsTotalXcDistance, _km(stats.totalStraightDistanceM, 1)),
    ];
    const gap = 16.0;
    final cardWidth = (_contentWidth - gap) / 2;
    const cardHeight = 122.0;
    final accents = _groupAccents;
    for (var i = 0; i < values.length; i++) {
      final accentColor = accents[i % accents.length];
      final column = i % 2;
      final row = i ~/ 2;
      final left = _margin + column * (cardWidth + gap);
      final y = top + row * (cardHeight + gap);
      final rect = Rect.fromLTWH(left, y, cardWidth, cardHeight);
      _paintCardSurface(
        canvas,
        rect,
        radius: 20,
        startColor: colorScheme.surfaceContainerHigh,
        endColor: colorScheme.surfaceContainer,
        accentColor: accentColor,
      );
      _text(
        canvas,
        values[i].$2,
        Offset(left + 24, y + 24),
        fontSize: 38,
        color: accentColor,
        weight: FontWeight.w700,
        maxWidth: cardWidth - 48,
        maxLines: 1,
      );
      _text(
        canvas,
        values[i].$1,
        Offset(left + 24, y + 76),
        fontSize: 23,
        color: _muted,
        maxWidth: cardWidth - 48,
        maxLines: 1,
      );
    }
  }

  double _paintSection(
    Canvas canvas,
    _CardSection section,
    double top,
    Color accentColor,
  ) {
    final rowCount = section.rows?.length ?? section.buckets?.length ?? 1;
    final bodyRows = rowCount == 0 ? 1 : rowCount;
    final cardHeight = 78 + bodyRows * section.rowHeight + 20;
    final rect = Rect.fromLTWH(_margin, top, _contentWidth, cardHeight);
    _paintCardSurface(
      canvas,
      rect,
      radius: 20,
      startColor: colorScheme.surfaceContainerLow,
      endColor: colorScheme.surfaceContainerHigh,
      accentColor: accentColor,
    );
    _text(
      canvas,
      section.title,
      Offset(_margin + 24, top + 22),
      fontSize: 29,
      color: accentColor,
      weight: FontWeight.w700,
      maxWidth: _contentWidth - 48,
      maxLines: 1,
    );
    final accentRect = Rect.fromLTWH(_margin + 24, top + 58, 72, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(accentRect, const Radius.circular(2)),
      Paint()
        ..shader = ui.Gradient.linear(accentRect.topLeft, accentRect.topRight, [
          accentColor,
          accentColor.withValues(alpha: 0.35),
        ]),
    );
    final contentTop = top + 72;
    if (section.rows != null) {
      for (var i = 0; i < section.rows!.length; i++) {
        _paintValueRow(
          canvas,
          section.rows![i],
          contentTop + i * section.rowHeight,
          section.rowHeight,
        );
      }
    } else if (section.buckets != null && section.buckets!.isNotEmpty) {
      final maxCount = section.buckets!
          .map((bucket) => bucket.count)
          .fold<int>(0, (a, b) => a > b ? a : b);
      for (var i = 0; i < section.buckets!.length; i++) {
        _paintBucketRow(
          canvas,
          section.buckets![i],
          maxCount,
          contentTop + i * section.rowHeight,
          section.rowHeight,
          accentColor,
        );
      }
    } else {
      _text(
        canvas,
        section.emptyMessage ?? l10n.statsNotEnoughData,
        Offset(_margin + 24, contentTop + 12),
        fontSize: 22,
        color: _muted,
        maxWidth: _contentWidth - 48,
      );
    }
    return top + cardHeight;
  }

  void _paintValueRow(
    Canvas canvas,
    _CardRow row,
    double top,
    double rowHeight,
  ) {
    final labelColor = _muted;
    _text(
      canvas,
      row.label,
      Offset(_margin + 24, top + (row.detail == null ? 12 : 5)),
      fontSize: 22,
      color: labelColor,
      maxWidth: 470,
      maxLines: 2,
    );
    _text(
      canvas,
      row.value,
      Offset(_margin + 510, top + (row.detail == null ? 12 : 3)),
      fontSize: row.detail == null ? 23 : 24,
      color: _white,
      weight: FontWeight.w600,
      maxWidth: _contentWidth - 556,
      maxLines: 1,
      alignRight: true,
    );
    if (row.detail != null) {
      _text(
        canvas,
        row.detail!,
        Offset(_margin + 510, top + 37),
        fontSize: 17,
        color: _muted,
        maxWidth: _contentWidth - 556,
        maxLines: 1,
        alignRight: true,
      );
    }
    if (rowHeight > 50) {
      canvas.drawLine(
        Offset(_margin + 24, top + rowHeight - 1),
        Offset(_margin + _contentWidth - 24, top + rowHeight - 1),
        Paint()..color = colorScheme.outlineVariant.withValues(alpha: 0.4),
      );
    }
  }

  void _paintBucketRow(
    Canvas canvas,
    FlightBucket bucket,
    int maxCount,
    double top,
    double rowHeight,
    Color accentColor,
  ) {
    final label = bucket.isUnknownType
        ? l10n.statsUnknownType
        : bucket.label.isEmpty
        ? '—'
        : bucket.displayLabel;
    final hours = bucket.duration.inHours;
    final minutes = bucket.duration.inMinutes % 60;
    final airtime = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
    final metrics = bucket.count == 0
        ? '—'
        : '${bucket.count}  ·  $airtime  ·  ${_km(bucket.distanceM, 1)}';
    _text(
      canvas,
      label,
      Offset(_margin + 24, top + 5),
      fontSize: 21,
      color: _white,
      weight: FontWeight.w600,
      maxWidth: 390,
      maxLines: 1,
    );
    _text(
      canvas,
      metrics,
      Offset(_margin + 430, top + 5),
      fontSize: 18,
      color: _muted,
      maxWidth: _contentWidth - 454,
      maxLines: 1,
      alignRight: true,
    );
    final barRect = Rect.fromLTWH(
      _margin + 24,
      top + 37,
      _contentWidth - 48,
      16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(8)),
      Paint()..color = _surfaceAlt,
    );
    final fraction = maxCount == 0 ? 0.0 : bucket.count / maxCount;
    if (fraction > 0) {
      final filled = Rect.fromLTWH(
        barRect.left,
        barRect.top,
        barRect.width * fraction.clamp(0.0, 1.0),
        barRect.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(filled, const Radius.circular(8)),
        Paint()..color = accentColor,
      );
    }
    canvas.drawLine(
      Offset(_margin + 24, top + rowHeight - 1),
      Offset(_margin + _contentWidth - 24, top + rowHeight - 1),
      Paint()..color = colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }

  void _paintFooter(Canvas canvas, double top) {
    _text(
      canvas,
      'ParaBeacon  ·  ${l10n.statsSampledFlights}: ${stats.flightsWithSamples}/${stats.flightCount}  ·  ${l10n.statsTotalSamples}: ${stats.totalSamples}',
      Offset(_margin, top + 8),
      fontSize: 19,
      color: _muted,
      maxWidth: _contentWidth,
      maxLines: 2,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
    FontWeight weight = FontWeight.normal,
    required double maxWidth,
    int maxLines = 2,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      alignRight
          ? Offset(offset.dx + maxWidth - painter.width, offset.dy)
          : offset,
    );
  }

  String _date(DateTime? date) =>
      date == null ? '—' : DateFormat.yMMMd(locale).format(date.toLocal());

  static String _km(double meters, int digits) =>
      '${(meters / 1000).toStringAsFixed(digits)} km';

  static String _duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '${minutes}m ${seconds}s';
  }
}

class _CardSection {
  const _CardSection(
    this.title, {
    this.rows,
    this.buckets,
    this.emptyMessage,
    this.rowHeight = 48,
  });

  final String title;
  final List<_CardRow>? rows;
  final List<FlightBucket>? buckets;
  final String? emptyMessage;
  final double rowHeight;
}

class _CardRow {
  const _CardRow(this.label, this.value, {this.detail});

  final String label;
  final String value;
  final String? detail;
}
