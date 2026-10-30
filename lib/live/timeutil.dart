/// util/UTCTimeAdapter - GregorianCalendar <-> JSON string.
library;

DateTime utc(DateTime dt) {
  final u = dt.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

/// util/UTCTimeAdapter - `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` in GMT
/// (util/UTCTimeAdapter.smali:231-260).
String utcToJson(DateTime dt) {
  final u = utc(dt);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
      'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}'
      '.${u.millisecond.toString().padLeft(3, '0')}Z';
}

DateTime utcFromJson(String s) => DateTime.parse(s).toUtc();

int epochSeconds(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;

DateTime fromEpochSeconds(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
