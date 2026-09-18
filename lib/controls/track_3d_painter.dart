import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

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
    var minE = double.infinity;
    var maxE = -double.infinity;
    var minN = double.infinity;
    var maxN = -double.infinity;
    for (final s in samples) {
      final e = (s.data.longitude - lon0) * mPerDegLon;
      final n = (s.data.latitude - lat0) * mPerDegLat;
      final u = s.data.altitude - minAlt;
      pts3.add(_V3(e, n, u));
      minE = math.min(minE, e);
      maxE = math.max(maxE, e);
      minN = math.min(minN, n);
      maxN = math.max(maxN, n);
    }

    // ── 2. Perspective camera: yaw around Z, then pitch toward the ground.
    // The finite camera distance makes parallel ground lines converge toward
    // a vanishing point, matching a real 3D map rather than an orthographic
    // chart. Higher pitch values reveal more of the ground plane.
    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);
    final trackSpan = math.max(maxE - minE, maxN - minN);
    final gridHalf = math.max(50.0, trackSpan * 0.75);
    final cameraDistance = math.max(100.0, trackSpan * 1.8);
    final focalLength = cameraDistance;

    Offset project(double e, double n, double u) {
      final x1 = e * cosY - n * sinY;
      final y1 = e * sinY + n * cosY;
      final z1 = u * zScale;
      final depth = y1 * cosP - z1 * sinP;
      final perspective = focalLength /
          math.max(1.0, cameraDistance + depth);
      final screenY = (y1 * sinP + z1 * cosP) * perspective;
      return Offset(x1 * perspective, -screenY);
    }

    final projected = <Offset>[];
    final groundProjected = <Offset>[];
    final gridSegments = <List<Offset>>[];
    double minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;

    void include(Offset p) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    for (final v in pts3) {
      final p = project(v.e, v.n, v.u);
      final g = project(v.e, v.n, 0);
      projected.add(p);
      groundProjected.add(g);
      include(p);
      include(g);
    }

    // Draw a regular ground-plane grid. The perspective projection turns the
    // cross-plane lines into the trapezoidal wireframe shown in the reference.
    const gridSteps = 10;
    for (var i = 0; i <= gridSteps; i++) {
      final t = -gridHalf + (gridHalf * 2 * i / gridSteps);
      final across = [
        project(-gridHalf, t, 0),
        project(gridHalf, t, 0),
      ];
      final along = [
        project(t, -gridHalf, 0),
        project(t, gridHalf, 0),
      ];
      gridSegments.add(across);
      gridSegments.add(along);
      include(across[0]);
      include(across[1]);
      include(along[0]);
      include(along[1]);
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

    // ── 4. Perspective ground grid, behind the flight track. ─────────────
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (final segment in gridSegments) {
      canvas.drawLine(
        toScreen(segment[0]),
        toScreen(segment[1]),
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

    // ── 6. Ground shadow polyline. ─────────────────────────────────────────
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

    // ── 7. The 3D track, colored by vario. ─────────────────────────────────
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

    // ── 8. Start / end / cursor markers. ───────────────────────────────────
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
