import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/weather_service.dart';

/// A Windy-style meteogram: a vertical stack of synchronized panels
/// (temperature, precipitation probability, wind speed + gusts, cloud
/// layers) sharing one horizontal time axis. The whole stack scrolls
/// horizontally; tapping an hour places the shared cursor and reports the
/// selection back via [onSelect] so the nowcast panel and the background
/// wind-flow animation stay in sync with the timeline.
///
/// Times are the forecast location's local wall clock (see the time
/// contract in weather_service.dart) — the "now" marker is placed from the
/// provider's own current time, never from the device clock.
///
/// Implemented with CustomPaint (no chart dependency) so the layout can
/// mirror Windy's aesthetic precisely and stay responsive: panels flex to
/// the available height and the pixel-per-hour density adapts to width.
class Meteogram extends StatefulWidget {
  const Meteogram({
    required this.hours,
    required this.selectedIndex,
    required this.onSelect,
    required this.labelTemp,
    required this.labelPrecip,
    required this.labelWind,
    required this.labelCloud,
    this.currentTime,
    this.dark = true,
    super.key,
  });

  /// The full hourly series — may include `past_days` history (rendered
  /// dimmed left of the now marker).
  final List<WeatherHour> hours;

  /// The provider's own current time (location-local), for the now marker.
  final DateTime? currentTime;

  /// Selected hour index (shared cursor across all panels).
  final int selectedIndex;

  /// Reports the tapped hour index.
  final ValueChanged<int> onSelect;

  /// Localized panel labels.
  final String labelTemp;
  final String labelPrecip;
  final String labelWind;
  final String labelCloud;

  /// Windy-like dark chrome (true) or theme-following light chrome.
  final bool dark;

  @override
  State<Meteogram> createState() => _MeteogramState();
}

class _MeteogramState extends State<Meteogram> {
  static const double _pxPerHour = 12.0;
  static const double _pad = 10.0;
  static const double _axisHeight = 20.0;

  final ScrollController _scroll = ScrollController();
  bool _autoScrolled = false;

  double get _contentWidth =>
      _pad * 2 + widget.hours.length * _pxPerHour;

  /// Index of the first hour at-or-after the provider's current time.
  int get _nowIndex {
    final t = widget.currentTime;
    if (t == null) return -1;
    final idx = widget.hours.indexWhere((h) => !h.time.isBefore(t));
    return idx; // -1 when unknown / before the series
  }

  @override
  void didUpdateWidget(Meteogram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hours != widget.hours) {
      _autoScrolled = false;
      _scheduleAutoScroll();
    }
  }

  @override
  void initState() {
    super.initState();
    _scheduleAutoScroll();
  }

  /// Centers the "now" marker in the viewport on first layout (and after a
  /// data reload). A no-op when the marker is unknown.
  void _scheduleAutoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoScrolled || !_scroll.hasClients) return;
      final now = _nowIndex;
      if (now < 0) return;
      final target = (_pad + now * _pxPerHour - _scroll.position.viewportDimension / 2)
          .clamp(0.0, math.max(0, _scroll.position.maxScrollExtent).toDouble());
      _scroll.jumpTo(target);
      _autoScrolled = true;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _selectAt(double localX) {
    final idx = ((localX - _pad) / _pxPerHour).round();
    if (idx < 0 || idx >= widget.hours.length) return;
    widget.onSelect(idx);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hours.isEmpty) return const SizedBox.shrink();
    final now = _nowIndex;

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _selectAt(d.localPosition.dx),
        child: SizedBox(
          width: _contentWidth,
          child: Column(
            children: [
              SizedBox(
                height: _axisHeight,
                width: _contentWidth,
                child: CustomPaint(
                  painter: _TimeAxisPainter(
                    hours: widget.hours,
                    pxPerHour: _pxPerHour,
                    pad: _pad,
                    nowIndex: now,
                    dark: widget.dark,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: CustomPaint(
                  size: Size(_contentWidth, double.infinity),
                  painter: _TempPanelPainter(
                    hours: widget.hours,
                    pxPerHour: _pxPerHour,
                    pad: _pad,
                    nowIndex: now,
                    selectedIndex: widget.selectedIndex,
                    label: widget.labelTemp,
                    dark: widget.dark,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: CustomPaint(
                  size: Size(_contentWidth, double.infinity),
                  painter: _PrecipPanelPainter(
                    hours: widget.hours,
                    pxPerHour: _pxPerHour,
                    pad: _pad,
                    nowIndex: now,
                    selectedIndex: widget.selectedIndex,
                    label: widget.labelPrecip,
                    dark: widget.dark,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: CustomPaint(
                  size: Size(_contentWidth, double.infinity),
                  painter: _WindPanelPainter(
                    hours: widget.hours,
                    pxPerHour: _pxPerHour,
                    pad: _pad,
                    nowIndex: now,
                    selectedIndex: widget.selectedIndex,
                    label: widget.labelWind,
                    dark: widget.dark,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: CustomPaint(
                  size: Size(_contentWidth, double.infinity),
                  painter: _CloudPanelPainter(
                    hours: widget.hours,
                    pxPerHour: _pxPerHour,
                    pad: _pad,
                    nowIndex: now,
                    selectedIndex: widget.selectedIndex,
                    label: widget.labelCloud,
                    dark: widget.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared palette ────────────────────────────────────────────────────────────

const Color _kTempColor = Color(0xFFFF7043);
const Color _kPrecipColor = Color(0xFF4FC3F7);
const Color _kWindColor = Color(0xFF66BB6A);
const Color _kGustColor = Color(0xFFB9F6CA);
const Color _kCloudLow = Color(0xFF78909C);
const Color _kCloudMid = Color(0xFF90A4AE);
const Color _kCloudHigh = Color(0xFFB0BEC5);

// ── Base panel painter ────────────────────────────────────────────────────────

/// Common chrome for every meteogram panel: night shading, the dimmed
/// past-zone left of the "now" marker, the now line, the selection cursor
/// and the panel label. Subclasses draw their series on top.
abstract class _PanelPainter extends CustomPainter {
  _PanelPainter({
    required this.hours,
    required this.pxPerHour,
    required this.pad,
    required this.nowIndex,
    required this.selectedIndex,
    required this.label,
    required this.dark,
  });

  final List<WeatherHour> hours;
  final double pxPerHour;
  final double pad;
  final int nowIndex;
  final int selectedIndex;
  final String label;
  final bool dark;

  Color get lineColor => dark ? Colors.white : Colors.black87;
  Color get dimColor => dark ? Colors.white : Colors.black;

  double xOf(int i) => pad + i * pxPerHour;

  /// Y helper: maps a normalized 0..1 value to the panel (padding-aware).
  double yFor(double t, double height) =>
      4 + (1 - t.clamp(0.0, 1.0)) * (height - 14);

  void paintChrome(Canvas canvas, Size size) {
    // Night shading (only when the provider supplies an is_day flag).
    for (var i = 0; i < hours.length; i++) {
      final isDay = hours[i].isDay;
      if (isDay == false) {
        final rect = Rect.fromLTWH(xOf(i) - pxPerHour / 2, 0, pxPerHour, size.height);
        canvas.drawRect(
          rect,
          Paint()..color = Colors.indigo.withAlpha(dark ? 46 : 26),
        );
      }
    }

    // Dim everything before "now" (past actuals) with a subtle veil.
    if (nowIndex > 0) {
      final pastRight = math.min(xOf(nowIndex), size.width);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, pastRight, size.height),
        Paint()..color = (dark ? Colors.black : Colors.white).withAlpha(70),
      );
    }

    // "Now" marker line.
    if (nowIndex >= 0 && nowIndex < hours.length) {
      final x = xOf(nowIndex);
      final paint = Paint()
        ..color = Colors.orangeAccent.withAlpha(200)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Selection cursor.
    if (selectedIndex >= 0 && selectedIndex < hours.length) {
      final x = xOf(selectedIndex);
      final paint = Paint()
        ..color = Colors.white.withAlpha(dark ? 90 : 60)
        ..strokeWidth = pxPerHour * 0.7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final paintLine = Paint()
        ..color = lineColor.withAlpha(160)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintLine);
    }

    // Panel label (top-left).
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: dimColor.withAlpha(150),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(4, 3));
  }

  /// Smooth polyline through the points (quadratic midpoint smoothing).
  Path smoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final midX = (prev.dx + cur.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
    }
    return path;
  }

  void dashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 4, double gap = 3}) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len;
    final uy = dy / len;
    var drawn = 0.0;
    while (drawn < len) {
      final end = math.min(drawn + dash, len);
      canvas.drawLine(
        Offset(a.dx + ux * drawn, a.dy + uy * drawn),
        Offset(a.dx + ux * end, a.dy + uy * end),
        paint,
      );
      drawn = end + gap;
    }
  }

  void paintValueTag(Canvas canvas, Offset at, String text, Color color,
      {bool above = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = above ? at.dy - tp.height - 2 : at.dy + 2;
    final dx = (at.dx - tp.width / 2).clamp(0.0, 10000.0);
    tp.paint(canvas, Offset(dx, dy));
  }
}

// ── Time axis ────────────────────────────────────────────────────────────────

class _TimeAxisPainter extends CustomPainter {
  _TimeAxisPainter({
    required this.hours,
    required this.pxPerHour,
    required this.pad,
    required this.nowIndex,
    required this.dark,
  });

  final List<WeatherHour> hours;
  final double pxPerHour;
  final double pad;
  final int nowIndex;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final color = (dark ? Colors.white : Colors.black87).withAlpha(170);
    final labelEvery = pxPerHour >= 10 ? 3 : 6;

    // Day separators + weekday labels at each local midnight.
    var lastDay = -1;
    for (var i = 0; i < hours.length; i++) {
      final t = hours[i].time;
      if (t.day != lastDay) {
        lastDay = t.day;
        final x = pad + i * pxPerHour;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = color.withAlpha(60)
            ..strokeWidth = 1,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: _weekday(t),
            style: TextStyle(fontSize: 9.5, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 3, size.height - tp.height));
      }
      // Hour tick labels at 0/3/6/… local hours.
      if (t.hour % labelEvery == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: t.hour.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 9,
              color: t.hour == 0 ? Colors.transparent : color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(pad + i * pxPerHour - tp.width / 2, size.height - tp.height),
        );
      }
    }
  }

  String _weekday(DateTime t) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[t.weekday - 1];
  }

  @override
  bool shouldRepaint(_TimeAxisPainter old) =>
      hours != old.hours ||
      nowIndex != old.nowIndex ||
      dark != old.dark ||
      pxPerHour != old.pxPerHour;
}

// ── Temperature panel ────────────────────────────────────────────────────────

class _TempPanelPainter extends _PanelPainter {
  _TempPanelPainter({
    required super.hours,
    required super.pxPerHour,
    required super.pad,
    required super.nowIndex,
    required super.selectedIndex,
    required super.label,
    required super.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintChrome(canvas, size);
    final temps = hours.map((h) => h.temperature).toList();
    final minT = temps.reduce(math.min);
    final maxT = temps.reduce(math.max);
    final span = math.max(2.0, maxT - minT);
    double y(double v) => yFor((v - minT + span * 0.08) / (span * 1.16), size.height);

    final pts = [
      for (var i = 0; i < hours.length; i++) Offset(xOf(i), y(temps[i])),
    ];
    if (pts.isEmpty) return;

    // Gradient area fill under the line.
    final line = smoothPath(pts);
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kTempColor.withAlpha(90), _kTempColor.withAlpha(4)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = _kTempColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Min / max tags at the extremes.
    final maxI = temps.indexOf(maxT);
    final minI = temps.indexOf(minT);
    paintValueTag(canvas, pts[maxI], '${maxT.round()}°', _kTempColor);
    paintValueTag(canvas, pts[minI], '${minT.round()}°', _kTempColor,
        above: false);
  }

  @override
  bool shouldRepaint(_TempPanelPainter old) =>
      hours != old.hours ||
      selectedIndex != old.selectedIndex ||
      nowIndex != old.nowIndex ||
      dark != old.dark;
}

// ── Precipitation panel ──────────────────────────────────────────────────────

class _PrecipPanelPainter extends _PanelPainter {
  _PrecipPanelPainter({
    required super.hours,
    required super.pxPerHour,
    required super.pad,
    required super.nowIndex,
    required super.selectedIndex,
    required super.label,
    required super.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintChrome(canvas, size);

    // 50% guide line.
    dashedLine(
      canvas,
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..color = lineColor.withAlpha(35)
        ..strokeWidth = 1,
    );

    final barW = math.max(2.0, pxPerHour * 0.55);
    for (var i = 0; i < hours.length; i++) {
      final prob = hours[i].precipProbability / 100;
      if (prob <= 0.005) continue;
      final h = prob * (size.height - 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            xOf(i) - barW / 2,
            size.height - 4 - h,
            barW,
            h,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = _kPrecipColor.withAlpha(230),
      );
    }
  }

  @override
  bool shouldRepaint(_PrecipPanelPainter old) =>
      hours != old.hours ||
      selectedIndex != old.selectedIndex ||
      nowIndex != old.nowIndex ||
      dark != old.dark;
}

// ── Wind panel ───────────────────────────────────────────────────────────────

class _WindPanelPainter extends _PanelPainter {
  _WindPanelPainter({
    required super.hours,
    required super.pxPerHour,
    required super.pad,
    required super.nowIndex,
    required super.selectedIndex,
    required super.label,
    required super.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintChrome(canvas, size);

    final speeds = hours.map((h) => h.windSpeed).toList();
    final gusts = hours.map((h) => h.windGusts).toList();
    final maxV = math.max(
      speeds.isEmpty ? 0.0 : speeds.reduce(math.max),
      gusts.isEmpty ? 0.0 : gusts.reduce(math.max),
    );
    final scale = math.max(5.0, maxV * 1.15);
    double y(double v) => yFor(v / scale, size.height);

    // Gusts: dashed, lighter.
    final gustPts = [
      for (var i = 0; i < hours.length; i++) Offset(xOf(i), y(gusts[i])),
    ];
    canvas.drawPath(
      smoothPath(gustPts),
      Paint()
        ..color = _kGustColor.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Mean speed: solid.
    final pts = [
      for (var i = 0; i < hours.length; i++) Offset(xOf(i), y(speeds[i])),
    ];
    canvas.drawPath(
      smoothPath(pts),
      Paint()
        ..color = _kWindColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Wind-direction chevrons along the bottom (pointing where the wind
    // blows TO: Open-Meteo's direction is where it comes FROM).
    const arrowEvery = 3;
    final arrowPaint = Paint()
      ..color = _kWindColor.withAlpha(190)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < hours.length; i += arrowEvery) {
      final dir = hours[i].windDirection + 180; // FROM → TO
      final cx = xOf(i);
      final cy = size.height - 5;
      final r = 3.4;
      final rad = dir * math.pi / 180;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rad);
      final tip = Offset(r, 0);
      canvas.drawLine(Offset(-r * 0.7, 0), tip, arrowPaint);
      canvas.drawLine(tip, Offset(r * 0.25, -r * 0.5), arrowPaint);
      canvas.drawLine(tip, Offset(r * 0.25, r * 0.5), arrowPaint);
      canvas.restore();
    }

    // Scale tag: peak gust.
    if (gusts.isNotEmpty) {
      paintValueTag(
        canvas,
        Offset(xOf(gusts.indexOf(gusts.reduce(math.max))), y(gusts.reduce(math.max))),
        '${gusts.reduce(math.max).round()}',
        _kGustColor.withAlpha(220),
      );
    }
  }

  @override
  bool shouldRepaint(_WindPanelPainter old) =>
      hours != old.hours ||
      selectedIndex != old.selectedIndex ||
      nowIndex != old.nowIndex ||
      dark != old.dark;
}

// ── Cloud panel ──────────────────────────────────────────────────────────────

class _CloudPanelPainter extends _PanelPainter {
  _CloudPanelPainter({
    required super.hours,
    required super.pxPerHour,
    required super.pad,
    required super.nowIndex,
    required super.selectedIndex,
    required super.label,
    required super.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintChrome(canvas, size);
    _layer(canvas, size, (h) => h.cloudHigh, _kCloudHigh);
    _layer(canvas, size, (h) => h.cloudMid, _kCloudMid);
    _layer(canvas, size, (h) => h.cloudLow, _kCloudLow);
  }

  /// Draws one cloud layer as a translucent area. Values are already in
  /// percent; null (model without the variable) renders as gaps.
  void _layer(Canvas canvas, Size size,
      double? Function(WeatherHour h) f, Color color) {
    final pts = <Offset>[];
    for (var i = 0; i < hours.length; i++) {
      final v = f(hours[i]);
      if (v == null) continue;
      pts.add(Offset(xOf(i), yFor(v / 100, size.height)));
    }
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, size.height);
    path.lineTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final midX = (pts[i - 1].dx + pts[i].dx) / 2;
      path.cubicTo(midX, pts[i - 1].dy, midX, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    path.lineTo(pts.last.dx, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color.withAlpha(80));
  }

  @override
  bool shouldRepaint(_CloudPanelPainter old) =>
      hours != old.hours ||
      selectedIndex != old.selectedIndex ||
      nowIndex != old.nowIndex ||
      dark != old.dark;
}
