import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/competition_task_sheet.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/data/competition/competition_task_store.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'selects objectives on local/server tasks and saves a finished result',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = CompetitionTaskStore.instance;
      await store.clear();
      const task = CompetitionTask(
        name: 'Server race',
        turnpoints: [
          Turnpoint(
            waypoint: TaskWaypoint(name: 'Takeoff', latitude: 0, longitude: 0),
            radiusMeters: 1000,
            role: TurnpointRole.takeoff,
          ),
          Turnpoint(
            waypoint: TaskWaypoint(
              name: 'Start gate',
              latitude: 0,
              longitude: 0,
            ),
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

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCompetitionTaskSheet(context),
                child: const Text('Open competition task'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open competition task'));
      await tester.pumpAndSettle();

      final tp2 = find.text('TP2');
      await tester.ensureVisible(tp2);
      await tester.tap(tp2);
      await tester.pumpAndSettle();
      expect(store.nextTurnpointIndex, 3);
      expect(
        tester
            .widget<ListTile>(
              find.ancestor(of: tp2, matching: find.byType(ListTile)).first,
            )
            .selected,
        isTrue,
      );

      const ownerId = '11111111-1111-4111-8111-111111111111';
      await store.setServerTask(task, ownerId: ownerId);
      await tester.pumpAndSettle();
      final tp1 = find.text('TP1');
      await tester.ensureVisible(tp1);
      await tester.tap(tp1);
      await tester.pumpAndSettle();
      expect(store.isCurrentTaskServerSourced, isTrue);
      expect(store.nextTurnpointIndex, 2);

      store.setNextTurnpointIndex(0);
      final startedAt = DateTime.utc(2026, 4, 5, 10);
      expect(store.updatePosition(0, 0, at: startedAt), isTrue);
      expect(store.nextTurnpointIndex, 1);
      expect(
        store.updatePosition(
          0,
          0,
          at: startedAt.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
      expect(
        store.competitionStartedAt,
        startedAt.add(const Duration(minutes: 1)),
      );
      expect(
        store.updatePosition(
          0,
          0,
          at: startedAt.add(const Duration(minutes: 2)),
        ),
        isTrue,
      );
      expect(
        store.updatePosition(
          0,
          0,
          at: startedAt.add(const Duration(minutes: 3)),
        ),
        isTrue,
      );
      expect(
        store.updatePosition(
          0,
          0,
          at: startedAt.add(const Duration(minutes: 4)),
        ),
        isTrue,
      );
      expect(store.pendingResult, isNotNull);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
      await tester.pumpAndSettle();

      final saveResult = find.text('Save result');
      await tester.ensureVisible(saveResult);
      expect(saveResult, findsOneWidget);
      await tester.tap(saveResult);
      await tester.pumpAndSettle();
      expect(store.pendingResult, isNull);
      expect(store.savedResults, hasLength(1));
      expect(store.savedResults.single.serverTaskOwnerId, ownerId);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
