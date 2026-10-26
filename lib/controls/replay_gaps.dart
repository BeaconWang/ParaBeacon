import 'package:flutter/material.dart';

import '../data/flight_recorder.dart';
import '../l10n/app_localizations.dart';

/// Color used for every missing-data indicator in the replays.
const Color replayGapColor = Color(0xFFFF9800);

/// A missing-data period mapped onto a replay's sample list and timeline.
@immutable
class ReplayGap {
  const ReplayGap({
    required this.gap,
    required this.afterIndex,
    required this.startMs,
    required this.endMs,
  });

  final FlightDataGap gap;

  /// Index of the first sample after the gap (the step `afterIndex - 1 →
  /// afterIndex` spans the gap).
  final int afterIndex;

  /// Gap bounds in track-relative milliseconds (0 == first sample).
  final double startMs;
  final double endMs;

  bool containsMs(double ms) => ms > startMs && ms < endMs;
}

/// Maps the [track]'s data gaps onto [samples]. Only gaps that fall between
/// two consecutive samples of [samples] are returned, oldest first.
List<ReplayGap> replayGapsFor(FlightTrack track, List<FlightSample> samples) {
  if (!track.hasDataGaps || samples.length < 2) return const [];
  final first = samples.first.time;
  final out = <ReplayGap>[];
  for (var i = 1; i < samples.length; i++) {
    final from = samples[i - 1].time;
    final to = samples[i].time;
    if (!track.crossesDataGap(from, to)) continue;
    for (final gap in track.dataGaps) {
      if (from.isAfter(gap.start) || to.isBefore(gap.end)) continue;
      out.add(
        ReplayGap(
          gap: gap,
          afterIndex: i,
          startMs: from.difference(first).inMilliseconds.toDouble(),
          endMs: to.difference(first).inMilliseconds.toDouble(),
        ),
      );
      break;
    }
  }
  return out;
}

/// The gap containing [cursorMs], if any.
ReplayGap? replayGapAt(List<ReplayGap> gaps, double cursorMs) {
  for (final gap in gaps) {
    if (gap.containsMs(cursorMs)) return gap;
  }
  return null;
}

/// While playing through a gap, the playback rate is raised so the gap
/// passes in about this long (it is still shown, just not in real time).
const double replayGapPlaybackMs = 2000.0;

/// Effective playback speed at [cursorMs]: [speed] outside gaps, fast enough
/// inside one to cross it in [replayGapPlaybackMs].
double replaySpeedAt(List<ReplayGap> gaps, double cursorMs, double speed) {
  final gap = replayGapAt(gaps, cursorMs);
  if (gap == null) return speed;
  final fast = (gap.endMs - gap.startMs) / replayGapPlaybackMs;
  return fast > speed ? fast : speed;
}

String formatGapDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

String formatGapClock(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// Slider track that paints missing-data periods over the normal track.
class ReplayGapSliderTrackShape extends RoundedRectSliderTrackShape {
  const ReplayGapSliderTrackShape({
    required this.gaps,
    required this.spanMs,
    this.color = replayGapColor,
  });

  final List<ReplayGap> gaps;
  final double spanMs;
  final Color color;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    if (gaps.isEmpty || spanMs <= 0) return;
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final paint = Paint()..color = color;
    final height = rect.height + additionalActiveTrackHeight + 2;
    for (final gap in gaps) {
      var left = rect.left + rect.width * (gap.startMs / spanMs);
      var right = rect.left + rect.width * (gap.endMs / spanMs);
      if (textDirection == TextDirection.rtl) {
        final mirroredLeft = rect.right - (right - rect.left);
        right = rect.right - (left - rect.left);
        left = mirroredLeft;
      }
      if (right - left < 3) {
        final mid = (left + right) / 2;
        left = mid - 1.5;
        right = mid + 1.5;
      }
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset((left + right) / 2, rect.center.dy),
            width: right - left,
            height: height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }
}

/// Wraps [slider] so its track shows the [gaps].
Widget replayGapSlider({
  required BuildContext context,
  required List<ReplayGap> gaps,
  required double spanMs,
  required Widget slider,
}) {
  if (gaps.isEmpty) return slider;
  return SliderTheme(
    data: SliderTheme.of(context).copyWith(
      trackShape: ReplayGapSliderTrackShape(gaps: gaps, spanMs: spanMs),
    ),
    child: slider,
  );
}

/// Paints translucent bands for [gaps] across a timeline drawn between
/// [left] and [right] (both in local coordinates).
void paintReplayGapBands(
  Canvas canvas, {
  required List<ReplayGap> gaps,
  required double spanMs,
  required double left,
  required double right,
  required double top,
  required double bottom,
}) {
  if (gaps.isEmpty || spanMs <= 0) return;
  final width = right - left;
  final fill = Paint()..color = replayGapColor.withAlpha(48);
  final edge = Paint()
    ..color = replayGapColor
    ..strokeWidth = 1;
  for (final gap in gaps) {
    final x0 = left + width * (gap.startMs / spanMs).clamp(0.0, 1.0);
    final x1 = left + width * (gap.endMs / spanMs).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTRB(x0, top, x1, bottom), fill);
    canvas.drawLine(Offset(x0, top), Offset(x0, bottom), edge);
    canvas.drawLine(Offset(x1, top), Offset(x1, bottom), edge);
  }
}

/// Banner shown while the replay cursor is inside a missing-data period.
class ReplayGapBanner extends StatelessWidget {
  const ReplayGapBanner({super.key, required this.gap});

  final ReplayGap gap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey<String>('replay-gap-banner'),
      color: replayGapColor.withAlpha(235),
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_off, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.replayDataGapBanner(
                  formatGapClock(gap.gap.start),
                  formatGapClock(gap.gap.end),
                  formatGapDuration(gap.gap.duration),
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small legend line under a replay that lists how many gaps there are.
class ReplayGapSummary extends StatelessWidget {
  const ReplayGapSummary({super.key, required this.gaps});

  final List<ReplayGap> gaps;

  @override
  Widget build(BuildContext context) {
    if (gaps.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    var total = Duration.zero;
    for (final gap in gaps) {
      total += gap.gap.duration;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 6,
            decoration: BoxDecoration(
              color: replayGapColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.replayDataGapSummary(gaps.length, formatGapDuration(total)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
