/// Pure, clock-driven trigger state machines used by the announcement bridge.
/// They hold no timers so they can be unit-tested with synthetic times.
library;

/// Fires once after a condition has held continuously for a dwell time, then
/// stays quiet until a rearm condition has held continuously for
/// [rearmDelay].
class DwellTrigger {
  DwellTrigger({this.rearmDelay = const Duration(seconds: 3)});

  final Duration rearmDelay;

  bool _armed = true;
  DateTime? _insideSince;
  DateTime? _rearmSince;

  bool get armed => _armed;

  /// Feeds one observation. [inside] is the firing condition, [rearming] the
  /// condition that (when sustained) allows the next announcement. Returns
  /// true when the announcement is due now.
  bool update(
    DateTime now, {
    required bool inside,
    required bool rearming,
    required Duration dwell,
  }) {
    if (rearming) {
      _rearmSince ??= now;
      if (now.difference(_rearmSince!) >= rearmDelay) _armed = true;
    } else {
      _rearmSince = null;
    }
    if (!inside) {
      _insideSince = null;
      return false;
    }
    _insideSince ??= now;
    if (!_armed || now.difference(_insideSince!) < dwell) return false;
    _armed = false;
    return true;
  }

  /// Time left until a continuous stay inside would fire, or null when no
  /// announcement is pending.
  Duration? pendingFor(DateTime now, Duration dwell) {
    final since = _insideSince;
    if (!_armed || since == null) return null;
    final left = dwell - now.difference(since);
    return left.isNegative ? Duration.zero : left;
  }

  /// Allows the next announcement right away (e.g. after a failed attempt).
  void rearm() => _armed = true;

  void reset() {
    _armed = true;
    _insideSince = null;
    _rearmSince = null;
  }
}

/// Detects new altitude records.
///
/// A record is the altitude exceeding the highest altitude seen so far (the
/// baseline included). It is announced immediately, except that while
/// records keep being broken (e.g. during a climb) announcements are at
/// least `minInterval` apart; a record broken during that pause is
/// announced as soon as the pause is over, with the highest value reached.
///
/// A record must exceed the last announced one by at least [minimumGain]
/// meters, so sensor noise around the peak never repeats the same number.
class AltitudeRecordTrigger {
  AltitudeRecordTrigger({this.minimumGain = 1.0});

  final double minimumGain;

  double _peak = double.negativeInfinity;
  double _announced = double.negativeInfinity;
  DateTime? _lastAnnouncedAt;
  double _previousAnnounced = double.negativeInfinity;
  DateTime? _previousAnnouncedAt;

  /// Highest altitude known (baseline included), or -infinity.
  double get peak => _peak;

  /// Whether a record is waiting for the end of the minimum interval.
  bool get hasPendingRecord =>
      _announced.isFinite && _peak >= _announced + minimumGain;

  /// Starts over with [baseline] (e.g. the highest altitude of all logged
  /// flights) as the record to beat. Without a baseline the first altitude
  /// fed becomes the reference.
  void reset({double baseline = double.negativeInfinity}) {
    _peak = baseline.isFinite ? baseline : double.negativeInfinity;
    _announced = _peak;
    _lastAnnouncedAt = null;
    _previousAnnounced = _announced;
    _previousAnnouncedAt = null;
  }

  /// Feeds an altitude (m) observed at [now]. Returns true when a record is
  /// due to be announced now; [peak] is then the record to announce. With
  /// [announce] false the peak is still tracked but nothing becomes due.
  bool update(
    double altitude,
    DateTime now, {
    required Duration minInterval,
    bool announce = true,
  }) {
    if (!altitude.isFinite) return false;
    if (!_peak.isFinite) {
      _peak = altitude;
      _announced = altitude;
      return false;
    }
    if (altitude > _peak) _peak = altitude;
    if (!announce || !hasPendingRecord) return false;
    final last = _lastAnnouncedAt;
    if (last != null && now.difference(last) < minInterval) return false;
    _previousAnnounced = _announced;
    _previousAnnouncedAt = last;
    _announced = _peak;
    _lastAnnouncedAt = now;
    return true;
  }

  /// Time left until a pending record may be announced, or null when no
  /// record is pending.
  Duration? pendingFor(DateTime now, Duration minInterval) {
    if (!hasPendingRecord) return null;
    final last = _lastAnnouncedAt;
    if (last == null) return Duration.zero;
    final left = minInterval - now.difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  /// Reverts the last announcement (it could not be spoken) so the record
  /// is announced again on the next update.
  void undoLastAnnouncement() {
    _announced = _previousAnnounced;
    _lastAnnouncedAt = _previousAnnouncedAt;
  }
}
