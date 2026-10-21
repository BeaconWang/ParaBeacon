import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/announcement_triggers.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
  const dwell = Duration(milliseconds: 500);

  group('DwellTrigger (glide dead zone)', () {
    bool feed(DwellTrigger trigger, int ms, bool inside) =>
        trigger.update(at(ms), inside: inside, rearming: !inside, dwell: dwell);

    test('fires once after staying inside for the dwell time', () {
      final trigger = DwellTrigger();
      expect(feed(trigger, 0, true), isFalse);
      expect(
        trigger.pendingFor(at(200), dwell),
        const Duration(milliseconds: 300),
      );
      expect(feed(trigger, 400, true), isFalse);
      expect(feed(trigger, 500, true), isTrue);
      expect(feed(trigger, 2000, true), isFalse);
      expect(trigger.pendingFor(at(2000), dwell), isNull);
    });

    test('leaving the zone before the dwell time cancels it', () {
      final trigger = DwellTrigger();
      feed(trigger, 0, true);
      feed(trigger, 300, false);
      expect(feed(trigger, 600, true), isFalse);
      expect(feed(trigger, 1100, true), isTrue);
    });

    test('rearms only after staying outside for the rearm delay', () {
      final trigger = DwellTrigger();
      feed(trigger, 0, true);
      expect(feed(trigger, 500, true), isTrue);
      // Brief excursion: not rearmed.
      feed(trigger, 1000, false);
      feed(trigger, 2000, true);
      expect(feed(trigger, 3000, true), isFalse);
      // Sustained excursion (>= 3 s): rearmed.
      feed(trigger, 4000, false);
      feed(trigger, 7000, false);
      feed(trigger, 7100, true);
      expect(feed(trigger, 7600, true), isTrue);
    });

    test('rearm() allows a retry after a failed attempt', () {
      final trigger = DwellTrigger();
      feed(trigger, 0, true);
      expect(feed(trigger, 500, true), isTrue);
      trigger.rearm();
      expect(feed(trigger, 600, true), isTrue);
    });
  });

  group('AltitudeRecordTrigger', () {
    test('continuous climb from launch is not a record', () {
      final trigger = AltitudeRecordTrigger();
      for (var altitude = 800.0; altitude < 1500; altitude += 5) {
        expect(trigger.update(altitude), isFalse);
      }
      expect(trigger.peak, 1495);
    });

    test('announces when exceeding the peak after dropping below it', () {
      final trigger = AltitudeRecordTrigger();
      trigger.update(1000);
      trigger.update(1500);
      trigger.update(1490); // noise, not enough to rearm
      expect(trigger.update(1501), isFalse);
      trigger.update(1450); // dropped > 20 m: armed
      expect(trigger.armed, isTrue);
      expect(trigger.update(1500), isFalse);
      expect(trigger.update(1502), isTrue);
      // Keeps climbing: no repeated announcements.
      expect(trigger.update(1520), isFalse);
      expect(trigger.update(1600), isFalse);
    });

    test('all-flights baseline is the record to beat', () {
      final trigger = AltitudeRecordTrigger()..reset(baseline: 2000);
      expect(trigger.update(900), isFalse);
      expect(trigger.update(1999), isFalse);
      expect(trigger.update(2001), isTrue);
      expect(trigger.update(2100), isFalse);
    });

    test('a launch above the baseline is not announced', () {
      final trigger = AltitudeRecordTrigger()..reset(baseline: 1000);
      expect(trigger.update(1200), isFalse);
      expect(trigger.update(1300), isFalse);
    });
  });
}
