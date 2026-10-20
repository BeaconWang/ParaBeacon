import '../data/unit_settings.dart';
import 'altitude_announcement_speaker.dart';

/// Values that can be inserted into a voice announcement template.
class AnnouncementValues {
  const AnnouncementValues({
    required this.altitudeMeters,
    required this.climbMetersPerSecond,
    required this.groundSpeedKmh,
  });

  /// Representative values used for the preview and the test announcement.
  static const sample = AnnouncementValues(
    altitudeMeters: 1250,
    climbMetersPerSecond: 1.5,
    groundSpeedKmh: 32,
  );

  final double altitudeMeters;
  final double climbMetersPerSecond;
  final double groundSpeedKmh;
}

/// A placeholder that can be used in a template, e.g. `{altitude}`.
enum AnnouncementPlaceholder {
  altitude('altitude'),
  altitudeUnit('altitudeUnit'),
  climb('climb'),
  climbUnit('climbUnit'),
  groundSpeed('groundSpeed'),
  speedUnit('speedUnit');

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

  static const defaultChinese = '当前高度，{altitude}{altitudeUnit}';
  static const defaultEnglish = 'Altitude {altitude} {altitudeUnit}';

  static final _tokenPattern = RegExp(r'\{(\w+)\}');
  static final _cjkPattern = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');

  static String defaultFor(AnnouncementLanguage language) =>
      language == AnnouncementLanguage.chinese ? defaultChinese : defaultEnglish;

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
    final zh = language == AnnouncementLanguage.chinese;

    String number(double value, {int decimals = 0}) {
      if (!value.isFinite) return zh ? '未知' : 'unknown';
      if (decimals == 0) return value.round().toString();
      final text = value.toStringAsFixed(decimals);
      return text == '-0.0' ? '0.0' : text;
    }

    final replacements = <String, String>{
      AnnouncementPlaceholder.altitude.key: number(
        UnitValues.convert(
          values.altitudeMeters,
          UnitDimension.altitude,
          altitudeUnit,
        ),
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
      AnnouncementPlaceholder.groundSpeed.key: number(
        UnitValues.convert(
          values.groundSpeedKmh,
          UnitDimension.speed,
          speedUnit,
        ),
      ),
      AnnouncementPlaceholder.speedUnit.key: _speedWord(speedUnit, zh),
    };

    return template.replaceAllMapped(
      _tokenPattern,
      (match) => replacements[match.group(1)] ?? match.group(0)!,
    );
  }

  static String _altitudeWord(String unit, bool zh) => unit == 'ft'
      ? (zh ? '英尺' : 'feet')
      : (zh ? '米' : 'meters');

  static String _climbWord(String unit, bool zh) => unit == 'fpm'
      ? (zh ? '英尺每分钟' : 'feet per minute')
      : (zh ? '米每秒' : 'meters per second');

  static String _speedWord(String unit, bool zh) => switch (unit) {
    'ms' => zh ? '米每秒' : 'meters per second',
    'mph' => zh ? '英里每小时' : 'miles per hour',
    'kn' => zh ? '节' : 'knots',
    _ => zh ? '公里每小时' : 'kilometers per hour',
  };
}
