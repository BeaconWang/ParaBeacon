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

    group('with repeat interval', () {
      const delay = Duration(milliseconds: 100);
      const repeat = Duration(seconds: 5);
      bool feedRepeat(DwellTrigger trigger, int ms, bool inside) =>
          trigger.update(
            at(ms),
            inside: inside,
            rearming: !inside,
            dwell: delay,
            repeatEvery: repeat,
          );

      test('repeats every interval while staying in the zone', () {
        final trigger = DwellTrigger();
        expect(feedRepeat(trigger, 0, true), isFalse);
        expect(feedRepeat(trigger, 100, true), isTrue);
        expect(feedRepeat(trigger, 3000, true), isFalse);
        expect(
          trigger.pendingFor(at(3000), delay, repeat),
          const Duration(milliseconds: 2100),
        );
        expect(feedRepeat(trigger, 5099, true), isFalse);
        expect(feedRepeat(trigger, 5100, true), isTrue);
        expect(feedRepeat(trigger, 10100, true), isTrue);
      });

      test('a brief excursion keeps the cadence', () {
        final trigger = DwellTrigger();
        feedRepeat(trigger, 0, true);
        expect(feedRepeat(trigger, 100, true), isTrue);
        feedRepeat(trigger, 1000, false);
        expect(feedRepeat(trigger, 2000, true), isFalse);
        expect(feedRepeat(trigger, 5000, true), isFalse);
        expect(feedRepeat(trigger, 5100, true), isTrue);
      });

      test('after leaving the zone for 3 s, re-entry starts over', () {
        final trigger = DwellTrigger();
        feedRepeat(trigger, 0, true);
        expect(feedRepeat(trigger, 100, true), isTrue);
        feedRepeat(trigger, 1000, false);
        feedRepeat(trigger, 4000, false);
        expect(feedRepeat(trigger, 4100, true), isFalse);
        expect(feedRepeat(trigger, 4200, true), isTrue);
      });

      test('stops repeating outside the zone', () {
        final trigger = DwellTrigger();
        feedRepeat(trigger, 0, true);
        expect(feedRepeat(trigger, 100, true), isTrue);
        expect(feedRepeat(trigger, 5100, false), isFalse);
        expect(trigger.pendingFor(at(5100), delay, repeat), isNull);
      });
    });
  });

  group('AltitudeRecordTrigger', () {
    const interval = Duration(seconds: 5);
    bool feed(AltitudeRecordTrigger trigger, int ms, double altitude) =>
        trigger.update(altitude, at(ms), minInterval: interval);

    test('first altitude of the flight is the reference', () {
      final trigger = AltitudeRecordTrigger();
      expect(feed(trigger, 0, 800), isFalse);
      expect(feed(trigger, 1000, 800.5), isFalse); // < 1 m gain
      expect(feed(trigger, 2000, 801), isTrue);
      expect(trigger.peak, 801);
    });

    test('consecutive records are at least the interval apart', () {
      final trigger = AltitudeRecordTrigger();
      feed(trigger, 0, 1000);
      expect(feed(trigger, 1000, 1002), isTrue);
      // Climbing on: new records, but within 5 s of the last announcement.
      expect(feed(trigger, 2000, 1004), isFalse);
      expect(feed(trigger, 4000, 1008), isFalse);
      expect(
        trigger.pendingFor(at(4000), interval),
        const Duration(seconds: 2),
      );
      // Interval over: the highest value reached is announced, even after
      // a small descent.
      expect(feed(trigger, 6000, 1007), isTrue);
      expect(trigger.peak, 1008);
      // No new record since: nothing pending.
      expect(feed(trigger, 20000, 1008), isFalse);
      expect(trigger.pendingFor(at(20000), interval), isNull);
      // A later record is announced immediately.
      expect(feed(trigger, 21000, 1010), isTrue);
    });

    test('interval is adjustable', () {
      final trigger = AltitudeRecordTrigger();
      bool feedLong(int ms, double altitude) => trigger.update(
        altitude,
        at(ms),
        minInterval: const Duration(seconds: 15),
      );
      feedLong(0, 1000);
      expect(feedLong(1000, 1005), isTrue);
      expect(feedLong(10000, 1050), isFalse);
      expect(feedLong(16000, 1060), isTrue);
    });

    test('a failed announcement is retried', () {
      final trigger = AltitudeRecordTrigger();
      feed(trigger, 0, 1000);
      expect(feed(trigger, 1000, 1005), isTrue);
      trigger.undoLastAnnouncement();
      expect(feed(trigger, 1100, 1005), isTrue);
    });

    test('peak is tracked while announcements are off', () {
      final trigger = AltitudeRecordTrigger();
      feed(trigger, 0, 1000);
      expect(
        trigger.update(1200, at(1000), minInterval: interval, announce: false),
        isFalse,
      );
      expect(trigger.peak, 1200);
    });

    test('all-flights baseline is the record to beat', () {
      final trigger = AltitudeRecordTrigger()..reset(baseline: 2000);
      expect(feed(trigger, 0, 900), isFalse);
      expect(feed(trigger, 1000, 2000.5), isFalse);
      expect(feed(trigger, 2000, 2001), isTrue);
      expect(feed(trigger, 3000, 2100), isFalse);
      expect(feed(trigger, 7000, 2100), isTrue);
    });
  });
}
