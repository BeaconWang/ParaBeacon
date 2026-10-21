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

/// Detects a new altitude record: fires as soon as the altitude exceeds the
/// highest altitude seen so far, but only after it has dropped at least
/// [rearmDrop] meters below that peak since the last record (or since the
/// start). This keeps a continuous climb from announcing every meter and
/// sensor noise from producing false records.
class AltitudeRecordTrigger {
  AltitudeRecordTrigger({this.rearmDrop = defaultRearmDrop});

  /// Default drop (m) below the record required before the next one.
  static const defaultRearmDrop = 20.0;

  final double rearmDrop;

  double _peak = double.negativeInfinity;
  bool _armed = false;

  /// Highest altitude known (baseline included), or -infinity.
  double get peak => _peak;
  bool get armed => _armed;

  /// Starts over with [baseline] (e.g. the highest altitude of all logged
  /// flights) as the record to beat.
  void reset({double baseline = double.negativeInfinity}) {
    _peak = baseline.isFinite ? baseline : double.negativeInfinity;
    _armed = false;
  }

  /// Feeds an altitude (m); returns true when it sets a new record.
  bool update(double altitude) {
    if (!altitude.isFinite) return false;
    if (altitude > _peak) {
      final record = _armed;
      _peak = altitude;
      _armed = false;
      return record;
    }
    if (!_armed && altitude <= _peak - rearmDrop) _armed = true;
    return false;
  }
}
