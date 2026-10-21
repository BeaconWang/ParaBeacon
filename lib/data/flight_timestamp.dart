/// Converts a flight timestamp to Unix epoch seconds (UTC).
///
/// Flight-log JSON uses integer seconds, matching the `time(NULL)` convention.
int flightTimestampSeconds(DateTime time) =>
    time.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

/// Parses a Unix epoch-seconds value or a legacy ISO-8601 timestamp.
///
/// Zone-less legacy strings were written as local wall time, so Dart interprets
/// them in the current local zone before this function normalizes the instant to
/// UTC. New numeric values are unambiguous across timezone changes.
DateTime? parseFlightTimestamp(Object? value) {
  if (value is num) {
    if (!value.isFinite) return null;
    final milliseconds = value * Duration.millisecondsPerSecond;
    if (!milliseconds.isFinite || milliseconds.abs() > 8640000000000000) {
      return null;
    }
    try {
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds.round(),
        isUtc: true,
      );
    } on RangeError {
      return null;
    }
  }
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  return null;
}
