/// Converts a flight timestamp to integer Unix epoch milliseconds (UTC).
int flightTimestampMilliseconds(DateTime time) =>
    time.toUtc().millisecondsSinceEpoch;

/// Parses a Unix epoch-seconds/milliseconds value or a legacy ISO-8601 timestamp.
///
/// Numeric values below 100 billion are treated as legacy seconds; larger values
/// are epoch milliseconds. This keeps existing second-based records readable
/// while preserving millisecond timestamps for current records. Zone-less
/// legacy strings are interpreted in the local zone before conversion to UTC.
DateTime? parseFlightTimestamp(Object? value) {
  if (value is num) {
    if (!value.isFinite) return null;
    final isMilliseconds = value.abs() >= 100000000000;
    final milliseconds = isMilliseconds
        ? value
        : value * Duration.millisecondsPerSecond;
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
