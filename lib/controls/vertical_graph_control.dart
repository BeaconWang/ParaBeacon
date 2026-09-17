import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/flight_recorder.dart';

/// A live altitude history graph inspired by XCTrack's Vertical graph widget.
///
/// It shows the most recent [intervalSeconds] of recorded altitude samples.
/// While a flight is active it follows the current track; after landing it keeps
/// showing the last completed track until another flight starts.
class VerticalGraphControl extends StatelessWidget {
  final double intervalSeconds;
  final double verticalStep;
  final double dotSize;

  const VerticalGraphControl({
    super.key,
    this.intervalSeconds = 60.0,
    this.verticalStep = 50.0,
    this.dotSize = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FlightRecorder.instance,
      builder: (context, _) {
        final recorder = FlightRecorder.instance;
        final track = recorder.currentTrack ?? recorder.lastCompletedTrack;
        final samples = track?.samples ?? const <FlightSample>[];
        return CustomPaint(
          painter: _VerticalGraphPainter(
            samples: _recentSamples(samples, intervalSeconds),
            verticalStep: verticalStep,
            dotSize: dotSize,
            theme: Theme.of(context),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  static List<FlightSample> _recentSamples(
    List<FlightSample> samples,
    double intervalSeconds,
  ) {
    if (samples.length < 2) return List<FlightSample>.of(samples);
    final cutoff = samples.last.time.subtract(
      Duration(
        milliseconds: (intervalSeconds.clamp(1.0, 3600.0) * 1000).round(),
      ),
    );
    var first = 0;
    while (first < samples.length - 2 && samples[first].time.isBefore(cutoff)) {
      first++;
    }
    return samples.sublist(first);
  }
}

class _VerticalGraphPainter extends CustomPainter {
  final List<FlightSample> samples;
  final double verticalStep;
  final double dotSize;
  final ThemeData theme;

  _VerticalGraphPainter({
    required this.samples,
    required this.verticalStep,
    required this.dotSize,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = theme.colorScheme.surfaceContainerHighest;
    canvas.drawRect(Offset.zero & size, background);
    if (samples.length < 2 || size.width <= 0 || size.height <= 0) {
      _drawEmpty(canvas, size);
      return;
    }

    const left = 34.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 18.0;
    final graph = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );

    var minAltitude = samples.first.data.altitude;
    var maxAltitude = minAltitude;
    for (final sample in samples.skip(1)) {
      minAltitude = math.min(minAltitude, sample.data.altitude);
      maxAltitude = math.max(maxAltitude, sample.data.altitude);
    }

    final step = verticalStep.clamp(1.0, 5000.0).toDouble();
    final range = math.max(step, maxAltitude - minAltitude);
    final center = (minAltitude + maxAltitude) / 2.0;
    final graphMin = ((center - range / 2) / step).floor() * step;
    final graphMax = ((center + range / 2) / step).ceil() * step;
    final altitudeSpan = math.max(step, graphMax - graphMin);

    final gridPaint = Paint()
      ..color = theme.colorScheme.onSurface.withAlpha(35)
      ..strokeWidth = 1;
    final labelStyle =
        theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
        ) ??
        TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10);
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);

    for (
      var altitude = graphMin;
      altitude <= graphMax + step / 2;
      altitude += step
    ) {
      final y =
          graph.bottom - ((altitude - graphMin) / altitudeSpan) * graph.height;
      canvas.drawLine(Offset(graph.left, y), Offset(graph.right, y), gridPaint);
      labelPaint.text = TextSpan(
        text: altitude.round().toString(),
        style: labelStyle,
      );
      labelPaint.layout(maxWidth: left - 4);
      labelPaint.paint(
        canvas,
        Offset(left - labelPaint.width - 4, y - labelPaint.height / 2),
      );
    }

    final t0 = samples.first.time;
    final totalMs = math
        .max(1, samples.last.time.difference(t0).inMilliseconds)
        .toDouble();
    Offset point(FlightSample sample) {
      final x =
          graph.left +
          (sample.time.difference(t0).inMilliseconds / totalMs) * graph.width;
      final y =
          graph.bottom -
          ((sample.data.altitude - graphMin) / altitudeSpan).clamp(0.0, 1.0) *
              graph.height;
      return Offset(x, y);
    }

    final line = Path();
    for (var i = 0; i < samples.length; i++) {
      final p = point(samples[i]);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = theme.colorScheme.primary,
    );

    final dotPaint = Paint()..color = theme.colorScheme.secondary;
    final radius = dotSize.clamp(1.0, 10.0).toDouble();
    for (final sample in samples) {
      canvas.drawCircle(point(sample), radius, dotPaint);
    }

    final duration = samples.last.time.difference(samples.first.time);
    final footer = TextPainter(
      text: TextSpan(text: _formatDuration(duration), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    footer.paint(
      canvas,
      Offset(graph.right - footer.width, size.height - footer.height - 2),
    );
  }

  void _drawEmpty(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: 'Waiting for flight data',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );
  }

  static String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final minutes = seconds ~/ 60;
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  @override
  bool shouldRepaint(covariant _VerticalGraphPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.verticalStep != verticalStep ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.theme != theme;
  }
}
