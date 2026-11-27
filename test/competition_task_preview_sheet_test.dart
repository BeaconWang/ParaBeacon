import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/competition_task_preview_sheet.dart';
import 'package:parabeacon/data/competition/competition_task.dart';
import 'package:parabeacon/data/map_view_source_settings.dart';
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

Widget _previewHost(
  ValueChanged<CompetitionTaskPreviewAction?> onResult, {
  String mapSourceId = 'none',
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async {
          final l10n = AppLocalizations.of(context);
          onResult(
            await showModalBottomSheet<CompetitionTaskPreviewAction>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => CompetitionTaskPreviewSheet(
                task: _task,
                l10n: l10n,
                mapSourceId: mapSourceId,
              ),
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
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CompetitionTaskPreviewAction? result;
    await tester.pumpWidget(_previewHost((value) => result = value));
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    expect(find.text('Preview task'), findsOneWidget);
    expect(find.text('Alpine Route'), findsOneWidget);
    expect(find.text('Start Gate'), findsOneWidget);
    expect(find.text('Goal'), findsNWidgets(2));
    expect(find.textContaining('Race to goal'), findsOneWidget);
    expect(find.textContaining('Goal type: Line'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(
      tester.widget<CircleLayer>(find.byType(CircleLayer)).circles,
      hasLength(2),
    );
    expect(
      tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
      hasLength(1),
    );
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(2),
    );
    expect(result, isNull);

    await tester.tap(find.text('Use this task'));
    await tester.pumpAndSettle();
    expect(result, CompetitionTaskPreviewAction.useServerTask);
  });

  testWidgets('changes and remembers the map source from the preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CompetitionTaskPreviewAction? result;
    await tester.pumpWidget(
      _previewHost((value) => result = value, mapSourceId: 'none'),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Map source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenStreetMap'));
    await tester.pumpAndSettle();

    expect(find.text('OpenStreetMap'), findsOneWidget);
    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
    expect(MapViewSourceSettings.instance.pickerSourceId, 'osm');
    expect(result, isNull);
  });

  testWidgets('copy action returns a local-copy choice', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CompetitionTaskPreviewAction? result;
    await tester.pumpWidget(_previewHost((value) => result = value));
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy to current local task'));
    await tester.pumpAndSettle();
    expect(result, CompetitionTaskPreviewAction.copyToLocal);
  });

  testWidgets('canceling preview does not apply the task', (tester) async {
    CompetitionTaskPreviewAction? result;
    await tester.pumpWidget(_previewHost((value) => result = value));
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
