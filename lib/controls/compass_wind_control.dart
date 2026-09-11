import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/flight_data_provider.dart';

/// A round compass rose that shows the current heading together with the wind
/// direction, inspired by XCTrack's "Compass and wind" widget.
///
/// The rose is drawn heading-up: the aircraft/travel direction always points
/// to the top of the tile and the cardinal ring rotates underneath it so the
/// pilot reads their heading against the fixed top marker. A wind arrow points
/// in the direction the wind is blowing *towards* (opposite of the
/// meteorological "from" convention stored in [FlightData.windDirection]) and
/// is labelled with the wind speed.
///
/// Reads heading, wind direction and wind speed from the shared
/// [FlightDataProvider]. Optional overrides are accepted for tests/previews.
class CompassWindControl extends StatelessWidget {
  final double? heading;
  final double? windDirection;
  final double? windSpeed;
  final bool? hasFix;

  const CompassWindControl({
    super.key,
    this.heading,
    this.windDirection,
    this.windSpeed,
    this.hasFix,
  });

  @override
  Widget build(BuildContext context) {
    final data = FlightDataProvider.of(context);
    final hdg = heading ?? data.heading;
    final windDir = windDirection ?? data.windDirection;
    final windKph = windSpeed ?? data.windSpeed;
    final fix = hasFix ?? data.hasFix;

    return CustomPaint(
      painter: _CompassWindPainter(
        heading: hdg,
        windFromDeg: windDir,
        windSpeedKph: windKph,
        hasFix: fix,
        theme: Theme.of(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CompassWindPainter extends CustomPainter {
  final double heading;
  final double windFromDeg;
  final double windSpeedKph;
  final bool hasFix;
  final ThemeData theme;

  _CompassWindPainter({
    required this.heading,
    required this.windFromDeg,
    required this.windSpeedKph,
    required this.hasFix,
    required this.theme,
  });

  static double _deg2rad(double d) => d * (math.pi / 180.0);

  @override
  void paint(Canvas canvas, Size size) {
    final cs = theme.colorScheme;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    if (radius <= 0) return;

    // Outer dial background.
    final dialPaint = Paint()..color = cs.surfaceContainerHighest;
    canvas.drawCircle(center, radius, dialPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = cs.outlineVariant.withAlpha(160);
    canvas.drawCircle(center, radius, ringPaint);

    // Heading-up: the ring rotates by -heading so North sits at (top - heading)
    // and the top of the tile represents the current travel direction.
    final rotation = _deg2rad(-heading);

    // Cardinal + tick marks around the ring.
    final tickPaint = Paint()
      ..color = cs.onSurfaceVariant.withAlpha(120)
      ..strokeWidth = 1;
    for (int deg = 0; deg < 360; deg += 15) {
      final major = deg % 90 == 0;
      final a = rotation + _deg2rad(deg.toDouble()) - math.pi / 2;
      final outer = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      final innerLen = major ? radius * 0.16 : radius * 0.08;
      final inner = Offset(
        center.dx + (radius - innerLen) * math.cos(a),
        center.dy + (radius - innerLen) * math.sin(a),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Cardinal labels (N/E/S/W). North is tinted so it stands out.
    const labels = ['N', 'E', 'S', 'W'];
    final labelR = radius * 0.72;
    for (int i = 0; i < 4; i++) {
      final deg = i * 90.0;
      final a = rotation + _deg2rad(deg) - math.pi / 2;
      final pos = Offset(
        center.dx + labelR * math.cos(a),
        center.dy + labelR * math.sin(a),
      );
      final color = i == 0 ? const Color(0xFFFF6B6B) : cs.onSurface;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: color,
            fontSize: (radius * 0.24).clamp(9.0, 28.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Fixed top marker: the travel direction pointer (a small triangle at the
    // top edge pointing inward).
    final markerPaint = Paint()..color = cs.primary;
    final topY = center.dy - radius;
    final marker = Path()
      ..moveTo(center.dx, topY + radius * 0.16)
      ..lineTo(center.dx - radius * 0.09, topY)
      ..lineTo(center.dx + radius * 0.09, topY)
      ..close();
    canvas.drawPath(marker, markerPaint);

    // Wind arrow: points in the direction the wind blows *towards*. Wind
    // direction is stored as the bearing the wind comes *from*, so the blow-to
    // bearing is windFrom + 180. Rotate into the heading-up frame as well.
    final blowToDeg = windFromDeg + 180.0;
    final windAngle = rotation + _deg2rad(blowToDeg) - math.pi / 2;
    final windLen = radius * 0.6;
    final tip = Offset(
      center.dx + windLen * math.cos(windAngle),
      center.dy + windLen * math.sin(windAngle),
    );
    final tail = Offset(
      center.dx - windLen * 0.5 * math.cos(windAngle),
      center.dy - windLen * 0.5 * math.sin(windAngle),
    );

    if (windSpeedKph > 0.1) {
      final windPaint = Paint()
        ..color = const Color(0xFF4C9AFF)
        ..strokeWidth = (radius * 0.06).clamp(2.0, 6.0)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, tip, windPaint);

      // Arrowhead.
      final headLen = radius * 0.16;
      final left = windAngle + math.pi - 0.5;
      final right = windAngle + math.pi + 0.5;
      final headFill = Paint()..color = windPaint.color;
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + headLen * math.cos(left),
            tip.dy + headLen * math.sin(left))
        ..lineTo(tip.dx + headLen * math.cos(right),
            tip.dy + headLen * math.sin(right))
        ..close();
      canvas.drawPath(head, headFill);
    }

    // Center hub.
    canvas.drawCircle(center, (radius * 0.06).clamp(2.0, 6.0),
        Paint()..color = cs.onSurface.withAlpha(200));

    // Center readout: heading in degrees + wind speed.
    final headingText = hasFix
        ? '${heading.round().toString().padLeft(3, '0')}°'
        : '---°';
    final tpHeading = TextPainter(
      text: TextSpan(
        text: headingText,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: (radius * 0.26).clamp(10.0, 30.0),
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpHeading.paint(
      canvas,
      Offset(center.dx - tpHeading.width / 2,
          center.dy + radius * 0.30 - tpHeading.height / 2),
    );

    final windText = '${windSpeedKph.toStringAsFixed(0)} km/h';
    final tpWind = TextPainter(
      text: TextSpan(
        text: windText,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: (radius * 0.16).clamp(8.0, 20.0),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpWind.paint(
      canvas,
      Offset(center.dx - tpWind.width / 2,
          center.dy + radius * 0.52 - tpWind.height / 2),
    );
  }

  @override
  bool shouldRepaint(_CompassWindPainter old) {
    return heading != old.heading ||
        windFromDeg != old.windFromDeg ||
        windSpeedKph != old.windSpeedKph ||
        hasFix != old.hasFix ||
        theme != old.theme;
  }
}
