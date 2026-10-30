import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../data/flight_recorder.dart';
import 'track_3d_map.dart';

/// Renders a flight track as a projected 3D polyline: X/Y are the ground plane
/// (meters east/north of the track centroid) and Z is altitude (meters above
/// the track's minimum), with uniform view zoom and adjustable vertical
/// exaggeration.
///
/// The projection is a simple yaw→pitch orthographic camera — enough to give a
/// readable sense of thermalling and glides without a full 3D engine. The line
/// is colored by vertical speed (vario): sink → cool, lift → warm, mirroring
/// the 2D replay's ramp. A drop-line to the ground plane and a coarse grid give
/// depth cues, and a marker shows the current playback cursor.
///
/// Self-contained port of the reference project's `Track3DPainter`, adapted to
/// this project's [FlightSample] model.
class Track3DGeometryCache {
  Track3DGeometryCache(this.samples);

  final List<FlightSample> samples;
  _Track3DGeometry? _cached;

  _Track3DGeometry _geometry({
    required double yaw,
    required double pitch,
    required double zScale,
    required double zoom,
    required Size size,
  }) {
    final cached = _cached;
    if (cached != null &&
        cached.yaw == yaw &&
        cached.pitch == pitch &&
        cached.zScale == zScale &&
        cached.zoom == zoom &&
        cached.size == size) {
      return cached;
    }

    var latitudeSum = 0.0;
    var longitudeSum = 0.0;
    var minAltitude = double.infinity;
    for (final sample in samples) {
      latitudeSum += sample.data.latitude;
      longitudeSum += sample.data.longitude;
      minAltitude = math.min(minAltitude, sample.data.altitude);
    }
    final lat0 = latitudeSum / samples.length;
    final lon0 = longitudeSum / samples.length;
    const mPerDegLat = 111320.0;
    final mPerDegLon = 111320.0 * math.cos(lat0 * math.pi / 180.0);

    final points3d = <_V3>[];
    var minE = double.infinity;
    var maxE = double.negativeInfinity;
    var minN = double.infinity;
    var maxN = double.negativeInfinity;
    for (final sample in samples) {
      final e = (sample.data.longitude - lon0) * mPerDegLon;
      final n = (sample.data.latitude - lat0) * mPerDegLat;
      points3d.add(_V3(e, n, sample.data.altitude - minAltitude));
      minE = math.min(minE, e);
      maxE = math.max(maxE, e);
      minN = math.min(minN, n);
      maxN = math.max(maxN, n);
    }

    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);
    final trackSpan = math.max(maxE - minE, maxN - minN);
    final gridHalf = math.max(50.0, trackSpan * 0.75);
    final cameraDistance = math.max(100.0, trackSpan * 1.8);

    Offset project(double e, double n, double u) {
      final x1 = e * cosY - n * sinY;
      final y1 = e * sinY + n * cosY;
      final z1 = u * zScale;
      final depth = y1 * cosP - z1 * sinP;
      final perspective =
          cameraDistance / math.max(1.0, cameraDistance + depth);
      final screenY = (y1 * sinP + z1 * cosP) * perspective;
      return Offset(x1 * perspective, -screenY);
    }

    final projected = <Offset>[];
    final groundProjected = <Offset>[];
    final gridSegments = <Offset>[];
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    void include(Offset point) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    for (final point in points3d) {
      final projectedPoint = project(point.e, point.n, point.u);
      final groundPoint = project(point.e, point.n, 0);
      projected.add(projectedPoint);
      groundProjected.add(groundPoint);
      include(projectedPoint);
      include(groundPoint);
    }

    const gridSteps = 10;
    for (var i = 0; i <= gridSteps; i++) {
      final t = -gridHalf + (gridHalf * 2 * i / gridSteps);
      final acrossStart = project(-gridHalf, t, 0);
      final acrossEnd = project(gridHalf, t, 0);
      final alongStart = project(t, -gridHalf, 0);
      final alongEnd = project(t, gridHalf, 0);
      gridSegments
        ..add(acrossStart)
        ..add(acrossEnd)
        ..add(alongStart)
        ..add(alongEnd);
      include(acrossStart);
      include(acrossEnd);
      include(alongStart);
      include(alongEnd);
    }

    final spanX = math.max(1.0, maxX - minX);
    final spanY = math.max(1.0, maxY - minY);
    const pad = 32.0;
    final scale = math.min(
      (size.width - pad * 2) / spanX,
      (size.height - pad * 2) / spanY,
    );
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    Offset cameraZoom(Offset point) => Offset(
      centerX + (point.dx - centerX) * zoom,
      centerY + (point.dy - centerY) * zoom,
    );
    _cached = _Track3DGeometry(
      yaw: yaw,
      pitch: pitch,
      zScale: zScale,
      zoom: zoom,
      cameraDistance: cameraDistance,
      size: size,
      projected: [for (final point in projected) cameraZoom(point)],
      groundProjected: [for (final point in groundProjected) cameraZoom(point)],
      gridSegments: [for (final point in gridSegments) cameraZoom(point)],
      scale: scale,
      centerX: centerX,
      centerY: centerY,
    );
    return _cached!;
  }
}

class _Track3DGeometry implements Track3DGroundProjector {
  const _Track3DGeometry({
    required this.yaw,
    required this.pitch,
    required this.zScale,
    required this.zoom,
    required this.cameraDistance,
    required this.size,
    required this.projected,
    required this.groundProjected,
    required this.gridSegments,
    required this.scale,
    required this.centerX,
    required this.centerY,
  });

  final double yaw;
  final double pitch;
  final double zScale;
  final double zoom;
  final double cameraDistance;
  final Size size;
  final List<Offset> projected;
  final List<Offset> groundProjected;
  final List<Offset> gridSegments;
  final double scale;
  final double centerX;
  final double centerY;

  Offset toScreen(Offset point) => Offset(
    size.width / 2 + (point.dx - centerX) * scale,
    size.height / 2 + (point.dy - centerY) * scale,
  );

  @override
  Offset projectGround(double east, double north) {
    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);
    final x1 = east * cosY - north * sinY;
    final y1 = east * sinY + north * cosY;
    final perspective =
        cameraDistance / math.max(1.0, cameraDistance + y1 * cosP);
    return Offset(
      size.width / 2 + (x1 * perspective - centerX) * scale * zoom,
      size.height / 2 + (-y1 * sinP * perspective - centerY) * scale * zoom,
    );
  }
}

class Track3DPainter extends CustomPainter {
  Track3DPainter({
    required this.samples,
    required this.yaw,
    required this.pitch,
    required this.zScale,
    required this.zoom,
    required this.cursorIndex,
    required this.geometryCache,
    required this.gridColor,
    required this.background,
    this.gapAfterIndices = const <int>{},
    this.cursorInGap = false,
    this.gapColor = const Color(0xFFFF9800),
    this.groundMap,
  });

  final List<FlightSample> samples;
  final double yaw;
  final double pitch;
  final double zScale;
  final double zoom;
  final int cursorIndex;
  final Track3DGeometryCache geometryCache;
  final Color gridColor;
  final Color background;

  /// Sample indices whose segment from the previous sample spans a
  /// missing-data period. Those segments are drawn as dashed gap connectors.
  final Set<int> gapAfterIndices;

  /// Whether the playback cursor is currently inside a missing-data period.
  final bool cursorInGap;
  final Color gapColor;
  final Track3DGroundMap? groundMap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (samples.length < 2) return;

    final geometry = geometryCache._geometry(
      yaw: yaw,
      pitch: pitch,
      zScale: zScale,
      zoom: zoom,
      size: size,
    );
    final projected = geometry.projected;
    final groundProjected = geometry.groundProjected;
    final gridSegments = geometry.gridSegments;
    Offset toScreen(Offset p) => geometry.toScreen(p);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    groundMap?.paint(canvas, geometry);

    // ── 4. Perspective ground grid, behind the flight track. ─────────────
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < gridSegments.length; i += 2) {
      canvas.drawLine(
        toScreen(gridSegments[i]),
        toScreen(gridSegments[i + 1]),
        gridPaint,
      );
    }

    // ── 5. Drop-lines to the ground plane (subtle depth cue). ──────────────
    final dropPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final step = math.max(1, (samples.length / 60).floor());
    for (var i = 0; i < samples.length; i += step) {
      canvas.drawLine(
        toScreen(projected[i]),
        toScreen(groundProjected[i]),
        dropPaint,
      );
    }

    // ── 6. Ground shadow polyline (broken at missing-data periods). ────────
    final shadowPath = Path();
    for (var i = 0; i < groundProjected.length; i++) {
      final s = toScreen(groundProjected[i]);
      if (i == 0 || gapAfterIndices.contains(i)) {
        shadowPath.moveTo(s.dx, s.dy);
      } else {
        shadowPath.lineTo(s.dx, s.dy);
      }
    }
    canvas.drawPath(
      shadowPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = gridColor,
    );

    // ── 7. The 3D track, colored by vario; gaps are dashed connectors. ────
    final gapPaint = Paint()
      ..color = gapColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < projected.length; i++) {
      if (gapAfterIndices.contains(i)) {
        _drawDashed(
          canvas,
          toScreen(projected[i - 1]),
          toScreen(projected[i]),
          gapPaint,
        );
        canvas.drawCircle(toScreen(projected[i - 1]), 4, gapPaint);
        canvas.drawCircle(toScreen(projected[i]), 4, gapPaint);
        continue;
      }
      final v = samples[i].data.verticalSpeed;
      final paint = Paint()
        ..color = _varioColor(v)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        toScreen(projected[i - 1]),
        toScreen(projected[i]),
        paint,
      );
    }

    // ── 8. Start / end / cursor markers. ───────────────────────────────────
    final startPaint = Paint()..color = Colors.green;
    final endPaint = Paint()..color = Colors.red;
    canvas.drawCircle(toScreen(projected.first), 5, startPaint);
    canvas.drawCircle(toScreen(projected.last), 5, endPaint);

    final ci = cursorIndex.clamp(0, projected.length - 1);
    final cursorColor = cursorInGap ? gapColor : Colors.blueAccent;
    final cursor = toScreen(projected[ci]);
    canvas.drawCircle(cursor, 8, Paint()..color = Colors.white.withAlpha(220));
    canvas.drawCircle(cursor, 5, Paint()..color = cursorColor);

    // A single point-mode dot ensures the cursor is crisp on all backends.
    canvas.drawPoints(
      PointMode.points,
      [cursor],
      Paint()
        ..color = cursorColor
        ..strokeWidth = 2,
    );
    canvas.restore();
    final mapAttribution = groundMap?.source.attribution;
    if (mapAttribution != null) {
      _paintMapAttribution(canvas, size, mapAttribution);
    }
  }

  void _paintMapAttribution(Canvas canvas, Size size, String attribution) {
    final painter = TextPainter(
      text: TextSpan(
        text: attribution,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, size.width - 24));
    const padding = 5.0;
    final rect = Rect.fromLTWH(
      size.width - painter.width - padding * 2 - 8,
      size.height - painter.height - padding * 2 - 8,
      painter.width + padding * 2,
      painter.height + padding * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = Colors.black.withAlpha(170),
    );
    painter.paint(canvas, Offset(rect.left + padding, rect.top + padding));
  }

  static void _drawDashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 7.0;
    const space = 5.0;
    final delta = b - a;
    final length = delta.distance;
    if (length < 1) return;
    final dir = delta / length;
    var t = 0.0;
    while (t < length) {
      final end = math.min(t + dash, length);
      canvas.drawLine(a + dir * t, a + dir * end, paint);
      t = end + space;
    }
  }

  /// Vario → color ramp: strong sink (blue) → neutral (grey) → strong lift
  /// (amber/red). Matches the palette used by the 2D replay.
  Color _varioColor(double v) {
    if (v.isNaN) return Colors.grey;
    if (v >= 0) {
      final t = (v / 3.0).clamp(0.0, 1.0);
      return Color.lerp(Colors.grey, Colors.redAccent, t)!;
    } else {
      final t = (-v / 3.0).clamp(0.0, 1.0);
      return Color.lerp(Colors.grey, Colors.blueAccent, t)!;
    }
  }

  @override
  bool shouldRepaint(covariant Track3DPainter old) {
    return old.samples != samples ||
        old.yaw != yaw ||
        old.pitch != pitch ||
        old.zScale != zScale ||
        old.zoom != zoom ||
        old.groundMap != groundMap ||
        old.cursorIndex != cursorIndex ||
        old.cursorInGap != cursorInGap ||
        old.gapAfterIndices != gapAfterIndices ||
        old.gridColor != gridColor ||
        old.background != background;
  }
}

class _V3 {
  const _V3(this.e, this.n, this.u);
  final double e; // east, meters
  final double n; // north, meters
  final double u; // up (altitude), meters
}
