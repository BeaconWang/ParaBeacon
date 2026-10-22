import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/audio/announcement_triggers.dart';
import 'package:parabeacon/audio/custom_announcement_rule.dart';
import 'package:parabeacon/data/flight_data.dart';

void main() {
  group('CustomAnnouncementRule', () {
    const greater = CustomAnnouncementRule(
      id: 1,
      metric: AnnouncementMetric.verticalSpeed,
      condition: AnnouncementCondition.greaterThan,
      threshold: 2,
      upperThreshold: 4,
      repeatSeconds: null,
      enabled: true,
      content: 'Climb detected',
    );

    test('supports strict greater-than and less-than judgments', () {
      expect(greater.matches(const FlightData(verticalSpeed: 2)), isFalse);
      expect(greater.matches(const FlightData(verticalSpeed: 2.1)), isTrue);
      final less = greater.copyWith(
        condition: AnnouncementCondition.lessThan,
        threshold: 2,
      );
      expect(less.matches(const FlightData(verticalSpeed: 2)), isFalse);
      expect(less.matches(const FlightData(verticalSpeed: 1.9)), isTrue);
    });

    test(
      'range endpoints are inclusive and invalid sensor data is ignored',
      () {
        final range = greater.copyWith(
          condition: AnnouncementCondition.withinRange,
          threshold: 2,
          upperThreshold: 4,
        );
        expect(range.matches(const FlightData(verticalSpeed: 2)), isTrue);
        expect(range.matches(const FlightData(verticalSpeed: 4)), isTrue);
        expect(range.matches(const FlightData(verticalSpeed: 4.1)), isFalse);
        expect(
          greater
              .copyWith(metric: AnnouncementMetric.temperature)
              .matches(const FlightData()),
          isFalse,
        );
      },
    );

    test(
      'serializes safely, enforces rule limits, and skips malformed data',
      () {
        final encoded = CustomAnnouncementRule.encodeList([greater]);
        expect(
          CustomAnnouncementRule.encodeList(
            CustomAnnouncementRule.decodeList(encoded),
          ),
          encoded,
        );
        expect(CustomAnnouncementRule.decodeList('{bad'), isEmpty);
        expect(CustomAnnouncementRule.decodeList('[{"id":-1}]'), isEmpty);
        expect(
          CustomAnnouncementRule.decodeList(
            CustomAnnouncementRule.encodeList(
              List.generate(
                CustomAnnouncementRule.maxRules + 2,
                (index) => CustomAnnouncementRule(
                  id: index,
                  metric: greater.metric,
                  condition: greater.condition,
                  threshold: index.toDouble(),
                  upperThreshold: greater.upperThreshold,
                  repeatSeconds: greater.repeatSeconds,
                  enabled: greater.enabled,
                  content: greater.content,
                ),
              ),
            ),
          ).length,
          CustomAnnouncementRule.maxRules,
        );
      },
    );
  });

  group('ConditionRepeatTrigger', () {
    final start = DateTime(2026, 1, 1);
    DateTime at(int seconds) => start.add(Duration(seconds: seconds));

    test('fires on entry, repeats after interval, and rearms on exit', () {
      final trigger = ConditionRepeatTrigger();
      const repeat = Duration(seconds: 5);
      expect(
        trigger.update(at(0), condition: true, repeatEvery: repeat),
        isTrue,
      );
      expect(
        trigger.update(at(4), condition: true, repeatEvery: repeat),
        isFalse,
      );
      expect(trigger.pendingFor(at(4), repeat), const Duration(seconds: 1));
      expect(
        trigger.update(at(5), condition: true, repeatEvery: repeat),
        isTrue,
      );
      expect(
        trigger.update(at(6), condition: false, repeatEvery: repeat),
        isFalse,
      );
      expect(
        trigger.update(at(7), condition: true, repeatEvery: repeat),
        isTrue,
      );
    });

    test('retries immediately after a transient playback failure', () {
      final trigger = ConditionRepeatTrigger();
      const repeat = Duration(seconds: 15);
      expect(
        trigger.update(at(0), condition: true, repeatEvery: repeat),
        isTrue,
      );
      trigger.retryNow();
      expect(
        trigger.update(at(1), condition: true, repeatEvery: repeat),
        isTrue,
      );
    });
  });
}
