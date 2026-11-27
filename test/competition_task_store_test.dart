import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/data/competition/competition_task_store.dart';
import 'package:parabeacon/data/geo_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reorders turnpoints using the adjusted destination index', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CompetitionTaskStore.instance;
    const a = Turnpoint(
      waypoint: TaskWaypoint(name: 'A', latitude: 0, longitude: 0),
      radiusMeters: 100,
    );
    const b = Turnpoint(
      waypoint: TaskWaypoint(name: 'B', latitude: 1, longitude: 1),
      radiusMeters: 100,
    );
    const c = Turnpoint(
      waypoint: TaskWaypoint(name: 'C', latitude: 2, longitude: 2),
      radiusMeters: 100,
    );
    await store.setTask(const CompetitionTask(turnpoints: [a, b, c]));

    await store.moveTurnpoint(0, 2);
    expect(store.task!.turnpoints.map((point) => point.name), ['B', 'C', 'A']);

    await store.moveTurnpoint(2, 0);
    expect(store.task!.turnpoints.map((point) => point.name), ['A', 'B', 'C']);
  });

  test(
    'persists radius reduction and navigates against effective radius',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CompetitionTaskStore.instance;
      await store.load();

      expect(
        store.radiusReductionMeters,
        CompetitionTaskStore.defaultRadiusReductionMeters,
      );
      await store.setRadiusReductionMeters(25);
      expect(store.radiusReductionMeters, 25);

      const turnpoint = Turnpoint(
        waypoint: TaskWaypoint(name: 'A', latitude: 0, longitude: 0),
        radiusMeters: 100,
      );
      await store.setTask(const CompetitionTask(turnpoints: [turnpoint]));

      final route = store.liveRouteToGoal(0.01, 0);
      expect(route, isNotNull);
      expect(
        GeoMath.distanceMeters(0, 0, route![1].$1, route[1].$2),
        closeTo(75, 0.5),
      );

      final outside = GeoMath.destination(0, 0, 0, 81);
      expect(store.updatePosition(outside[0], outside[1]), isFalse);
      final inside = GeoMath.destination(0, 0, 0, 79);
      expect(store.updatePosition(inside[0], inside[1]), isTrue);

      expect(store.effectiveRadiusMeters(turnpoint), 75);
      expect(store.task!.turnpoints.single.radiusMeters, 100);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('pb.competition.radiusReductionMeters'), 25);

      const ownerId = '11111111-1111-4111-8111-111111111111';
      final serverTask = CompetitionTask(
        name: 'Server route',
        turnpoints: [turnpoint],
      );
      await store.setServerTask(serverTask, ownerId: ownerId);
      expect(store.isCurrentTaskServerSourced, isTrue);
      expect(store.canAutoSyncCurrentTask, isFalse);
      await store.setName('Attempted edit');
      expect(store.task!.name, 'Server route');
      await store.setTask(const CompetitionTask(turnpoints: []));
      expect(store.task!.name, 'Server route');

      final serverRecord =
          jsonDecode(preferences.getString('pb.competition.task.v1')!)
              as Map<String, dynamic>;
      expect(serverRecord['serverTaskOwnerId'], ownerId);
      expect(serverRecord['isLocalServerCopy'], isNull);

      await store.copyTaskFromServer(serverTask, ownerId: ownerId);
      expect(store.isCurrentTaskServerSourced, isFalse);
      expect(store.isCurrentTaskLocalCopy, isTrue);
      expect(store.canAutoSyncCurrentTask, isFalse);
      final copyRecord =
          jsonDecode(preferences.getString('pb.competition.task.v1')!)
              as Map<String, dynamic>;
      expect(copyRecord['serverTaskOwnerId'], ownerId);
      expect(copyRecord['isLocalServerCopy'], isTrue);
      await store.setName('Editable local copy');
      expect(store.task!.name, 'Editable local copy');

      await store.setTask(const CompetitionTask(turnpoints: [turnpoint]));
      expect(store.serverTaskOwnerId, isNull);
      expect(store.isCurrentTaskLocalCopy, isFalse);
      expect(store.canAutoSyncCurrentTask, isTrue);
    },
  );

  test(
    'runs Takeoff, Start, turnpoints and End, then saves the result',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = CompetitionTaskStore.instance;
      final pendingBefore = store.pendingResults.length;
      final resultsBefore = store.savedResults.length;
      await store.clear();
      const task = CompetitionTask(
        name: 'Local race',
        turnpoints: [
          Turnpoint(
            waypoint: TaskWaypoint(name: 'Takeoff', latitude: 0, longitude: 0),
            radiusMeters: 1000,
            role: TurnpointRole.takeoff,
          ),
          Turnpoint(
            waypoint: TaskWaypoint(name: 'Start', latitude: 0, longitude: 0),
            radiusMeters: 1000,
            role: TurnpointRole.sss,
          ),
          Turnpoint(
            waypoint: TaskWaypoint(name: 'TP1', latitude: 0, longitude: 0),
            radiusMeters: 1000,
          ),
          Turnpoint(
            waypoint: TaskWaypoint(name: 'TP2', latitude: 0, longitude: 0),
            radiusMeters: 1000,
          ),
          Turnpoint(
            waypoint: TaskWaypoint(name: 'End', latitude: 0, longitude: 0),
            radiusMeters: 1000,
            role: TurnpointRole.ess,
          ),
        ],
      );
      await store.setTask(task);

      final takeoffAt = DateTime.utc(2026, 1, 1, 10);
      expect(store.nextTurnpointIndex, 0);
      expect(store.updatePosition(0, 0, at: takeoffAt), isTrue);
      expect(store.nextTurnpointIndex, 1);
      expect(store.competitionStartedAt, isNull);

      final startedAt = takeoffAt.add(const Duration(minutes: 2));
      expect(store.updatePosition(0, 0, at: startedAt), isTrue);
      expect(store.competitionStartedAt, startedAt);
      expect(store.nextTurnpointIndex, 2);

      store.setNextTurnpointIndex(3);
      expect(store.nextTurnpointIndex, 3);
      expect(
        store.updatePosition(
          0,
          0,
          at: startedAt.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
      expect(store.nextTurnpointIndex, 4);
      final finishedAt = startedAt.add(const Duration(minutes: 7, seconds: 12));
      expect(store.updatePosition(0, 0, at: finishedAt), isTrue);
      expect(store.isCompetitionFinished, isTrue);
      expect(
        store.pendingResult?.elapsed,
        const Duration(minutes: 7, seconds: 12),
      );
      expect(store.updatePosition(0, 0, at: finishedAt), isFalse);
      expect(store.pendingResults, hasLength(pendingBefore + 1));
      final localResult = store.pendingResult!;
      expect(localResult.taskName, 'Local race');

      await store.savePendingResult(localResult);
      expect(store.pendingResults, hasLength(pendingBefore));
      expect(store.savedResults, hasLength(resultsBefore + 1));
      expect(store.savedResults.first.taskName, 'Local race');
      final preferences = await SharedPreferences.getInstance();
      final savedResults =
          jsonDecode(preferences.getString('pb.competition.results.v1')!)
              as List<dynamic>;
      expect(savedResults, hasLength(resultsBefore + 1));

      await store.clear();
      const ownerId = '11111111-1111-4111-8111-111111111111';
      await store.setServerTask(task, ownerId: ownerId);
      expect(store.isCurrentTaskServerSourced, isTrue);
      store.setNextTurnpointIndex(2);
      expect(store.nextTurnpointIndex, 2);
      expect(store.updatePosition(0, 0, at: startedAt), isTrue);
      expect(store.nextTurnpointIndex, 3);
    },
  );
}
