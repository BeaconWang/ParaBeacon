import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/thermal_gain_widget.dart';

void main() {
  group('ThermalGainTracker', () {
    test('starts at climb threshold and stores gain on exit', () {
      final tracker = ThermalGainTracker();
      addTearDown(tracker.dispose);

      tracker.addSample(altitudeM: 1200, climbRateMps: 0.49);
      expect(tracker.isActive, isFalse);
      expect(tracker.lastGainM, isNull);

      tracker.addSample(altitudeM: 1210, climbRateMps: 0.5);
      expect(tracker.isActive, isTrue);
      expect(tracker.entryAltitudeM, 1210);
      expect(tracker.currentGainM, 0);

      tracker.addSample(altitudeM: 1560, climbRateMps: 0.3);
      expect(tracker.isActive, isTrue);
      expect(tracker.currentGainM, 350);

      tracker.addSample(altitudeM: 1558, climbRateMps: 0.1);
      expect(tracker.isActive, isFalse);
      expect(tracker.entryAltitudeM, isNull);
      expect(tracker.currentGainM, isNull);
      expect(tracker.lastGainM, 348);
    });

    test('external thermal state overrides climb-rate thresholds', () {
      final tracker = ThermalGainTracker();
      addTearDown(tracker.dispose);

      tracker.addSample(
        altitudeM: 800,
        climbRateMps: -0.4,
        isThermalling: true,
      );
      expect(tracker.isActive, isTrue);

      tracker.addSample(altitudeM: 920, climbRateMps: 0.0, isThermalling: true);
      expect(tracker.currentGainM, 120);

      tracker.addSample(
        altitudeM: 919,
        climbRateMps: 1.2,
        isThermalling: false,
      );
      expect(tracker.isActive, isFalse);
      expect(tracker.lastGainM, 119);
    });

    test('ignores non-finite samples and reset clears prior gain', () {
      final tracker = ThermalGainTracker();
      addTearDown(tracker.dispose);

      tracker.addSample(altitudeM: 1000, climbRateMps: 0.8);
      tracker.addSample(altitudeM: double.nan, climbRateMps: 0.8);
      expect(tracker.currentGainM, 0);

      tracker.addSample(altitudeM: 1040, climbRateMps: 0.0);
      expect(tracker.lastGainM, 40);
      tracker.reset();
      expect(tracker.isActive, isFalse);
      expect(tracker.lastGainM, isNull);
    });
  });
}
