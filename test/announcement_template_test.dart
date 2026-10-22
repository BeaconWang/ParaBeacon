import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/audio/announcement_template.dart';

void main() {
  const values = AnnouncementValues(
    altitudeMeters: 1250.4,
    climbMetersPerSecond: 1.46,
    groundSpeedKmh: 32.2,
  );

  test('renders all placeholders and keeps unknown tokens', () {
    expect(
      AnnouncementTemplate.render(
        '{altitude} {altitudeUnit}, climb {climb} {climbUnit}, '
        '{groundSpeed} {speedUnit} {unknown}',
        AnnouncementLanguage.english,
        values,
      ),
      '1250 meters, climb 1.5 meters per second, '
      '32 kilometers per hour {unknown}',
    );
  });

  test('missing values are spoken as unknown', () {
    const missing = AnnouncementValues(
      altitudeMeters: 900,
      climbMetersPerSecond: 0,
      groundSpeedKmh: double.nan,
    );
    expect(
      AnnouncementTemplate.render(
        '{groundSpeed}',
        AnnouncementLanguage.chinese,
        missing,
      ),
      '未知',
    );
  });

  test('language is detected from template text', () {
    expect(
      AnnouncementTemplate.languageOf(
        '高度{altitude}',
        AnnouncementLanguage.english,
      ),
      AnnouncementLanguage.chinese,
    );
    expect(
      AnnouncementTemplate.languageOf(
        'Height {altitude}',
        AnnouncementLanguage.chinese,
      ),
      AnnouncementLanguage.english,
    );
    expect(
      AnnouncementTemplate.languageOf(
        '{altitude} {altitudeUnit}',
        AnnouncementLanguage.chinese,
      ),
      AnnouncementLanguage.chinese,
    );
  });

  test('event defaults: takeoff, continue flight, landing, altitude', () {
    const zh = AnnouncementLanguage.chinese;
    const en = AnnouncementLanguage.english;
    expect(
      AnnouncementTemplate.defaultFor(zh, AnnouncementEvent.takeoff),
      '起飞',
    );
    expect(
      AnnouncementTemplate.defaultFor(zh, AnnouncementEvent.continueFlight),
      '继续飞行',
    );
    expect(
      AnnouncementTemplate.defaultFor(zh, AnnouncementEvent.landing),
      '降落',
    );
    expect(
      AnnouncementTemplate.defaultFor(en, AnnouncementEvent.continueFlight),
      'Continue flight',
    );
    expect(
      AnnouncementTemplate.render(
        AnnouncementTemplate.defaultFor(zh, AnnouncementEvent.glide),
        zh,
        values,
      ),
      '高度：1250，速度：32',
    );
    expect(
      AnnouncementTemplate.render(
        AnnouncementTemplate.defaultFor(en, AnnouncementEvent.glide),
        en,
        values,
      ),
      'Altitude: 1250, Speed: 32',
    );
    final record = values.copyWith(maxAltitudeMeters: 1310.4);
    expect(
      AnnouncementTemplate.render(
        AnnouncementTemplate.defaultFor(zh, AnnouncementEvent.altitudeRecord),
        zh,
        record,
      ),
      '刷新高度：1310',
    );
    expect(
      AnnouncementTemplate.render(
        AnnouncementTemplate.defaultFor(en, AnnouncementEvent.altitudeRecord),
        en,
        record,
      ),
      'Refresh altitude: 1310',
    );
  });

  test('renders the extended placeholders', () {
    final extended = AnnouncementValues(
      altitudeMeters: 1250,
      climbMetersPerSecond: -1.2,
      groundSpeedKmh: 36,
      heightAboveGroundMeters: 830.4,
      heightAboveTakeoffMeters: 420,
      maxAltitudeMeters: 1310,
      distanceMeters: 12400,
      windSpeedKmh: 12,
      flightDuration: const Duration(hours: 1, minutes: 5),
      clockTime: DateTime(2026, 1, 1, 14, 5),
    );
    expect(
      AnnouncementTemplate.render(
        '{agl} {takeoffHeight} {maxAltitude} {glideRatio} {windSpeed} '
        '{flightTime} {distance} {distanceUnit} {time}',
        AnnouncementLanguage.english,
        extended,
      ),
      '830 420 1310 8.3 12 1 hour 5 minutes 12.4 kilometers 14:05',
    );
    expect(
      AnnouncementTemplate.render(
        '{flightTime}，{distance}{distanceUnit}，{time}',
        AnnouncementLanguage.chinese,
        extended.copyWith(distanceMeters: 640),
      ),
      '1小时5分钟，640米，14点05分',
    );
  });

  test('glide ratio is unknown while not sinking', () {
    expect(
      AnnouncementTemplate.render(
        '{glideRatio}',
        AnnouncementLanguage.english,
        values,
      ),
      'unknown',
    );
  });

  test('sanitize trims, strips control chars, limits length', () {
    expect(AnnouncementTemplate.sanitize('   '), isNull);
    expect(AnnouncementTemplate.sanitize(null), isNull);
    expect(AnnouncementTemplate.sanitize(' a\nb '), 'a b');
    expect(
      AnnouncementTemplate.sanitize('x' * 500)!.length,
      AnnouncementTemplate.maxLength,
    );
  });
}
