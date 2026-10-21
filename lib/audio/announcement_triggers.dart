/// Pure, clock-driven trigger state machines used by the announcement bridge.
/// They hold no timers so they can be unit-tested with synthetic times.
library;

/// Fires after a condition has held continuously for a dwell time and, when
/// a repeat interval is given, again every interval while the condition keeps
/// holding. After firing it stays quiet (apart from the repeats) until a
/// rearm condition has held continuously for [rearmDelay]; a brief excursion
/// therefore continues the repeat cadence instead of starting over.
class DwellTrigger {
  DwellTrigger({this.rearmDelay = const Duration(seconds: 3)});

  final Duration rearmDelay;

  bool _armed = true;
  DateTime? _insideSince;
  DateTime? _rearmSince;
  DateTime? _lastFiredAt;

  bool get armed => _armed;

  /// Feeds one observation. [inside] is the firing condition, [rearming] the
  /// condition that (when sustained) allows a fresh announcement. With
  /// [repeatEvery], announcements repeat at that interval (start to start)
  /// while [inside] holds. Returns true when an announcement is due now.
  bool update(
    DateTime now, {
    required bool inside,
    required bool rearming,
    required Duration dwell,
    Duration? repeatEvery,
  }) {
    if (rearming) {
      _rearmSince ??= now;
      if (now.difference(_rearmSince!) >= rearmDelay) {
        _armed = true;
        _lastFiredAt = null;
      }
    } else {
      _rearmSince = null;
    }
    if (!inside) {
      _insideSince = null;
      return false;
    }
    _insideSince ??= now;
    final left = _timeLeft(now, dwell, repeatEvery);
    if (left == null || left > Duration.zero) return false;
    _armed = false;
    _lastFiredAt = now;
    return true;
  }

  /// Time left until a continuous stay inside would fire, or null when no
  /// announcement is pending.
  Duration? pendingFor(DateTime now, Duration dwell, [Duration? repeatEvery]) {
    if (_insideSince == null) return null;
    return _timeLeft(now, dwell, repeatEvery);
  }

  Duration? _timeLeft(DateTime now, Duration dwell, Duration? repeatEvery) {
    final since = _insideSince;
    if (since == null) return null;
    var left = dwell - now.difference(since);
    if (!_armed) {
      final last = _lastFiredAt;
      if (repeatEvery == null || last == null) return null;
      final repeatLeft = repeatEvery - now.difference(last);
      if (repeatLeft > left) left = repeatLeft;
    }
    return left.isNegative ? Duration.zero : left;
  }

  /// Allows the next announcement right away (e.g. after a failed attempt).
  void rearm() => _armed = true;

  void reset() {
    _armed = true;
    _insideSince = null;
    _rearmSince = null;
    _lastFiredAt = null;
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
