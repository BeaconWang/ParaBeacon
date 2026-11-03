import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/data/competition/task_polyline.dart';

void main() {
  group('TaskPolyline', () {
    test('round-trips signed integers (absolute, per-value)', () {
      final values = [
        610000, // lon*1e5 ~ 6.1
        4650000, // lat*1e5 ~ 46.5
        1200, // alt
        400, // radius
        -12345,
        0,
      ];
      final encoded = TaskPolyline.encode(values);
      expect(TaskPolyline.decode(encoded), values);
    });

    test('rejects truncated input', () {
      // A lone continuation char (0x20|something + 63) with no terminator.
      expect(TaskPolyline.decode(String.fromCharCode((0x20 | 1) + 63)), isEmpty);
    });
  });

  group('CompetitionTask compact (v2) QR format', () {
    test('encodes and parses a compact task round-trip', () {
      final task = CompetitionTask(
        name: 'Test',
        turnpoints: [
          Turnpoint(
            waypoint: const TaskWaypoint(
              name: 'D01',
              latitude: 46.5,
              longitude: 6.1,
              altitudeM: 1200,
            ),
            radiusMeters: 400,
            role: TurnpointRole.takeoff,
          ),
          Turnpoint(
            waypoint: const TaskWaypoint(
              name: 'START',
              latitude: 46.55,
              longitude: 6.15,
              altitudeM: 1100,
            ),
            radiusMeters: 1000,
            role: TurnpointRole.sss,
          ),
          Turnpoint(
            waypoint: const TaskWaypoint(
              name: 'GOAL',
              latitude: 46.7,
              longitude: 6.3,
              altitudeM: 900,
            ),
            radiusMeters: 200,
            role: TurnpointRole.ess,
          ),
        ],
        start: const TaskStart(
          type: TaskStartType.race,
          direction: TaskStartDirection.exit,
          timeGates: [45000], // 12:30:00
        ),
        goal: const TaskGoal(
          type: TaskGoalType.cylinder,
          deadlineSeconds: 54000, // 15:00:00
        ),
      );

      final code = task.toTaskCode();
      expect(code.startsWith('XCTSK:'), isTrue);

      final parsed = CompetitionTask.tryParse(code);
      expect(parsed, isNotNull);
      expect(parsed!.turnpoints.length, 3);

      // Coordinates survive the 1e5 polyline quantization.
      expect(parsed.turnpoints[0].latitude, closeTo(46.5, 1e-5));
      expect(parsed.turnpoints[0].longitude, closeTo(6.1, 1e-5));
      expect(parsed.turnpoints[0].radiusMeters, 400);
      expect(parsed.turnpoints[0].role, TurnpointRole.takeoff);
      expect(parsed.turnpoints[1].role, TurnpointRole.sss);
      expect(parsed.turnpoints[1].radiusMeters, 1000);
      expect(parsed.turnpoints[2].role, TurnpointRole.ess);

      expect(parsed.start, isNotNull);
      expect(parsed.start!.type, TaskStartType.race);
      expect(parsed.start!.direction, TaskStartDirection.exit);
      expect(parsed.start!.timeGates, [45000]);

      expect(parsed.goal.type, TaskGoalType.cylinder);
      expect(parsed.goal.deadlineSeconds, 54000);
    });

    test('parses a long (v1) task code too', () {
      final task = CompetitionTask(
        turnpoints: [
          Turnpoint(
            waypoint: const TaskWaypoint(
              name: 'A',
              latitude: 45.0,
              longitude: 7.0,
            ),
            radiusMeters: 400,
          ),
          Turnpoint(
            waypoint: const TaskWaypoint(
              name: 'B',
              latitude: 45.1,
              longitude: 7.1,
            ),
            radiusMeters: 400,
          ),
        ],
      );
      final longCode = task.toLongTaskCode();
      final parsed = CompetitionTask.tryParse(longCode);
      expect(parsed, isNotNull);
      expect(parsed!.turnpoints.length, 2);
      expect(parsed.turnpoints[1].latitude, closeTo(45.1, 1e-9));
    });

    test('rejects junk', () {
      expect(CompetitionTask.tryParse('not a task'), isNull);
      expect(CompetitionTask.tryParse('XCTSK:{"foo":1}'), isNull);
      expect(CompetitionTask.tryParse(''), isNull);
    });
  });
}
