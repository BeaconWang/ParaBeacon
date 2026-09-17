import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/flight_data.dart';
import '../data/flight_data_provider.dart';
import '../data/flight_recorder.dart';

/// A live altitude and vertical-acceleration history graph inspired by
/// XCTrack's Vertical graph widget.
///
/// It shows the most recent [intervalSeconds] of recorded altitude samples and
/// overlays vertical acceleration derived from the change in vertical speed.
/// While a flight is active it follows the current track and appends the latest
/// live data snapshot, so the right edge updates even between recorder samples.
/// After landing it keeps showing the last completed track until another flight
/// starts.
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
        // Depend on the transformer as well as the recorder. The recorder is
        // deliberately throttled, while the transformed data stream updates on
        // every sensor tick; using both keeps the graph genuinely live without
        // changing recording/storage cadence.
        final liveData = FlightDataProvider.of(context);
        final recorder = FlightRecorder.instance;
        final currentTrack = recorder.currentTrack;
        final track = currentTrack ?? recorder.lastCompletedTrack;
        final samples = _samplesWithLiveData(
          track,
          currentTrack == null ? null : liveData,
        );
        return CustomPaint(
          painter: _VerticalGraphPainter(
            samples: _recentSamples(samples, intervalSeconds),
            intervalSeconds: intervalSeconds,
            verticalStep: verticalStep,
            dotSize: dotSize,
            theme: Theme.of(context),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  static List<FlightSample> _samplesWithLiveData(
    FlightTrack? track,
    FlightData? liveData,
  ) {
    final samples = List<FlightSample>.of(
      track?.samples ?? const <FlightSample>[],
    );
    if (liveData == null) return samples;

    final liveSample = FlightSample(
      time: liveData.timestamp ?? DateTime.now(),
      data: liveData,
    );
    if (samples.isEmpty || liveSample.time.isAfter(samples.last.time)) {
      samples.add(liveSample);
    }
    return samples;
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
  final double intervalSeconds;
  final double verticalStep;
  final double dotSize;
  final ThemeData theme;

  _VerticalGraphPainter({
    required this.samples,
    required this.intervalSeconds,
    required this.verticalStep,
    required this.dotSize,
    required this.theme,
  });

  double _verticalAccelerationFor(
    FlightSample current,
    FlightSample previous,
    FlightSample beforePrevious,
  ) {
    final currentDt = current.time.difference(previous.time).inMilliseconds /
        1000.0;
    final previousDt =
        previous.time.difference(beforePrevious.time).inMilliseconds / 1000.0;
    if (currentDt <= 0 || previousDt <= 0) return 0.0;

    final currentVerticalSpeed =
        (current.data.verticalSpeed + previous.data.verticalSpeed) / 2.0;
    final previousVerticalSpeed =
        (previous.data.verticalSpeed + beforePrevious.data.verticalSpeed) / 2.0;
    return (currentVerticalSpeed - previousVerticalSpeed) /
        ((currentDt + previousDt) / 2.0);
  }

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

    final accelerationValues = <double>[0.0, 0.0];
    for (var i = 2; i < samples.length; i++) {
      accelerationValues.add(
        _verticalAccelerationFor(samples[i], samples[i - 1], samples[i - 2]),
      );
    }
    final accelerationAbsMax = accelerationValues
        .map((value) => value.abs())
        .fold<double>(0.0, math.max);
    // Keep the acceleration trace readable even when the current flight is
    // smooth, while allowing stronger manoeuvres to expand the right axis.
    final accelerationScale = math.max(1.0, accelerationAbsMax * 1.15);

    final gridPaint = Paint()
      ..color = theme.colorScheme.onSurface.withAlpha(35)
      ..strokeWidth = 1;
    final labelStyle =
        theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
        ) ??
        TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10);
    final accelerationLabelStyle = labelStyle.copyWith(
      color: theme.colorScheme.tertiary,
    );
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

    final accelerationMaxLabel = TextPainter(
      text: TextSpan(
        text: '+${accelerationScale.toStringAsFixed(1)}',
        style: accelerationLabelStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final accelerationZeroLabel = TextPainter(
      text: TextSpan(text: '0', style: accelerationLabelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final accelerationMinLabel = TextPainter(
      text: TextSpan(
        text: '-${accelerationScale.toStringAsFixed(1)}',
        style: accelerationLabelStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    accelerationMaxLabel.paint(
      canvas,
      Offset(graph.right - accelerationMaxLabel.width, graph.top),
    );
    accelerationZeroLabel.paint(
      canvas,
      Offset(
        graph.right - accelerationZeroLabel.width,
        graph.center.dy - accelerationZeroLabel.height / 2,
      ),
    );
    accelerationMinLabel.paint(
      canvas,
      Offset(
        graph.right - accelerationMinLabel.width,
        graph.bottom - accelerationMinLabel.height,
      ),
    );

    final intervalLabel = TextPainter(
      text: TextSpan(text: '${intervalSeconds.round()}s', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final zeroLabel = TextPainter(
      text: TextSpan(text: '0s', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    intervalLabel.paint(canvas, Offset(graph.left, graph.bottom + 2));
    zeroLabel.paint(
      canvas,
      Offset(graph.right - zeroLabel.width, graph.bottom + 2),
    );

    // Keep the horizontal axis fixed: the right edge is always 0 seconds and
    // the left edge is always the configured interval (60s by default). Older
    // samples therefore occupy only the visible portion instead of stretching
    // to fill the graph.
    final windowMs = (intervalSeconds.clamp(1.0, 3600.0) * 1000.0)
        .round()
        .toDouble();
    final windowEnd = samples.last.time;
    Offset point(FlightSample sample) {
      final ageMs = windowEnd.difference(sample.time).inMilliseconds;
      final x =
          graph.left + (1.0 - (ageMs / windowMs).clamp(0.0, 1.0)) * graph.width;
      final y =
          graph.bottom -
          ((sample.data.altitude - graphMin) / altitudeSpan).clamp(0.0, 1.0) *
              graph.height;
      return Offset(x, y);
    }

    Offset accelerationPoint(int index) {
      final sample = samples[index];
      final ageMs = windowEnd.difference(sample.time).inMilliseconds;
      final x =
          graph.left + (1.0 - (ageMs / windowMs).clamp(0.0, 1.0)) * graph.width;
      final acceleration = accelerationValues[index];
      final y = graph.center.dy -
          (acceleration / accelerationScale).clamp(-1.0, 1.0) *
              graph.height / 2.0;
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

    final accelerationLine = Path();
    for (var i = 0; i < accelerationValues.length; i++) {
      final p = accelerationPoint(i);
      if (i == 0) {
        accelerationLine.moveTo(p.dx, p.dy);
      } else {
        accelerationLine.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      accelerationLine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..strokeJoin = StrokeJoin.round
        ..color = theme.colorScheme.tertiary,
    );

    final dotPaint = Paint()..color = theme.colorScheme.secondary;
    final radius = dotSize.clamp(1.0, 10.0).toDouble();
    for (final sample in samples) {
      canvas.drawCircle(point(sample), radius, dotPaint);
    }
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

  @override
  bool shouldRepaint(covariant _VerticalGraphPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.intervalSeconds != intervalSeconds ||
        oldDelegate.verticalStep != verticalStep ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.theme != theme;
  }
}
