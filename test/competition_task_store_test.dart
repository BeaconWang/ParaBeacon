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
    },
  );
}
