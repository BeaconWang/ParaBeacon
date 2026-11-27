import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/competition/competition_task.dart';
import '../data/gcj02.dart';
import '../data/map_tile_cache.dart';
import '../data/map_view_source_settings.dart';
import '../l10n/app_localizations.dart';
import 'map_control.dart' show MapTileSource, MapTileSources;

enum CompetitionTaskPreviewAction { useServerTask, copyToLocal }

class CompetitionTaskPreviewSheet extends StatelessWidget {
  const CompetitionTaskPreviewSheet({
    required this.task,
    required this.l10n,
    this.mapSourceId,
    super.key,
  });

  final CompetitionTask task;
  final AppLocalizations l10n;
  final String? mapSourceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskName = task.name.trim().isEmpty
        ? l10n.competitionUnnamedTask
        : task.name;
    final start = task.start;
    final goalType = task.goal.type == TaskGoalType.line
        ? l10n.competitionGoalLine
        : l10n.competitionGoalCylinder;
    final deadline = task.goal.deadlineSeconds == null
        ? l10n.competitionNoDeadline
        : secondsToClock(task.goal.deadlineSeconds!);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.competitionServerPreview,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.flag_outlined),
                        ),
                        title: Text(taskName),
                        subtitle: Text(
                          l10n.competitionTaskSummarySubtitle(
                            task.turnpoints.length,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TaskRouteMapPreview(
                      task: task,
                      initialSourceId: mapSourceId,
                    ),
                    const SizedBox(height: 12),
                    for (var index = 0; index < task.turnpoints.length; index++)
                      _TurnpointPreviewCard(
                        index: index,
                        turnpoint: task.turnpoints[index],
                        l10n: l10n,
                      ),
                    if (start != null)
                      _PreviewInfoCard(
                        title: l10n.competitionStartSection,
                        lines: [
                          '${l10n.competitionStartType}: ${start.type == TaskStartType.race ? l10n.competitionStartTypeRace : l10n.competitionStartTypeElapsed}',
                          '${l10n.competitionStartDirection}: ${start.direction == TaskStartDirection.enter ? l10n.competitionStartEnter : l10n.competitionStartExit}',
                          if (start.timeGates.isNotEmpty)
                            '${l10n.competitionTimeGates}: ${start.timeGates.map(secondsToClock).join(', ')}',
                        ],
                      ),
                    _PreviewInfoCard(
                      title: l10n.competitionGoalSection,
                      lines: [
                        '${l10n.competitionGoalType}: $goalType',
                        '${l10n.competitionDeadline}: $deadline',
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(CompetitionTaskPreviewAction.copyToLocal),
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(l10n.competitionCopyToLocalTask),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(CompetitionTaskPreviewAction.useServerTask),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.competitionServerUseTask),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRouteMapPreview extends StatefulWidget {
  const _TaskRouteMapPreview({required this.task, this.initialSourceId});

  final CompetitionTask task;
  final String? initialSourceId;

  @override
  State<_TaskRouteMapPreview> createState() => _TaskRouteMapPreviewState();
}

class _TaskRouteMapPreviewState extends State<_TaskRouteMapPreview> {
  final MapController _controller = MapController();
  late String _sourceId;

  @override
  void initState() {
    super.initState();
    _sourceId =
        widget.initialSourceId ?? MapViewSourceSettings.instance.pickerSourceId;
    if (widget.initialSourceId == null) _restoreSourceSelection();
  }

  Future<void> _restoreSourceSelection() async {
    await MapViewSourceSettings.instance.load();
    if (mounted) {
      setState(() => _sourceId = MapViewSourceSettings.instance.pickerSourceId);
    }
  }

  void _selectSource(String sourceId) {
    if (sourceId == _sourceId) return;
    setState(() => _sourceId = sourceId);
    unawaited(MapViewSourceSettings.instance.setPickerSourceId(sourceId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitTask(MapTileSources.byId(sourceId));
    });
  }

  String _sourceLabel(MapTileSource source, AppLocalizations l10n) =>
      switch (source.id) {
        'none' => l10n.settingMapSourceNone,
        'osm' => l10n.settingMapSourceOsm,
        'osmfr' => l10n.settingMapSourceOsmFr,
        'carto-dark' => l10n.settingMapSourceCartoDark,
        'carto-voyager' => l10n.settingMapSourceCartoVoyager,
        'google' => l10n.settingMapSourceGoogle,
        'google-sat' => l10n.settingMapSourceGoogleSat,
        'amap' => l10n.settingMapSourceAmap,
        'amap-sat' => l10n.settingMapSourceAmapSat,
        _ => source.label,
      };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLng _displayPoint(Turnpoint turnpoint, MapTileSource source) {
    final point = LatLng(turnpoint.latitude, turnpoint.longitude);
    if (!source.requiresGcjShift) return point;
    final shifted = Gcj02.wgsToGcj(point.latitude, point.longitude);
    return LatLng(shifted[0], shifted[1]);
  }

  void _fitTask(MapTileSource source) {
    final points = widget.task.turnpoints
        .map((point) => _displayPoint(point, source))
        .toList(growable: false);
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.single, 12);
      return;
    }
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
        maxZoom: 14,
      ),
    );
  }

  Color _roleColor(TurnpointRole role, ColorScheme scheme) => switch (role) {
    TurnpointRole.takeoff => const Color(0xFF43A047),
    TurnpointRole.sss => const Color(0xFF1E88E5),
    TurnpointRole.ess => const Color(0xFFF4511E),
    TurnpointRole.turnpoint => scheme.primary,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = MapTileSources.byId(_sourceId);
    final points = widget.task.turnpoints
        .map((point) => _displayPoint(point, source))
        .toList(growable: false);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: points.isEmpty
                      ? const LatLng(0, 0)
                      : points.first,
                  initialZoom: points.length == 1 ? 12 : 8,
                  minZoom: 2,
                  maxZoom: source.maxZoom,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  onMapReady: () => _fitTask(source),
                ),
                children: [
                  if (!source.isNone)
                    TileLayer(
                      key: ValueKey('competition-task-tiles-${source.id}'),
                      urlTemplate: source.urlTemplate,
                      tileProvider: OfflineFirstTileProvider(
                        onlineProvider: MapTileCacheProvider(),
                      ),
                      maxNativeZoom: source.maxZoom.round(),
                      userAgentPackageName: 'com.beacon.parabeacon',
                    ),
                  CircleLayer(
                    circles: [
                      for (
                        var index = 0;
                        index < widget.task.turnpoints.length;
                        index++
                      )
                        CircleMarker(
                          point: points[index],
                          radius: widget.task.turnpoints[index].radiusMeters,
                          useRadiusInMeter: true,
                          color: _roleColor(
                            widget.task.turnpoints[index].role,
                            theme.colorScheme,
                          ).withAlpha(36),
                          borderColor: _roleColor(
                            widget.task.turnpoints[index].role,
                            theme.colorScheme,
                          ),
                          borderStrokeWidth: 2,
                        ),
                    ],
                  ),
                  if (points.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          strokeWidth: 4,
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (var index = 0; index < points.length; index++)
                        Marker(
                          point: points[index],
                          width: 34,
                          height: 34,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _roleColor(
                                widget.task.turnpoints[index].role,
                                theme.colorScheme,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 3),
                              ],
                            ),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: PopupMenuButton<String>(
                tooltip: AppLocalizations.of(context).settingMapSource,
                initialValue: _sourceId,
                onSelected: _selectSource,
                itemBuilder: (context) => [
                  for (final mapSource in MapTileSources.all)
                    PopupMenuItem<String>(
                      value: mapSource.id,
                      child: Row(
                        children: [
                          Icon(
                            mapSource.id == _sourceId
                                ? Icons.check
                                : Icons.layers_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _sourceLabel(
                                mapSource,
                                AppLocalizations.of(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Material(
                  color: theme.colorScheme.surface.withAlpha(230),
                  borderRadius: BorderRadius.circular(8),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_outlined, size: 20),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _sourceLabel(source, AppLocalizations.of(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (source.attribution.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(220),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Text(
                      source.attribution,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TurnpointPreviewCard extends StatelessWidget {
  const _TurnpointPreviewCard({
    required this.index,
    required this.turnpoint,
    required this.l10n,
  });

  final int index;
  final Turnpoint turnpoint;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = turnpoint.name.trim().isEmpty
        ? l10n.competitionTurnpointShort(index + 1)
        : turnpoint.name;
    final role = switch (turnpoint.role) {
      TurnpointRole.takeoff => l10n.competitionRoleTakeoff,
      TurnpointRole.sss => l10n.competitionRoleSss,
      TurnpointRole.ess => l10n.competitionRoleEss,
      TurnpointRole.turnpoint => l10n.competitionRoleTurnpoint,
    };
    final coordinates =
        '${turnpoint.latitude.toStringAsFixed(5)}, '
        '${turnpoint.longitude.toStringAsFixed(5)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(label),
        subtitle: Text(
          '$role · $coordinates · ${turnpoint.radiusMeters.round()} m',
        ),
      ),
    );
  }
}

class _PreviewInfoCard extends StatelessWidget {
  const _PreviewInfoCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final line in lines) Text(line),
        ],
      ),
    ),
  );
}
