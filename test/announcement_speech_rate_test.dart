import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/altitude_announcement_speaker.dart';

void main() {
  test('speech speed maps to flutter_tts rate scale', () {
    // 0.5 is the normal speed on both Android and iOS.
    expect(AltitudeAnnouncementSpeaker.platformRateFor(1.0), 0.5);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(0.5), 0.25);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(2.0), 1.0);
    // Out-of-range and invalid values are clamped / reset.
    expect(AltitudeAnnouncementSpeaker.platformRateFor(10), 1.0);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(0), 0.25);
    expect(AltitudeAnnouncementSpeaker.platformRateFor(double.nan), 0.5);
  });
}
