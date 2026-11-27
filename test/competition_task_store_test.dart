import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/data/competition/competition_task_store.dart';
import 'package:parabeacon/data/geo_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
