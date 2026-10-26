import 'dart:math' as math;

import '../data/unit_settings.dart';
import 'altitude_announcement_speaker.dart';

/// Flight situations that can trigger a voice announcement. Each one has its
/// own (customizable) announcement text.
enum AnnouncementEvent {
  /// A new flight started.
  takeoff,

  /// Automatic detection resumed the previous flight record (quick relaunch).
  continueFlight,

  /// The flight ended.
  landing,

  /// Vertical speed stayed in the silent glide dead zone.
  glide,

  /// The altitude exceeded the highest altitude recorded so far.
  altitudeRecord;

  /// Takeoff / landing events are preceded by a notification ding.
  bool get isFlightTransition =>
      this == takeoff || this == continueFlight || this == landing;
}

/// Values that can be inserted into a voice announcement template.
///
/// Every optional value defaults to "unknown" (NaN / null), which is spoken
/// as such rather than as a misleading zero.
class AnnouncementValues {
  const AnnouncementValues({
    required this.altitudeMeters,
    required this.climbMetersPerSecond,
    required this.groundSpeedKmh,
    this.heightAboveGroundMeters = double.nan,
    this.heightAboveTakeoffMeters = double.nan,
    this.maxAltitudeMeters = double.nan,
    this.distanceMeters = double.nan,
    this.windSpeedKmh = double.nan,
    this.flightDuration,
    this.clockTime,
  });

  /// Representative values used for the preview and the test announcement.
  static final sample = AnnouncementValues(
    altitudeMeters: 1250,
    climbMetersPerSecond: 1.5,
    groundSpeedKmh: 32,
    heightAboveGroundMeters: 830,
    heightAboveTakeoffMeters: 420,
    maxAltitudeMeters: 1310,
    distanceMeters: 12400,
    windSpeedKmh: 12,
    flightDuration: const Duration(hours: 1, minutes: 5),
    clockTime: DateTime(2026, 1, 1, 14, 30),
  );

  /// Sample values that match the situation of [event], so the preview reads
  /// like the real announcement (e.g. a small sink rate in the dead zone).
  static AnnouncementValues sampleFor(AnnouncementEvent event) =>
      switch (event) {
        AnnouncementEvent.takeoff => sample.copyWith(
          altitudeMeters: 830,
          climbMetersPerSecond: 0.3,
          heightAboveGroundMeters: 5,
          heightAboveTakeoffMeters: 0,
          maxAltitudeMeters: 830,
          distanceMeters: 0,
          flightDuration: Duration.zero,
        ),
        AnnouncementEvent.landing => sample.copyWith(
          altitudeMeters: 420,
          climbMetersPerSecond: 0,
          groundSpeedKmh: 0,
          heightAboveGroundMeters: 0,
          heightAboveTakeoffMeters: -410,
        ),
        AnnouncementEvent.glide => sample.copyWith(climbMetersPerSecond: -0.1),
        AnnouncementEvent.altitudeRecord => sample.copyWith(
          altitudeMeters: 1310,
          climbMetersPerSecond: 1.2,
        ),
        AnnouncementEvent.continueFlight => sample,
      };

  final double altitudeMeters;
  final double climbMetersPerSecond;
  final double groundSpeedKmh;

  /// Height above the terrain below (AGL).
  final double heightAboveGroundMeters;

  /// Height relative to the takeoff altitude of the current flight.
  final double heightAboveTakeoffMeters;

  /// Highest altitude of the current flight.
  final double maxAltitudeMeters;

  /// Distance flown in the current flight.
  final double distanceMeters;

  final double windSpeedKmh;

  /// Duration of the current flight, or null when unknown.
  final Duration? flightDuration;

  /// Local clock time of the announcement, or null when unknown.
  final DateTime? clockTime;

  AnnouncementValues copyWith({
    double? altitudeMeters,
    double? climbMetersPerSecond,
    double? groundSpeedKmh,
    double? heightAboveGroundMeters,
    double? heightAboveTakeoffMeters,
    double? maxAltitudeMeters,
    double? distanceMeters,
    double? windSpeedKmh,
    Duration? flightDuration,
    DateTime? clockTime,
  }) {
    return AnnouncementValues(
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      climbMetersPerSecond: climbMetersPerSecond ?? this.climbMetersPerSecond,
      groundSpeedKmh: groundSpeedKmh ?? this.groundSpeedKmh,
      heightAboveGroundMeters:
          heightAboveGroundMeters ?? this.heightAboveGroundMeters,
      heightAboveTakeoffMeters:
          heightAboveTakeoffMeters ?? this.heightAboveTakeoffMeters,
      maxAltitudeMeters: maxAltitudeMeters ?? this.maxAltitudeMeters,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      windSpeedKmh: windSpeedKmh ?? this.windSpeedKmh,
      flightDuration: flightDuration ?? this.flightDuration,
      clockTime: clockTime ?? this.clockTime,
    );
  }
}

/// A placeholder that can be used in a template, e.g. `{altitude}`.
enum AnnouncementPlaceholder {
  altitude('altitude'),
  altitudeUnit('altitudeUnit'),
  climb('climb'),
  climbUnit('climbUnit'),
  groundSpeed('groundSpeed'),
  speedUnit('speedUnit'),
  heightAboveGround('agl'),
  heightAboveTakeoff('takeoffHeight'),
  maxAltitude('maxAltitude'),
  glideRatio('glideRatio'),
  windSpeed('windSpeed'),
  flightTime('flightTime'),
  distance('distance'),
  distanceUnit('distanceUnit'),
  time('time');

  const AnnouncementPlaceholder(this.key);

  final String key;

  String get token => '{$key}';
}

/// Renders user-customizable voice announcement templates.
///
/// Templates are plain text with `{placeholder}` tokens (see
/// [AnnouncementPlaceholder]). Unknown tokens are left as-is so typos are
/// audible/visible rather than silently dropped. Units are rendered as spoken
/// words in the announcement language and follow the app's unit settings.
class AnnouncementTemplate {
  AnnouncementTemplate._();

  static const maxLength = 200;

  static final _tokenPattern = RegExp(r'\{(\w+)\}');
  static final _cjkPattern = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');

  /// Built-in announcement text for [event] in [language].
  static String defaultFor(
    AnnouncementLanguage language,
    AnnouncementEvent event,
  ) {
    final zh = language == AnnouncementLanguage.chinese;
    return switch (event) {
      AnnouncementEvent.takeoff => zh ? '起飞' : 'Takeoff',
      AnnouncementEvent.continueFlight => zh ? '继续飞行' : 'Continue flight',
      AnnouncementEvent.landing => zh ? '降落' : 'Landing',
      AnnouncementEvent.glide =>
        zh
            ? '高度：{altitude}，速度：{groundSpeed}'
            : 'Altitude: {altitude}, Speed: {groundSpeed}',
      AnnouncementEvent.altitudeRecord =>
        zh ? '刷新高度：{maxAltitude}' : 'Refresh altitude: {maxAltitude}',
    };
  }

  /// Normalizes user input; returns `null` for a blank template (use default).
  static String? sanitize(String? template) {
    if (template == null) return null;
    final singleLine = template
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ')
        .trim();
    if (singleLine.isEmpty) return null;
    return singleLine.length > maxLength
        ? singleLine.substring(0, maxLength)
        : singleLine;
  }

  /// Language implied by the template text: Chinese characters select a
  /// Chinese voice, otherwise [fallback] is kept.
  static AnnouncementLanguage languageOf(
    String template,
    AnnouncementLanguage fallback,
  ) {
    if (_cjkPattern.hasMatch(template)) return AnnouncementLanguage.chinese;
    final withoutTokens = template.replaceAll(_tokenPattern, '');
    if (RegExp(r'[A-Za-z]').hasMatch(withoutTokens)) {
      return AnnouncementLanguage.english;
    }
    return fallback;
  }

  static String render(
    String template,
    AnnouncementLanguage language,
    AnnouncementValues values,
  ) {
    final units = UnitSettings.instance;
    final altitudeUnit = units.defaultUnit(UnitDimension.altitude);
    final climbUnit = units.defaultUnit(UnitDimension.verticalSpeed);
    final speedUnit = units.defaultUnit(UnitDimension.speed);
    final distanceUnit = units.defaultUnit(UnitDimension.distance);
    final zh = language == AnnouncementLanguage.chinese;
    final unknown = zh ? '未知' : 'unknown';

    // Spell the sign out as a word. TTS engines often drop a leading ASCII
    // hyphen-minus, which made negative values (e.g. height below takeoff) be
    // voiced as if they were positive.
    String spokenSign(String text) {
      if (!text.startsWith('-')) return text;
      final magnitude = text.substring(1);
      return zh ? '负$magnitude' : 'minus $magnitude';
    }

    String number(double value, {int decimals = 0}) {
      if (!value.isFinite) return unknown;
      if (decimals == 0) return spokenSign(value.round().toString());
      final text = value.toStringAsFixed(decimals);
      return spokenSign(text == '-0.0' ? '0.0' : text);
    }

    String altitudeValue(double meters) => number(
      UnitValues.convert(meters, UnitDimension.altitude, altitudeUnit),
    );

    String speedValue(double kmh) =>
        number(UnitValues.convert(kmh, UnitDimension.speed, speedUnit));

    final distance = _distance(values.distanceMeters, distanceUnit, zh);

    final replacements = <String, String>{
      AnnouncementPlaceholder.altitude.key: altitudeValue(
        values.altitudeMeters,
      ),
      AnnouncementPlaceholder.altitudeUnit.key: _altitudeWord(altitudeUnit, zh),
      AnnouncementPlaceholder.climb.key: number(
        UnitValues.convert(
          values.climbMetersPerSecond,
          UnitDimension.verticalSpeed,
          climbUnit,
        ),
        decimals: climbUnit == 'fpm' ? 0 : 1,
      ),
      AnnouncementPlaceholder.climbUnit.key: _climbWord(climbUnit, zh),
      AnnouncementPlaceholder.groundSpeed.key: speedValue(
        values.groundSpeedKmh,
      ),
      AnnouncementPlaceholder.speedUnit.key: _speedWord(speedUnit, zh),
      AnnouncementPlaceholder.heightAboveGround.key: altitudeValue(
        values.heightAboveGroundMeters,
      ),
      AnnouncementPlaceholder.heightAboveTakeoff.key: altitudeValue(
        values.heightAboveTakeoffMeters,
      ),
      AnnouncementPlaceholder.maxAltitude.key: altitudeValue(
        values.maxAltitudeMeters,
      ),
      AnnouncementPlaceholder.glideRatio.key: _glideRatio(
        values.groundSpeedKmh,
        values.climbMetersPerSecond,
        unknown,
      ),
      AnnouncementPlaceholder.windSpeed.key: speedValue(values.windSpeedKmh),
      AnnouncementPlaceholder.flightTime.key: _duration(
        values.flightDuration,
        zh,
        unknown,
      ),
      AnnouncementPlaceholder.distance.key: distance?.$1 ?? unknown,
      AnnouncementPlaceholder.distanceUnit.key:
          distance?.$2 ??
          _distanceWord(distanceUnit == 'auto' ? 'km' : distanceUnit, zh),
      AnnouncementPlaceholder.time.key: _clock(values.clockTime, zh, unknown),
    };

    return template.replaceAllMapped(
      _tokenPattern,
      (match) => replacements[match.group(1)] ?? match.group(0)!,
    );
  }

  /// Ground distance per height lost; unknown while (almost) not sinking.
  static String _glideRatio(
    double groundSpeedKmh,
    double climb,
    String unknown,
  ) {
    if (!groundSpeedKmh.isFinite || !climb.isFinite || climb > -0.05) {
      return unknown;
    }
    final ratio = math.min(99.0, (groundSpeedKmh / 3.6) / -climb);
    return ratio < 10 ? ratio.toStringAsFixed(1) : ratio.round().toString();
  }

  /// Spoken distance value and unit word; "auto" switches from meters to
  /// kilometers at 1 km like the dashboard does.
  static (String, String)? _distance(double meters, String unit, bool zh) {
    if (!meters.isFinite) return null;
    final effective = unit == 'auto' ? (meters < 1000 ? 'm' : 'km') : unit;
    final value = UnitValues.convert(meters, UnitDimension.distance, effective);
    final precise = (effective == 'km' || effective == 'mi') && value < 100;
    final text = precise ? value.toStringAsFixed(1) : value.round().toString();
    return (text, _distanceWord(effective, zh));
  }

  static String _duration(Duration? duration, bool zh, String unknown) {
    if (duration == null || duration.isNegative) return unknown;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    String en(int value, String word) => '$value $word${value == 1 ? '' : 's'}';
    if (hours > 0) {
      if (zh) return minutes == 0 ? '$hours小时' : '$hours小时$minutes分钟';
      return minutes == 0
          ? en(hours, 'hour')
          : '${en(hours, 'hour')} ${en(minutes, 'minute')}';
    }
    if (minutes > 0) return zh ? '$minutes分钟' : en(minutes, 'minute');
    return zh ? '$seconds秒' : en(seconds, 'second');
  }

  static String _clock(DateTime? time, bool zh, String unknown) {
    if (time == null) return unknown;
    final minutes = time.minute.toString().padLeft(2, '0');
    return zh ? '${time.hour}点$minutes分' : '${time.hour}:$minutes';
  }

  static String _altitudeWord(String unit, bool zh) =>
      unit == 'ft' ? (zh ? '英尺' : 'feet') : (zh ? '米' : 'meters');

  static String _climbWord(String unit, bool zh) => unit == 'fpm'
      ? (zh ? '英尺每分钟' : 'feet per minute')
      : (zh ? '米每秒' : 'meters per second');

  static String _speedWord(String unit, bool zh) => switch (unit) {
    'ms' => zh ? '米每秒' : 'meters per second',
    'mph' => zh ? '英里每小时' : 'miles per hour',
    'kn' => zh ? '节' : 'knots',
    _ => zh ? '公里每小时' : 'kilometers per hour',
  };

  static String _distanceWord(String unit, bool zh) => switch (unit) {
    'm' => zh ? '米' : 'meters',
    'ft' => zh ? '英尺' : 'feet',
    'mi' => zh ? '英里' : 'miles',
    _ => zh ? '公里' : 'kilometers',
  };
}
