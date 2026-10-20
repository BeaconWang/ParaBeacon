import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';
import 'package:parabeacon/audio/announcement_template.dart';

void main() {
  const values = AnnouncementValues(
    altitudeMeters: 1250.4,
    climbMetersPerSecond: 1.46,
    groundSpeedKmh: 32.2,
  );

  test('renders default English template with metric units', () {
    expect(
      AnnouncementTemplate.render(
        AnnouncementTemplate.defaultEnglish,
        AnnouncementLanguage.english,
        values,
      ),
      'Altitude 1250 meters',
    );
  });

  test('renders default Chinese template', () {
    expect(
      AnnouncementTemplate.render(
        AnnouncementTemplate.defaultChinese,
        AnnouncementLanguage.chinese,
        values,
      ),
      '当前高度，1250米',
    );
  });

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
