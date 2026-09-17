import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/flight_recorder.dart';

/// Renders a flight track as a projected 3D polyline: X/Y are the ground plane
/// (meters east/north of the track centroid) and Z is altitude (meters above
/// the track's minimum), with an adjustable vertical exaggeration.
///
/// The projection is a simple yaw→pitch orthographic camera — enough to give a
/// readable sense of thermalling and glides without a full 3D engine. The line
/// is colored by vertical speed (vario): sink → cool, lift → warm, mirroring
/// the 2D replay's ramp. A drop-line to the ground plane and a coarse grid give
/// depth cues, and a marker shows the current playback cursor.
///
/// Self-contained port of the reference project's `Track3DPainter`, adapted to
/// this project's [FlightSample] model.
class Track3DPainter extends CustomPainter {
  Track3DPainter({
    required this.samples,
    required this.yaw,
    required this.pitch,
    required this.zScale,
    required this.cursorIndex,
    required this.gridColor,
    required this.background,
  });

  final List<FlightSample> samples;
  final double yaw;
  final double pitch;
  final double zScale;
  final int cursorIndex;
  final Color gridColor;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (samples.length < 2) return;

    // ── 1. Project each sample to local meters (east, north, up). ─────────
    final lat0 = samples
            .map((s) => s.data.latitude)
            .reduce((a, b) => a + b) /
        samples.length;
    final lon0 = samples
            .map((s) => s.data.longitude)
            .reduce((a, b) => a + b) /
        samples.length;
    final minAlt =
        samples.map((s) => s.data.altitude).reduce(math.min);

    const mPerDegLat = 111320.0;
    final mPerDegLon = 111320.0 * math.cos(lat0 * math.pi / 180.0);

    final pts3 = <_V3>[];
    for (final s in samples) {
      final e = (s.data.longitude - lon0) * mPerDegLon;
      final n = (s.data.latitude - lat0) * mPerDegLat;
      final u = (s.data.altitude - minAlt);
      pts3.add(_V3(e, n, u));
    }

    // ── 2. Rotate by yaw (about up axis) then pitch (about east axis). ────
    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);

    final projected = <Offset>[];
    final groundProjected = <Offset>[];
    double minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;

    Offset project(double e, double n, double u) {
      // Yaw about vertical axis (rotates east/north).
      final x1 = e * cosY - n * sinY;
      final y1 = e * sinY + n * cosY;
      final z1 = u * zScale;
      // Pitch: tilt the world so higher pitch looks more top-down.
      final screenX = x1;
      final screenY = y1 * cosP - z1 * sinP;
      return Offset(screenX, -screenY);
    }

    for (final v in pts3) {
      final p = project(v.e, v.n, v.u);
      final g = project(v.e, v.n, 0);
      projected.add(p);
      groundProjected.add(g);
      minX = math.min(minX, math.min(p.dx, g.dx));
      maxX = math.max(maxX, math.max(p.dx, g.dx));
      minY = math.min(minY, math.min(p.dy, g.dy));
      maxY = math.max(maxY, math.max(p.dy, g.dy));
    }

    // ── 3. Fit-to-view transform (uniform scale + center). ────────────────
    final spanX = math.max(1.0, maxX - minX);
    final spanY = math.max(1.0, maxY - minY);
    const pad = 32.0;
    final scale = math.min(
      (size.width - pad * 2) / spanX,
      (size.height - pad * 2) / spanY,
    );
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;

    Offset toScreen(Offset p) => Offset(
          size.width / 2 + (p.dx - cx) * scale,
          size.height / 2 + (p.dy - cy) * scale,
        );

    // ── 4. Drop-lines to the ground plane (subtle depth cue). ──────────────
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

    // ── 5. Ground shadow polyline. ─────────────────────────────────────────
    final shadowPath = Path();
    for (var i = 0; i < groundProjected.length; i++) {
      final s = toScreen(groundProjected[i]);
      if (i == 0) {
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

    // ── 6. The 3D track, colored by vario. ─────────────────────────────────
    for (var i = 1; i < projected.length; i++) {
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

    // ── 7. Start / end / cursor markers. ───────────────────────────────────
    final startPaint = Paint()..color = Colors.green;
    final endPaint = Paint()..color = Colors.red;
    canvas.drawCircle(toScreen(projected.first), 5, startPaint);
    canvas.drawCircle(toScreen(projected.last), 5, endPaint);

    final ci = cursorIndex.clamp(0, projected.length - 1);
    final cursor = toScreen(projected[ci]);
    canvas.drawCircle(
      cursor,
      8,
      Paint()..color = Colors.white.withAlpha(220),
    );
    canvas.drawCircle(cursor, 5, Paint()..color = Colors.blueAccent);

    // A single point-mode dot ensures the cursor is crisp on all backends.
    canvas.drawPoints(
      PointMode.points,
      [cursor],
      Paint()
        ..color = Colors.blueAccent
        ..strokeWidth = 2,
    );
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
        old.cursorIndex != cursorIndex ||
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

/// A replay point in the map's rendered coordinate system.
@immutable
class Track3DMapPoint {
  const Track3DMapPoint({
    required this.point,
    required this.altitude,
    required this.verticalSpeed,
    required this.sampleIndex,
  });

  final LatLng point;
  final double altitude;
  final double verticalSpeed;
  final int sampleIndex;
}

/// Paints an altitude-aware replay track directly over a [FlutterMap].
///
/// The geographic position remains anchored to the map camera while altitude is
/// represented by a screen-space lift, a ground shadow, and drop-lines. This
/// keeps the 3D track aligned during pan, zoom, and map rotation instead of
/// rendering it in a separate non-geographic canvas.
class Track3DMapLayer extends StatelessWidget {
  const Track3DMapLayer({
    super.key,
    required this.points,
    required this.cursorIndex,
    required this.yaw,
    required this.pitch,
    required this.zScale,
    required this.gridColor,
    required this.colorFor,
  });

  final List<Track3DMapPoint> points;
  final int cursorIndex;
  final double yaw;
  final double pitch;
  final double zScale;
  final Color gridColor;
  final Color Function(Track3DMapPoint point, bool dimmed) colorFor;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: CustomPaint(
        size: Size.infinite,
        painter: Track3DMapPainter(
          camera: camera,
          points: points,
          cursorIndex: cursorIndex,
          yaw: yaw,
          pitch: pitch,
          zScale: zScale,
          gridColor: gridColor,
          colorFor: colorFor,
        ),
      ),
    );
  }
}

class Track3DMapPainter extends CustomPainter {
  Track3DMapPainter({
    required this.camera,
    required this.points,
    required this.cursorIndex,
    required this.yaw,
    required this.pitch,
    required this.zScale,
    required this.gridColor,
    required this.colorFor,
  });

  final MapCamera camera;
  final List<Track3DMapPoint> points;
  final int cursorIndex;
  final double yaw;
  final double pitch;
  final double zScale;
  final Color gridColor;
  final Color Function(Track3DMapPoint point, bool dimmed) colorFor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;

    final minAltitude = points
        .map((p) => p.altitude)
        .where((altitude) => altitude.isFinite)
        .fold<double>(double.infinity, math.min);
    if (!minAltitude.isFinite) return;

    final metersPerPixel = _metersPerPixel(camera);
    final maxLift = math.max(size.width, size.height) * 0.7;
    final liftDirection = Offset(math.cos(yaw), -math.sin(yaw));
    final liftFactor = math.sin(pitch).clamp(0.0, 1.0);

    // Apply a lightweight perspective transform around the map viewport. This
    // keeps the track geographically anchored while making the elevated path
    // read as a tilted 3D scene without requiring a 3D map engine.
    final viewportCenter = Offset(size.width / 2, size.height / 2);
    final cameraDistance = math.max(180.0, math.max(size.width, size.height) * 1.15);
    Offset perspective(Offset point) {
      final depth = (point.dy - viewportCenter.dy) * math.sin(pitch);
      final denominator = math.max(80.0, cameraDistance + depth * 0.5);
      final scale = cameraDistance / denominator;
      return viewportCenter + (point - viewportCenter) * scale;
    }

    final ground = <Offset>[];
    final elevated = <Offset>[];
    for (final point in points) {
      final groundPoint = camera.getOffsetFromOrigin(point.point);
      final altitude = math.max(0.0, point.altitude - minAltitude);
      final rawLift = altitude / metersPerPixel * zScale * liftFactor;
      final lift = rawLift.clamp(0.0, maxLift);
      ground.add(perspective(groundPoint));
      elevated.add(perspective(groundPoint + liftDirection * -lift));
    }

    final shadowPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawPath(canvas, ground, shadowPaint);

    final dropPaint = Paint()
      ..color = gridColor.withAlpha(110)
      ..strokeWidth = 1.0;
    final step = math.max(1, (points.length / 60).ceil());
    for (var i = 0; i < points.length; i += step) {
      canvas.drawLine(elevated[i], ground[i], dropPaint);
    }
    if ((points.length - 1) % step != 0) {
      final last = points.length - 1;
      canvas.drawLine(elevated[last], ground[last], dropPaint);
    }

    for (var i = 1; i < points.length; i++) {
      final dimmed = points[i].sampleIndex > cursorIndex;
      final color = colorFor(points[i], dimmed);
      canvas.drawLine(
        elevated[i - 1],
        elevated[i],
        Paint()
          ..color = color
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    final startPaint = Paint()..color = Colors.greenAccent;
    final endPaint = Paint()..color = Colors.redAccent;
    canvas.drawCircle(elevated.first, 5, startPaint);
    canvas.drawCircle(elevated.last, 5, endPaint);

    final cursorPoint = _cursorPoint(elevated);
    if (cursorPoint != null) {
      canvas.drawCircle(cursorPoint, 9, Paint()..color = Colors.white.withAlpha(210));
      canvas.drawCircle(cursorPoint, 6, Paint()..color = Colors.blueAccent);
    }
  }

  Offset? _cursorPoint(List<Offset> elevated) {
    if (elevated.isEmpty) return null;
    var best = 0;
    var bestDistance = (points.first.sampleIndex - cursorIndex).abs();
    for (var i = 1; i < points.length; i++) {
      final distance = (points[i].sampleIndex - cursorIndex).abs();
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return elevated[best];
  }

  static double _metersPerPixel(MapCamera camera) {
    final cosLat = math.cos(camera.center.latitude * math.pi / 180).abs();
    final value = 156543.03392 * cosLat / math.pow(2, camera.zoom);
    return value.isFinite && value > 0 ? value : 1.0;
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant Track3DMapPainter old) {
    return old.camera.center != camera.center ||
        old.camera.zoom != camera.zoom ||
        old.camera.rotation != camera.rotation ||
        old.points != points ||
        old.cursorIndex != cursorIndex ||
        old.yaw != yaw ||
        old.pitch != pitch ||
        old.zScale != zScale ||
        old.gridColor != gridColor ||
        old.colorFor != colorFor;
  }
}
