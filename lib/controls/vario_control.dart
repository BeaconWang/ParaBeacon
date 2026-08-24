import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A vertical Vario column gauge, inspired by XCTrack's `WVarioColumn`.
///
/// The column represents vertical speed (climb/sink) in m/s on a symmetric
/// scale (default +/-[maxScale] m/s). The bar fills from the center baseline:
/// climb fills upward, sink fills downward. Colors follow XCTrack's mapping:
/// strong climb is red, moderate climb orange, gentle climb green, and sink
/// is blue.
///
/// If [verticalSpeed] is null the control animates a simulated value so it is
/// alive on the dashboard until a real sensor feed is wired in.
class VarioControl extends StatefulWidget {
  /// Vertical speed in m/s. When null, a simulated value is used.
  final double? verticalSpeed;

  /// Absolute scale limit in m/s for the column extent.
  final double maxScale;

  const VarioControl({
    super.key,
    this.verticalSpeed,
    this.maxScale = 8.0,
  });

  @override
  State<VarioControl> createState() => _VarioControlState();
}

class _VarioControlState extends State<VarioControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final math.Random _rand = math.Random();
  double _simValue = 0.0;
  double _simTarget = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
    if (widget.verticalSpeed == null) {
      _ticker.repeat();
    }
  }

  @override
  void didUpdateWidget(VarioControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final live = widget.verticalSpeed == null;
    if (live && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!live && _ticker.isAnimating) {
      _ticker.stop();
    }
  }

  void _onTick() {
    // Ease the simulated value toward a target, occasionally picking a new one.
    if (_rand.nextDouble() < 0.03) {
      _simTarget = (_rand.nextDouble() * 2 - 1) * widget.maxScale;
    }
    setState(() {
      _simValue += (_simTarget - _simValue) * 0.08;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _value => widget.verticalSpeed ?? _simValue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VarioPainter(
        value: _value,
        maxScale: widget.maxScale,
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
