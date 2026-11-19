import 'package:flutter/material.dart';

import '../data/pilot_course.dart';

class PilotDirectionArrow extends StatelessWidget {
  const PilotDirectionArrow({
    required this.headingDegrees,
    required this.mapRotationDegrees,
    required this.color,
    super.key,
  });

  final double headingDegrees;
  final double mapRotationDegrees;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: PilotCourse.screenRadians(
      courseDegrees: headingDegrees,
      mapRotationDegrees: mapRotationDegrees,
    ),
    child: CustomPaint(
      size: const Size(14, 11),
      painter: _PilotDirectionArrowPainter(color: color),
    ),
  );
}

class _PilotDirectionArrowPainter extends CustomPainter {
  const _PilotDirectionArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arrow = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width / 2, 1)
      ..moveTo(2, size.height / 2)
      ..lineTo(size.width / 2, 1)
      ..lineTo(size.width - 2, size.height / 2);
    canvas.drawPath(path, outline);
    canvas.drawPath(path, arrow);
  }

  @override
  bool shouldRepaint(_PilotDirectionArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
