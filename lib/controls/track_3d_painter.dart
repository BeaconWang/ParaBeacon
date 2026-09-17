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
