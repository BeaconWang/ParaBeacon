import 'dart:math' as math;

import 'package:flutter/material.dart';

class AboutInfoSphere extends StatefulWidget {
  const AboutInfoSphere({
    required this.labels,
    required this.semanticsLabel,
    required this.dragHint,
    super.key,
  });

  final List<String> labels;
  final String semanticsLabel;
  final String dragHint;

  @override
  State<AboutInfoSphere> createState() => _AboutInfoSphereState();
}

class _AboutInfoSphereState extends State<AboutInfoSphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;
  double _yaw = -0.24;
  double _pitch = 0.08;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return Semantics(
      label: '${widget.semanticsLabel} ${widget.labels.join('. ')}',
      hint: widget.dragHint,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            height: 300,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    final radius =
                        math.min(constraints.maxWidth, constraints.maxHeight) *
                        0.41;
                    _yaw += details.delta.dx / radius;
                    _pitch = (_pitch + details.delta.dy / radius).clamp(
                      -1.15,
                      1.15,
                    );
                  });
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _AboutSpherePainter(
                    labels: widget.labels,
                    yaw: _yaw,
                    pitch: _pitch,
                    rotation: _rotation,
                    textDirection: textDirection,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutSpherePainter extends CustomPainter {
  _AboutSpherePainter({
    required this.labels,
    required this.yaw,
    required this.pitch,
    required this.rotation,
    required this.textDirection,
  }) : super(repaint: rotation);

  final List<String> labels;
  final double yaw;
  final double pitch;
  final Animation<double> rotation;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.41;
    final currentYaw = yaw + rotation.value * math.pi * 2;
    final sphereBounds = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center.translate(0, radius * 0.08),
      radius * 1.04,
      Paint()
        ..color = const Color(0xFF4DD0E1).withValues(alpha: 0.055)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    canvas.drawCircle(
      center.translate(0, radius * 0.08),
      radius * 1.09,
      Paint()
        ..color = const Color(0xFF78E4EC).withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center.translate(0, radius * 0.08),
      radius * 1.14,
      Paint()
        ..color = const Color(0xFF78E4EC).withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      center.translate(0, radius * 0.1),
      radius,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.16),
    );

    final spherePath = Path()..addOval(sphereBounds);
    canvas.save();
    canvas.clipPath(spherePath);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.32, -0.38),
          radius: 1.2,
          colors: [
            Color(0xFF318FA5),
            Color(0xFF14546F),
            Color(0xFF09243A),
            Color(0xFF06111F),
          ],
          stops: [0, 0.38, 0.76, 1],
        ).createShader(sphereBounds),
    );

    _drawSphericalGrid(canvas, center, radius, currentYaw);
    _drawSurfaceLabels(canvas, center, radius, currentYaw);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF8BEAF0).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  void _drawSphericalGrid(
    Canvas canvas,
    Offset center,
    double radius,
    double currentYaw,
  ) {
    final gridPaints = List<Paint>.generate(
      10,
      (index) => Paint()
        ..color = const Color(
          0xFF9FEAF0,
        ).withValues(alpha: 0.08 + index * 0.022)
        ..strokeWidth = index > 6 ? 1.05 : 0.75,
    );

    Offset project(_SpherePoint point) =>
        Offset(center.dx + point.x * radius, center.dy - point.y * radius);

    void drawCurve(Iterable<_SpherePoint> points) {
      _SpherePoint? previous;
      for (final point in points) {
        final last = previous;
        if (last != null && point.z > 0.015 && last.z > 0.015) {
          final depth = ((point.z + last.z) * 0.5 * 9).round().clamp(0, 9);
          canvas.drawLine(project(last), project(point), gridPaints[depth]);
        }
        previous = point;
      }
    }

    for (var meridian = -5; meridian <= 5; meridian++) {
      final longitude = meridian * math.pi / 10;
      drawCurve(
        List.generate(49, (index) {
          final latitude = -math.pi / 2 + math.pi * index / 48;
          return _rotatePoint(latitude, longitude, currentYaw, pitch);
        }),
      );
    }

    for (var parallel = -3; parallel <= 3; parallel++) {
      final latitude = parallel * math.pi / 8;
      drawCurve(
        List.generate(73, (index) {
          final longitude = -math.pi + 2 * math.pi * index / 72;
          return _rotatePoint(latitude, longitude, currentYaw, pitch);
        }),
      );
    }
  }

  void _drawSurfaceLabels(
    Canvas canvas,
    Offset center,
    double radius,
    double currentYaw,
  ) {
    const positions = [
      (0.67, 0.0),
      (0.24, -0.86),
      (0.0, 0.05),
      (-0.24, 0.9),
      (-0.61, -0.63),
      (-0.61, 0.72),
    ];
    final surfaceLabels = <_SurfaceLabel>[];
    for (
      var index = 0;
      index < math.min(labels.length, positions.length);
      index++
    ) {
      final (latitude, longitude) = positions[index];
      final point = _rotatePoint(latitude, longitude, currentYaw, pitch);
      if (point.z > 0.08) {
        surfaceLabels.add(_SurfaceLabel(labels[index], point));
      }
    }
    surfaceLabels.sort((a, b) => a.point.z.compareTo(b.point.z));

    for (final label in surfaceLabels) {
      final depth = label.point.z.clamp(0.0, 1.0);
      final opacity = 0.56 + depth * 0.42;
      final textPainter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: opacity),
            fontSize: 9.5 + depth * 1.1,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: 0.25,
          ),
        ),
        textDirection: textDirection,
        textAlign: TextAlign.center,
        maxLines: 2,
      )..layout(maxWidth: radius * 0.82);

      final position = Offset(
        center.dx + label.point.x * radius,
        center.dy - label.point.y * radius,
      );
      final cardRect = Rect.fromCenter(
        center: position,
        width: textPainter.width + 16,
        height: textPainter.height + 9,
      );
      final card = RRect.fromRectAndRadius(cardRect, const Radius.circular(9));
      canvas.drawRRect(
        card,
        Paint()
          ..color = const Color(
            0xFF031522,
          ).withValues(alpha: (0.5 + depth * 0.18) * opacity),
      );
      canvas.drawRRect(
        card,
        Paint()
          ..color = const Color(0xFFB3F3F3).withValues(alpha: 0.15 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      textPainter.paint(
        canvas,
        Offset(
          position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2,
        ),
      );
    }
  }

  _SpherePoint _rotatePoint(
    double latitude,
    double longitude,
    double currentYaw,
    double currentPitch,
  ) {
    final cosLatitude = math.cos(latitude);
    final x = cosLatitude * math.sin(longitude);
    final y = math.sin(latitude);
    final z = cosLatitude * math.cos(longitude);

    final cosYaw = math.cos(currentYaw);
    final sinYaw = math.sin(currentYaw);
    final yawX = x * cosYaw + z * sinYaw;
    final yawZ = -x * sinYaw + z * cosYaw;

    final cosPitch = math.cos(currentPitch);
    final sinPitch = math.sin(currentPitch);
    return _SpherePoint(
      x: yawX,
      y: y * cosPitch - yawZ * sinPitch,
      z: y * sinPitch + yawZ * cosPitch,
    );
  }

  @override
  bool shouldRepaint(_AboutSpherePainter oldDelegate) =>
      oldDelegate.labels != labels ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.textDirection != textDirection;
}

class _SpherePoint {
  const _SpherePoint({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;
}

class _SurfaceLabel {
  const _SurfaceLabel(this.text, this.point);

  final String text;
  final _SpherePoint point;
}
