import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/vario_config.dart';
import 'package:parabeacon/audio/vario_sound_curve.dart';

void main() {
  group('XCTrack custom sound curve', () {
    test('default anchors map the documented waveform boundary', () {
      final curve = VarioSoundCurve.defaultCurve;

      expect(curve.sampleAt(-10).freqHz, 200);
      expect(curve.sampleAt(-0.5).isContinuous, isTrue);
      expect(curve.sampleAt(0).freqHz, 493);
      expect(curve.sampleAt(0).duty, 0.5);
      expect(curve.sampleAt(10).freqHz, 1108);
      expect(curve.sampleAt(10).isContinuous, isFalse);
    });

    test('interpolates frequency, cycle and duty', () {
      final point = VarioSoundCurve.defaultCurve.sampleAt(0.25);

      expect(point.freqHz, closeTo(521.5, 0.0001));
      expect(point.cycleSeconds, closeTo(0.575, 0.0001));
      expect(point.duty, 0.5);
      expect(
        point.toneSeconds + point.gapSeconds,
        closeTo(point.cycleSeconds, 0.0001),
      );
    });

    test('uses edge segments for linear extrapolation', () {
      final below = VarioSoundCurve.defaultCurve.sampleAt(-11);
      final above = VarioSoundCurve.defaultCurve.sampleAt(11);

      expect(below.freqHz, closeTo(186.7142857, 0.0001));
      expect(above.freqHz, closeTo(1153.6, 0.0001));
    });

    test('rejects unsafe anchors', () {
      expect(
        () => VarioSoundCurve([
          const VarioSoundAnchor(lift: 0, freqHz: 0, cycleMs: 100, dutyPct: 50),
        ]),
        throwsArgumentError,
      );
    });
  });

  test('custom profile is opt-in and preserves 22050 Hz defaults', () {
    const config = VarioAudioConfig.xcTrack;

    expect(config.profileMode, VarioProfileMode.classic);
    expect(config.sampleRate, 22050);
    expect(config.channels, 1);
    expect(config.sinkWaveform, VarioWaveform.square);
    expect(config.customCurve, VarioSoundCurve.defaultCurve);
  });
}
