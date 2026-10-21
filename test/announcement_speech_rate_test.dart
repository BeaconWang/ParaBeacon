import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';

void main() {
  test('speech speed maps linearly to the Android rate scale', () {
    // 0.5 is the normal speed; the plugin doubles it into a linear rate.
    expect(AltitudeAnnouncementSpeaker.platformRateFor(1.0), 0.5);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(0.5), 0.25);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(2.0), 1.0);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(4.0), 2.0);
    // Out-of-range and invalid values are clamped / reset.
    expect(AltitudeAnnouncementSpeaker.platformRateFor(10), 2.0);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(0), 0.25);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(double.nan), 0.5);
  });

  test('speech speed maps into the 0..1 Apple rate scale', () {
    double apple(double m) =>
        AltitudeAnnouncementSpeaker.platformRateFor(m, apple: true);
    expect(apple(0.5), 0.25);
    expect(apple(1.0), 0.5);
    expect(apple(2.5), closeTo(0.75, 1e-9));
    expect(apple(4.0), 1.0);
    expect(apple(10), 1.0);
  });

  test('user range is 0.5x to 4.0x', () {
    expect(AltitudeAnnouncementSpeaker.minRate, 0.5);
    expect(AltitudeAnnouncementSpeaker.maxRate, 4.0);
  });
}
