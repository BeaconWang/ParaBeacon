import 'flight_derived_stats.dart';
import 'flight_recorder.dart';

/// A single "record" (best / extreme) value tied to the flight that set it.
///
/// Carries both the numeric [value] and the owning [track] so the UI can show
/// *which* flight achieved the record (e.g. "Longest flight — 2026-09-09").
class FlightRecordValue<T> {
  const FlightRecordValue(this.value, this.track);

  final T value;
  final FlightTrack track;
}

/// A labelled bucket used by the distribution breakdowns (per aircraft, per
/// takeoff site, per year, …). Carries the aggregate airtime so the UI can
/// show flights *and* hours per bucket.
class FlightBucket {
  FlightBucket(this.label);

  String label;
  int count = 0;
  Duration duration = Duration.zero;
  double distanceM = 0;

  void add(FlightTrack track) {
    count++;
    duration += track.duration;
    distanceM += track.distanceM;
  }
}

/// Aggregate statistics over a collection of [FlightTrack]s.
///
/// Everything is computed in a single pass (plus one [FlightDerivedStats]
/// computation per track that still carries per-sample data). Tracks that were
/// restored summary-only still contribute their duration / distance / altitude
/// extremes; the sample-derived figures (XC distance, glide ratio, thermals,
/// FAI triangle) simply skip those flights.
///
/// Units follow the rest of the Flights UI: distances in meters (converted to
/// km for display), speeds in km/h, vertical rates in m/s.
class FlightStatistics {
  FlightStatistics._();

  // ── Totals ────────────────────────────────────────────────────────────────
  int flightCount = 0;

  /// Flights that still carry per-sample data (so sample-derived figures are
  /// meaningful). Summary-only flights are excluded from those aggregates.
  int flightsWithSamples = 0;

  Duration totalDuration = Duration.zero;
  double totalTrackDistanceM = 0;
  double totalStraightDistanceM = 0;
  double totalAltitudeGainedM = 0;
  double totalAltitudeLostM = 0;
  Duration totalAirtimeMoving = Duration.zero;
  int totalThermals = 0;
  int totalSamples = 0;

  DateTime? firstFlight;
  DateTime? lastFlight;

  /// Number of distinct calendar days with at least one flight.
  int activeDays = 0;

  // ── Records (best / extreme values) ─────────────────────────────────────
  FlightRecordValue<Duration>? longestDuration;
  FlightRecordValue<double>? longestTrackDistanceM;
  FlightRecordValue<double>? longestStraightDistanceM;
  FlightRecordValue<double>? highestAltitudeM;
  FlightRecordValue<double>? lowestAltitudeM;
  FlightRecordValue<double>? maxClimbMs;
  FlightRecordValue<double>? maxSinkMs;
  FlightRecordValue<double>? maxSpeedKph;
  FlightRecordValue<double>? bestGlideRatio;
  FlightRecordValue<double>? bestFaiTriangleM;
  FlightRecordValue<double>? maxDistanceFromStartM;

  // ── Averages (per flight) ────────────────────────────────────────────────
  Duration get avgDuration =>
      flightCount == 0 ? Duration.zero : totalDuration ~/ flightCount;
  double get avgTrackDistanceM =>
      flightCount == 0 ? 0 : totalTrackDistanceM / flightCount;
  double get avgStraightDistanceM =>
      flightCount == 0 ? 0 : totalStraightDistanceM / flightCount;

  double _maxAltSum = 0;
  double get avgMaxAltitudeM => flightCount == 0 ? 0 : _maxAltSum / flightCount;

  double _speedSum = 0;
  int _speedCount = 0;
  double get avgSpeedKph => _speedCount == 0 ? 0 : _speedSum / _speedCount;

  double _glideSum = 0;
  int _glideCount = 0;
  double get avgGlideRatio => _glideCount == 0 ? 0 : _glideSum / _glideCount;

  /// Average number of flights per active day.
  double get flightsPerActiveDay =>
      activeDays == 0 ? 0 : flightCount / activeDays;

  // ── Distributions ────────────────────────────────────────────────────────
  /// Flights grouped by calendar year, ascending by year.
  final Map<int, FlightBucket> _byYear = {};

  /// Flights grouped by month-of-year (1..12) across all years — reveals the
  /// soaring season.
  final Map<int, FlightBucket> _byMonth = {};

  final Map<String, FlightBucket> _byAircraft = {};
  final Map<String, FlightBucket> _byTakeoffSite = {};

  List<FlightBucket> get byYear {
    final list = _byYear.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [for (final e in list) e.value];
  }

  /// All twelve months in calendar order (Jan..Dec); empty months included so
  /// the chart shows the full year. [monthLabels] has length 12 (Jan..Dec).
  List<FlightBucket> monthsLabeled(List<String> monthLabels) {
    return [
      for (var m = 1; m <= 12; m++)
        (_byMonth[m] ?? FlightBucket(''))..label = monthLabels[m - 1],
    ];
  }

  List<FlightBucket> get byAircraft => _sortedBuckets(_byAircraft);
  List<FlightBucket> get byTakeoffSite => _sortedBuckets(_byTakeoffSite);

  static List<FlightBucket> _sortedBuckets(Map<String, FlightBucket> m) {
    final list = m.values.toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return b.duration.compareTo(a.duration);
      });
    return list;
  }

  bool get isEmpty => flightCount == 0;

  /// Computes aggregate statistics over [tracks].
  ///
  /// [unknownAircraftLabel] is used to bucket flights with no recorded
  /// glider / aircraft name; [monthLabels] (length 12, Jan..Dec) label the
  /// month distribution.
  factory FlightStatistics.compute(Iterable<FlightTrack> tracks) {
    final stats = FlightStatistics._();
    final days = <String>{};

    for (final track in tracks) {
      stats.flightCount++;
      stats.totalDuration += track.duration;
      stats.totalTrackDistanceM += track.distanceM;
      stats.totalSamples += track.pointCount;
      stats._maxAltSum += track.maxAltitude;

      // First / last flight bounds.
      final start = track.startTime;
      if (stats.firstFlight == null || start.isBefore(stats.firstFlight!)) {
        stats.firstFlight = start;
      }
      if (stats.lastFlight == null || start.isAfter(stats.lastFlight!)) {
        stats.lastFlight = start;
      }
      days.add('${start.year}-${start.month}-${start.day}');

      // Year / month distributions.
      (stats._byYear[start.year] ??= FlightBucket('${start.year}')).add(track);
      (stats._byMonth[start.month] ??= FlightBucket('${start.month}')).add(
        track,
      );

      // Aircraft / site distributions.
      final aircraft = _aircraftLabel(track);
      if (aircraft != null) {
        (stats._byAircraft[aircraft] ??= FlightBucket(aircraft)).add(track);
      }
      final site = track.takeoffSite?.trim();
      if (site != null && site.isNotEmpty) {
        (stats._byTakeoffSite[site] ??= FlightBucket(site)).add(track);
      }

      // Summary-level records (available even for summary-only tracks).
      stats.longestDuration = _max(
        stats.longestDuration,
        track.duration,
        track,
        (d) => d.inMilliseconds.toDouble(),
      );
      stats.longestTrackDistanceM = _maxNum(
        stats.longestTrackDistanceM,
        track.distanceM,
        track,
      );
      stats.highestAltitudeM = _maxNum(
        stats.highestAltitudeM,
        track.maxAltitude,
        track,
      );
      stats.lowestAltitudeM = _minNum(
        stats.lowestAltitudeM,
        track.minAltitude,
        track,
      );
      stats.maxClimbMs = _maxNum(stats.maxClimbMs, track.maxClimb, track);
      // maxSink is stored negative; the strongest sink is the most negative.
      stats.maxSinkMs = _minNum(stats.maxSinkMs, track.maxSink, track);

      // Sample-derived figures (skip summary-only tracks).
      if (track.hasSamples) {
        stats.flightsWithSamples++;
        final d = FlightDerivedStats.compute(track);
        stats.totalStraightDistanceM += d.straightDistanceM;
        stats.totalAltitudeGainedM += d.altitudeGainedM;
        stats.totalAltitudeLostM += d.altitudeLostM;
        stats.totalAirtimeMoving += d.movingTime;
        stats.totalThermals += d.thermalCount;

        if (d.avgGroundSpeedKph > 0) {
          stats._speedSum += d.avgGroundSpeedKph;
          stats._speedCount++;
        }
        if (d.avgGlideRatio > 0) {
          stats._glideSum += d.avgGlideRatio;
          stats._glideCount++;
        }

        stats.longestStraightDistanceM = _maxNum(
          stats.longestStraightDistanceM,
          d.straightDistanceM,
          track,
        );
        stats.maxDistanceFromStartM = _maxNum(
          stats.maxDistanceFromStartM,
          d.maxDistanceFromStartM,
          track,
        );
        stats.maxSpeedKph = _maxNum(stats.maxSpeedKph, d.maxSpeedKph, track);
        if (d.avgGlideRatio > 0) {
          stats.bestGlideRatio = _maxNum(
            stats.bestGlideRatio,
            d.avgGlideRatio,
            track,
          );
        }
        if (d.faiTriangleM > 0) {
          stats.bestFaiTriangleM = _maxNum(
            stats.bestFaiTriangleM,
            d.faiTriangleM,
            track,
          );
        }
      }
    }

    stats.activeDays = days.length;
    return stats;
  }

  /// Glider / aircraft label used to bucket a flight, or null when unknown.
  static String? _aircraftLabel(FlightTrack track) {
    final glider = track.gliderName?.trim();
    if (glider != null && glider.isNotEmpty) return glider;
    final parts = [
      track.aircraftManufacturer?.trim(),
      track.aircraftModel?.trim(),
    ].where((e) => e != null && e.isNotEmpty).cast<String>();
    if (parts.isNotEmpty) return parts.join(' ');
    final name = track.aircraftName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  /// Keeps the larger of the current record and a candidate numeric value.
  static FlightRecordValue<double>? _maxNum(
    FlightRecordValue<double>? current,
    double value,
    FlightTrack track,
  ) {
    if (current == null || value > current.value) {
      return FlightRecordValue<double>(value, track);
    }
    return current;
  }

  /// Keeps the smaller (most negative / lowest) of the current record and a
  /// candidate numeric value.
  static FlightRecordValue<double>? _minNum(
    FlightRecordValue<double>? current,
    double value,
    FlightTrack track,
  ) {
    if (current == null || value < current.value) {
      return FlightRecordValue<double>(value, track);
    }
    return current;
  }

  /// Keeps the record whose [rank] of [value] is largest.
  static FlightRecordValue<T>? _max<T>(
    FlightRecordValue<T>? current,
    T value,
    FlightTrack track,
    double Function(T) rank,
  ) {
    if (current == null || rank(value) > rank(current.value)) {
      return FlightRecordValue<T>(value, track);
    }
    return current;
  }
}
