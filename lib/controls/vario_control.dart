import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/flight_data_provider.dart';
import 'decimal_places.dart';

/// A vertical Vario column gauge, inspired by XCTrack's `WVarioColumn`.
///
/// The column represents vertical speed (climb/sink) in m/s on a symmetric
/// scale (default +/-[maxScale] m/s). The bar fills from the center baseline:
/// climb fills upward, sink fills downward. Fill colors are interpolated across
/// fixed vertical-speed stops from blue-black sink through gray to red-purple
/// climb.
///
/// Reads from the unified [FlightDataProvider]. An optional [verticalSpeed]
/// override can be supplied (e.g. for tests/previews).
class VarioControl extends StatelessWidget {
  /// Optional override for the vertical speed in m/s. When null the value is
  /// read from the shared flight-data source.
  final double? verticalSpeed;

  /// Absolute scale limit in m/s for the column extent.
  final double maxScale;

  /// Whether to render the gauge as a glass vessel with a liquid surface.
  final bool liquidGlass;

  const VarioControl({
    super.key,
    this.verticalSpeed,
    this.maxScale = 8.0,
    this.liquidGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = verticalSpeed ?? FlightDataProvider.of(context).verticalSpeed;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: liquidGlass ? const Duration(milliseconds: 480) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) => CustomPaint(
        painter: _VarioPainter(
          value: animatedValue,
          maxScale: maxScale,
          liquidGlass: liquidGlass,
          precision: DecimalPlacesScope.rangeOf(context, 'valueDecimals'),
          theme: Theme.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        ),
        child: child,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Fixed vertical-speed stops used to color the bar continuously.
const _varioColorStops = <(double, Color)>[
  (-10.0, Color(0xFF000B1E)), // blue-black
  (-7.0, Color(0xFF0D47A1)), // dark blue
  (-3.0, Color(0xFF00BCD4)), // cyan blue
  (0.0, Color(0xFF9E9E9E)), // gray
  (3.0, Color(0xFF4CAF50)), // green
  (7.0, Color(0xFFF44336)), // red
  (10.0, Color(0xFF4A0033)), // dark purplish red
];

/// Maps vertical speed (m/s) to a linearly interpolated fill color.
Color varioColorFor(double v) {
  if (v.isNaN) return _varioColorStops[3].$2;
  if (v <= _varioColorStops.first.$1) return _varioColorStops.first.$2;
  if (v >= _varioColorStops.last.$1) return _varioColorStops.last.$2;

  for (int i = 0; i < _varioColorStops.length - 1; i++) {
    final lower = _varioColorStops[i];
    final upper = _varioColorStops[i + 1];
    if (v == lower.$1) return lower.$2;
    if (v <= upper.$1) {
      final t = (v - lower.$1) / (upper.$1 - lower.$1);
      return Color.lerp(lower.$2, upper.$2, t)!;
    }
  }
  return _varioColorStops.last.$2;
}

LinearGradient _varioFillGradient(double maxScale) {
  final scale = maxScale > 0 && maxScale.isFinite ? maxScale : 1.0;
  final colors = <Color>[varioColorFor(scale)];
  final stops = <double>[0.0];

  for (final stop in _varioColorStops.reversed) {
    final speed = stop.$1;
    if (speed < scale && speed > -scale) {
      colors.add(stop.$2);
      stops.add((scale - speed) / (2 * scale));
    }
  }

  colors.add(varioColorFor(-scale));
  stops.add(1.0);
  return LinearGradient(
    colors: colors,
    stops: stops,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

double _markerY(double centerY, double value, double scale) =>
    centerY - (value / scale) * (centerY);

double _liquidSurfaceY(Size size, double x, double markerY, double fillHeight) {
  final amplitude = math
      .min(1.8, math.min(size.width * 0.035, fillHeight * 0.12))
      .toDouble();
  final phase = size.width == 0 ? 0.0 : (x / size.width) * 2 * math.pi;
  return markerY + amplitude * math.sin(phase);
}

Path _liquidSurfacePath(Size size, double markerY, double fillHeight) {
  final path = Path()..moveTo(0, _liquidSurfaceY(size, 0, markerY, fillHeight));
  for (var i = 1; i <= 24; i++) {
    final x = size.width * i / 24;
    path.lineTo(x, _liquidSurfaceY(size, x, markerY, fillHeight));
  }
  return path;
}

Path _liquidFillPath(
  Size size,
  double centerY,
  double value,
  double fillHeight,
  double markerY,
) {
  final path = Path();
  if (value >= 0) {
    path
      ..addPath(_liquidSurfacePath(size, markerY, fillHeight), Offset.zero)
      ..lineTo(size.width, centerY)
      ..lineTo(0, centerY)
      ..close();
  } else {
    path
      ..moveTo(0, centerY)
      ..lineTo(size.width, centerY);
    for (var i = 24; i >= 0; i--) {
      final x = size.width * i / 24;
      path.lineTo(x, _liquidSurfaceY(size, x, markerY, fillHeight));
    }
    path.close();
  }
  return path;
}

class _VarioPainter extends CustomPainter {
  final double value;
  final double maxScale;
  final bool liquidGlass;
  final DecimalPlaceRange? precision;
  final ThemeData theme;
  final TextScaler textScaler;

  _VarioPainter({
    required this.value,
    required this.maxScale,
    required this.liquidGlass,
    required this.precision,
    required this.theme,
    required this.textScaler,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = maxScale > 0 && maxScale.isFinite ? maxScale : 1.0;
    final centerY = size.height / 2;
    final clamped = value.clamp(-scale, scale);
    final fillHeight = (clamped.abs() / scale) * (size.height / 2);
    final vesselRect = Rect.fromLTRB(
      2,
      2,
      math.max(2, size.width - 2),
      math.max(2, size.height - 2),
    );
    final vessel = RRect.fromRectAndRadius(
      vesselRect,
      Radius.circular(math.min(size.width * 0.24, 18)),
    );

    if (liquidGlass) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = theme.colorScheme.surface.withAlpha(20),
      );
      canvas.drawRRect(
        vessel,
        Paint()
          ..color = Colors.black.withAlpha(24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawRRect(
        vessel,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.topRight,
            colors: [
              Color(0x66FFFFFF),
              Color(0x3383D8F4),
              Color(0x55FFFFFF),
              Color(0x2283D8F4),
              Color(0x66FFFFFF),
            ],
            stops: [0, 0.16, 0.48, 0.82, 1],
          ).createShader(vesselRect),
      );
      canvas.save();
      canvas.clipRRect(vessel);
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = theme.colorScheme.surfaceContainerHighest,
      );
    }

    // Fill bar from center with a gradient mapped to the full speed scale.
    final fillPaint = Paint()
      ..shader = _varioFillGradient(scale).createShader(Offset.zero & size);
    if (liquidGlass) {
      final markerY = _markerY(centerY, clamped, scale);
      final liquidPath = _liquidFillPath(
        size,
        centerY,
        clamped,
        fillHeight,
        markerY,
      );
      canvas.drawPath(liquidPath, fillPaint);
    } else {
      final fillRect = clamped >= 0
          ? Rect.fromLTRB(0, centerY - fillHeight, size.width, centerY)
          : Rect.fromLTRB(0, centerY, size.width, centerY + fillHeight);
      canvas.drawRect(fillRect, fillPaint);
    }

    // Scale ticks every 1 m/s.
    final tickPaint = Paint()
      ..color = theme.colorScheme.onSurfaceVariant.withAlpha(90)
      ..strokeWidth = 1;
    for (int i = -scale.toInt(); i <= scale.toInt(); i++) {
      final y = centerY - (i / scale) * (size.height / 2);
      final tickLen = (i % 5 == 0) ? size.width * 0.35 : size.width * 0.18;
      canvas.drawLine(Offset(0, y), Offset(tickLen, y), tickPaint);
      canvas.drawLine(
        Offset(size.width - tickLen, y),
        Offset(size.width, y),
        tickPaint,
      );
    }

    // Center baseline.
    final baseline = Paint()
      ..color = theme.colorScheme.onSurface.withAlpha(160)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), baseline);

    // Keep the current-speed marker straight even when the liquid edge ripples.
    final markerY = _markerY(centerY, clamped, scale);
    final markerOutline = Paint()
      ..color = Colors.black.withAlpha(210)
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(0, markerY),
      Offset(size.width, markerY),
      markerOutline,
    );
    final marker = Paint()
      ..color = Colors.white.withAlpha(240)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, markerY), Offset(size.width, markerY), marker);

    // Numeric readout.
    final tp = TextPainter(
      text: TextSpan(
        text:
            '${value >= 0 ? '+' : ''}${formatDecimalValue(value, autoDecimals: 1, range: precision)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: textScaler,
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
      textScaler: textScaler,
    )..layout(maxWidth: size.width);
    unit.paint(canvas, Offset((size.width - unit.width) / 2, 2));

    if (liquidGlass) {
      canvas.restore();
      canvas.save();
      canvas.clipRRect(vessel);
      final reflection = Paint()
        ..color = Colors.white.withAlpha(100)
        ..strokeWidth = math.max(1.0, size.width * 0.025).toDouble()
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.13, size.height * 0.08),
        Offset(size.width * 0.13, size.height * 0.92),
        reflection,
      );
      canvas.restore();
      canvas.drawRRect(
        vessel,
        Paint()
          ..color = Colors.white.withAlpha(190)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
  }

  @override
  bool shouldRepaint(_VarioPainter oldDelegate) {
    return value != oldDelegate.value ||
        maxScale != oldDelegate.maxScale ||
        liquidGlass != oldDelegate.liquidGlass ||
        precision?.min != oldDelegate.precision?.min ||
        precision?.max != oldDelegate.precision?.max ||
        theme != oldDelegate.theme ||
        textScaler != oldDelegate.textScaler;
  }
}
