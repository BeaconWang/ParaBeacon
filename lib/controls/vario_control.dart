import 'package:flutter/material.dart';

import '../data/flight_data_provider.dart';

/// A vertical Vario column gauge, inspired by XCTrack's `WVarioColumn`.
///
/// The column represents vertical speed (climb/sink) in m/s on a symmetric
/// scale (default +/-[maxScale] m/s). The bar fills from the center baseline:
/// climb fills upward, sink fills downward. Colors follow XCTrack's mapping:
/// strong climb is red, moderate climb orange, gentle climb green, and sink
/// is blue.
///
/// Reads from the unified [FlightDataProvider]. An optional [verticalSpeed]
/// override can be supplied (e.g. for tests/previews).
class VarioControl extends StatelessWidget {
  /// Optional override for the vertical speed in m/s. When null the value is
  /// read from the shared flight-data source.
  final double? verticalSpeed;

  /// Absolute scale limit in m/s for the column extent.
  final double maxScale;

  const VarioControl({
    super.key,
    this.verticalSpeed,
    this.maxScale = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final value =
        verticalSpeed ?? FlightDataProvider.of(context).verticalSpeed;
    return CustomPaint(
      painter: _VarioPainter(
        value: value,
        maxScale: maxScale,
        theme: Theme.of(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Maps a vertical speed (m/s) to a fill color, following XCTrack's scheme.
Color varioColorFor(double v) {
  if (v >= 3.0) {
    return const Color(0xFFFFA0A0); // strong climb - red
  } else if (v >= 2.0) {
    return const Color(0xFFFFD0A0); // moderate climb - orange
  } else if (v >= 0.0) {
    return const Color(0xFFA0FFA0); // gentle climb - green
  } else {
    return const Color(0xFFA0B0FF); // sink - blue
  }
}

class _VarioPainter extends CustomPainter {
  final double value;
  final double maxScale;
  final ThemeData theme;

  _VarioPainter({
    required this.value,
    required this.maxScale,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = theme.colorScheme.surfaceContainerHighest;
    canvas.drawRect(Offset.zero & size, bg);

    final centerY = size.height / 2;
    final clamped = value.clamp(-maxScale, maxScale);
    final fillHeight = (clamped.abs() / maxScale) * (size.height / 2);

    // Fill bar from center.
    final fillPaint = Paint()..color = varioColorFor(value);
    final Rect fillRect;
    if (clamped >= 0) {
      // Climb: fill upward from center.
      fillRect = Rect.fromLTRB(0, centerY - fillHeight, size.width, centerY);
    } else {
      // Sink: fill downward from center.
      fillRect = Rect.fromLTRB(0, centerY, size.width, centerY + fillHeight);
    }
    canvas.drawRect(fillRect, fillPaint);

    // Scale ticks every 1 m/s.
    final tickPaint = Paint()
      ..color = theme.colorScheme.onSurfaceVariant.withAlpha(90)
      ..strokeWidth = 1;
    for (int i = -maxScale.toInt(); i <= maxScale.toInt(); i++) {
      final y = centerY - (i / maxScale) * (size.height / 2);
      final tickLen = (i % 5 == 0) ? size.width * 0.35 : size.width * 0.18;
      canvas.drawLine(Offset(0, y), Offset(tickLen, y), tickPaint);
      canvas.drawLine(Offset(size.width - tickLen, y), Offset(size.width, y),
          tickPaint);
    }

    // Center baseline.
    final baseline = Paint()
      ..color = theme.colorScheme.onSurface.withAlpha(160)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), baseline);

    // Numeric readout.
    final tp = TextPainter(
      text: TextSpan(
        text: '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width);
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, size.height - tp.height - 4),
    );

    // Unit label.
    final unit = TextPainter(
      text: TextSpan(
        text: 'm/s',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    unit.paint(canvas, Offset((size.width - unit.width) / 2, 2));
  }

  @override
  bool shouldRepaint(_VarioPainter oldDelegate) {
    return value != oldDelegate.value ||
        maxScale != oldDelegate.maxScale ||
        theme != oldDelegate.theme;
  }
}
