import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/competition_task_preview_sheet.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

const _task = CompetitionTask(
  name: 'Alpine Route',
  turnpoints: [
    Turnpoint(
      waypoint: TaskWaypoint(
        name: 'Start Gate',
        latitude: 47.1,
        longitude: 8.5,
      ),
      radiusMeters: 400,
      role: TurnpointRole.sss,
    ),
    Turnpoint(
      waypoint: TaskWaypoint(name: 'Goal', latitude: 47.2, longitude: 8.6),
      radiusMeters: 200,
      role: TurnpointRole.ess,
    ),
  ],
  start: TaskStart(
    type: TaskStartType.race,
    direction: TaskStartDirection.exit,
    timeGates: [36000],
  ),
  goal: TaskGoal(type: TaskGoalType.line, deadlineSeconds: 64800),
);

Widget _previewHost(ValueChanged<bool?> onResult) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async {
          final l10n = AppLocalizations.of(context);
          onResult(
            await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) =>
                  CompetitionTaskPreviewSheet(task: _task, l10n: l10n),
            ),
          );
        },
        child: const Text('Open preview'),
      ),
    ),
  ),
);

void main() {
  testWidgets('previews route details and applies only after confirmation', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(_previewHost((value) => result = value));
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    expect(find.text('Preview task'), findsOneWidget);
    expect(find.text('Alpine Route'), findsOneWidget);
    expect(find.text('Start Gate'), findsOneWidget);
    expect(find.text('Goal'), findsNWidgets(2));
    expect(find.textContaining('Race to goal'), findsOneWidget);
    expect(find.textContaining('Goal type: Line'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.text('Use this task'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('canceling preview does not apply the task', (tester) async {
    bool? result;
    await tester.pumpWidget(_previewHost((value) => result = value));
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
