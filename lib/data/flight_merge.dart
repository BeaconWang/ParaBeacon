import 'package:flutter/foundation.dart';

import 'flight_recorder.dart';
import 'geo_math.dart';

/// Why a set of flights can't be merged.
enum FlightMergeIssueKind {
  /// Fewer than two flights were selected.
  tooFewFlights,

  /// A flight is still being recorded.
  recording,

  /// A flight is no longer in the flight log.
  notInLog,

  /// A flight has no per-sample GPS data (summary-only record).
  noSamples,

  /// A flight has samples but no valid GPS fix, so positions can't be
  /// compared.
  noFix,

  /// Two consecutive flights overlap in time.
  overlap,

  /// The time between a landing and the next takeoff is too long.
  gapTooLong,

  /// The landing point is too far from the next takeoff point.
  tooFar,

  /// Consecutive flights were flown with different wings.
  aircraftMismatch,

  /// Consecutive flights were flown by different pilots.
  pilotMismatch,
}

/// One failed merge condition. [track] is the flight concerned for
/// single-flight issues, or the earlier flight of a pair (with [next] being
/// the later one) for pair issues.
@immutable
class FlightMergeIssue {
  const FlightMergeIssue({
    required this.kind,
    this.track,
    this.next,
    this.duration,
    this.distanceM,
    this.previousValue,
    this.nextValue,
  });

  final FlightMergeIssueKind kind;
  final FlightTrack? track;
  final FlightTrack? next;

  /// Overlap / gap duration for [FlightMergeIssueKind.overlap] and
  /// [FlightMergeIssueKind.gapTooLong].
  final Duration? duration;

  /// Landing-to-takeoff distance for [FlightMergeIssueKind.tooFar].
  final double? distanceM;

  /// Conflicting values for the mismatch kinds (wing / pilot names).
  final String? previousValue;
  final String? nextValue;
}

/// The outcome of [FlightMergeValidator.check].
@immutable
class FlightMergeCheck {
  const FlightMergeCheck({required this.ordered, required this.issues});

  /// The candidate flights, oldest first.
  final List<FlightTrack> ordered;

  /// Every failed condition; empty when the merge is allowed.
  final List<FlightMergeIssue> issues;

  bool get canMerge => issues.isEmpty;
}

/// Conditions that must hold before flights can be merged into one record.
///
/// Flights are sorted by their first sample; every consecutive pair
/// (previous → next) must satisfy all pair rules. All failures are reported,
/// not just the first one, so the user sees every reason at once.
class FlightMergeValidator {
  FlightMergeValidator._();

  /// Longest allowed time from a landing (last sample) to the next takeoff
  /// (first sample).
  static const Duration maxGap = Duration(minutes: 30);

  /// Largest allowed distance between the last valid fix of a flight and the
  /// first valid fix of the next one.
  static const double maxDistanceM = 3000.0;

  /// Validates [tracks]. [recording] is the in-progress track (if any) and
  /// [isLogged] reports whether a track is still in the flight log.
  static FlightMergeCheck check(
    Iterable<FlightTrack> tracks, {
    FlightTrack? recording,
    bool Function(FlightTrack track)? isLogged,
  }) {
    final ordered = tracks.toSet().toList()
      ..sort((a, b) => a.firstRecordedTime.compareTo(b.firstRecordedTime));
    final issues = <FlightMergeIssue>[];

    if (ordered.length < 2) {
      issues.add(
        const FlightMergeIssue(kind: FlightMergeIssueKind.tooFewFlights),
      );
      return FlightMergeCheck(ordered: ordered, issues: issues);
    }

    // Single-flight rules. Pair rules need samples, so remember which
    // flights are usable for them.
    final usable = <FlightTrack>{};
    for (final track in ordered) {
      if (recording != null && identical(track, recording)) {
        issues.add(
          FlightMergeIssue(kind: FlightMergeIssueKind.recording, track: track),
        );
        continue;
      }
      if (isLogged != null && !isLogged(track)) {
        issues.add(
          FlightMergeIssue(kind: FlightMergeIssueKind.notInLog, track: track),
        );
        continue;
      }
      if (!track.hasSamples) {
        issues.add(
          FlightMergeIssue(kind: FlightMergeIssueKind.noSamples, track: track),
        );
        continue;
      }
      if (_firstFix(track) == null) {
        issues.add(
          FlightMergeIssue(kind: FlightMergeIssueKind.noFix, track: track),
        );
        continue;
      }
      usable.add(track);
    }

    for (var i = 1; i < ordered.length; i++) {
      final previous = ordered[i - 1];
      final next = ordered[i];
      if (!usable.contains(previous) || !usable.contains(next)) continue;

      final landing = previous.samples.last.time;
      final takeoff = next.samples.first.time;
      final gap = takeoff.difference(landing);
      if (gap.isNegative || gap == Duration.zero) {
        issues.add(
          FlightMergeIssue(
            kind: FlightMergeIssueKind.overlap,
            track: previous,
            next: next,
            duration: -gap,
          ),
        );
      } else if (gap > maxGap) {
        issues.add(
          FlightMergeIssue(
            kind: FlightMergeIssueKind.gapTooLong,
            track: previous,
            next: next,
            duration: gap,
          ),
        );
      }

      final landingFix = _lastFix(previous)!;
      final takeoffFix = _firstFix(next)!;
      final distance = GeoMath.distanceMeters(
        landingFix.data.latitude,
        landingFix.data.longitude,
        takeoffFix.data.latitude,
        takeoffFix.data.longitude,
      );
      if (distance > maxDistanceM) {
        issues.add(
          FlightMergeIssue(
            kind: FlightMergeIssueKind.tooFar,
            track: previous,
            next: next,
            distanceM: distance,
          ),
        );
      }

      final previousWing = aircraftLabel(previous);
      final nextWing = aircraftLabel(next);
      if (previousWing != null &&
          nextWing != null &&
          _normalize(previousWing) != _normalize(nextWing)) {
        issues.add(
          FlightMergeIssue(
            kind: FlightMergeIssueKind.aircraftMismatch,
            track: previous,
            next: next,
            previousValue: previousWing,
            nextValue: nextWing,
          ),
        );
      }

      final previousPilot = _nonEmpty(previous.pilotName);
      final nextPilot = _nonEmpty(next.pilotName);
      if (previousPilot != null &&
          nextPilot != null &&
          _normalize(previousPilot) != _normalize(nextPilot)) {
        issues.add(
          FlightMergeIssue(
            kind: FlightMergeIssueKind.pilotMismatch,
            track: previous,
            next: next,
            previousValue: previousPilot,
            nextValue: nextPilot,
          ),
        );
      }
    }

    return FlightMergeCheck(ordered: ordered, issues: issues);
  }

  /// The wing used for [track], or null when none was recorded. The legacy
  /// glider name (set for live recordings and IGC imports) is preferred, then
  /// the aircraft snapshot.
  static String? aircraftLabel(FlightTrack track) {
    final glider = _nonEmpty(track.gliderName);
    if (glider != null) return glider;
    final model = _nonEmpty(
      [
        track.aircraftManufacturer?.trim() ?? '',
        track.aircraftModel?.trim() ?? '',
      ].where((part) => part.isNotEmpty).join(' '),
    );
    return model ?? _nonEmpty(track.aircraftName);
  }

  static FlightSample? _firstFix(FlightTrack track) {
    for (final sample in track.samples) {
      if (sample.data.hasFix) return sample;
    }
    return null;
  }

  static FlightSample? _lastFix(FlightTrack track) {
    for (var i = track.samples.length - 1; i >= 0; i--) {
      if (track.samples[i].data.hasFix) return track.samples[i];
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Result of [FlightRecorder.mergeTracks]: the validation outcome and, when
/// it passed, the new merged track that replaced the originals.
@immutable
class FlightMergeResult {
  const FlightMergeResult({required this.check, this.merged});

  final FlightMergeCheck check;
  final FlightTrack? merged;

  bool get succeeded => merged != null;
}
