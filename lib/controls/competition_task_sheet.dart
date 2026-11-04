import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../data/competition/competition_task.dart';
import '../data/competition/competition_task_downloader.dart';
import '../data/competition/competition_task_io.dart';
import '../data/competition/competition_task_store.dart';
import '../data/competition/qr_image_decoder.dart';
import '../data/flight_data_provider.dart';
import '../data/landing_point_store.dart';
import '../l10n/app_localizations.dart';
import 'competition_task_qr_sheet.dart';
import 'map_picker_sheet.dart';
import 'qr_scanner_screen.dart';

/// Opens the full-screen competition task editor / manager.
Future<void> showCompetitionTaskSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (context) => const _CompetitionTaskSheet(),
  );
}

class _CompetitionTaskSheet extends StatefulWidget {
  const _CompetitionTaskSheet();

  @override
  State<_CompetitionTaskSheet> createState() => _CompetitionTaskSheetState();
}

class _CompetitionTaskSheetState extends State<_CompetitionTaskSheet> {
  final CompetitionTaskStore _store = CompetitionTaskStore.instance;

  @override
  void initState() {
    super.initState();
    _store.load();
    LandingPointStore.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final task = _store.task;
        final optimized = _store.optimized;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.flag, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.competitionTaskTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    _buildMenu(l10n),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: task == null
                    ? _buildEmpty(theme, l10n)
                    : _buildTask(theme, l10n, task, optimized),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenu(AppLocalizations l10n) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'scan_qr':
            await _scanQrCamera(l10n);
            break;
          case 'scan_image':
            await _scanQrImage(l10n);
            break;
          case 'download_url':
            await _downloadFromUrl(l10n);
            break;
          case 'import_file':
            await _importFromFile(l10n);
            break;
          case 'import_code':
            await _importFromCode(l10n);
            break;
          case 'show_qr':
            await _showQr(l10n);
            break;
          case 'export_file':
            await _exportFile(l10n);
            break;
          case 'copy_code':
            await _copyCode(l10n);
            break;
          case 'clear':
            await _confirmClear(l10n);
            break;
        }
      },
      itemBuilder: (context) {
        final hasTask = _store.hasTask;
        return [
          if (isCameraScanSupported)
            PopupMenuItem(
              value: 'scan_qr',
              child: _menuRow(Icons.qr_code_scanner, l10n.competitionScanQr),
            ),
          PopupMenuItem(
            value: 'scan_image',
            child: _menuRow(Icons.image_outlined, l10n.competitionScanImage),
          ),
          PopupMenuItem(
            value: 'download_url',
            child: _menuRow(Icons.cloud_download_outlined, l10n.competitionDownloadUrl),
          ),
          PopupMenuItem(
            value: 'import_file',
            child: _menuRow(Icons.file_open_outlined, l10n.competitionImportFile),
          ),
          PopupMenuItem(
            value: 'import_code',
            child: _menuRow(Icons.content_paste, l10n.competitionImportCode),
          ),
          if (hasTask) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'show_qr',
              child: _menuRow(Icons.qr_code_2, l10n.competitionShowQr),
            ),
            PopupMenuItem(
              value: 'export_file',
              child: _menuRow(Icons.ios_share, l10n.competitionExportFile),
            ),
            PopupMenuItem(
              value: 'copy_code',
              child: _menuRow(Icons.copy_all_outlined, l10n.competitionCopyCode),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'clear',
              child: _menuRow(Icons.delete_outline, l10n.competitionClearTask),
            ),
          ],
        ];
      },
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 12),
      Flexible(child: Text(label)),
    ],
  );

  Widget _buildEmpty(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.competitionNoTask,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _addTurnpoint(l10n),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l10n.competitionAddTurnpoint),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (isCameraScanSupported)
                  OutlinedButton.icon(
                    onPressed: () => _scanQrCamera(l10n),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l10n.competitionScanQr),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _scanQrImage(l10n),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l10n.competitionScanImage),
                ),
                OutlinedButton.icon(
                  onPressed: () => _downloadFromUrl(l10n),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(l10n.competitionDownloadUrl),
                ),
                OutlinedButton.icon(
                  onPressed: () => _importFromFile(l10n),
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(l10n.competitionImportFile),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTask(
    ThemeData theme,
    AppLocalizations l10n,
    CompetitionTask task,
    dynamic optimized,
  ) {
    final totalKm = optimized == null
        ? 0.0
        : (optimized.totalDistanceM as double) / 1000.0;
    final ssKm = optimized == null
        ? 0.0
        : (optimized.speedSectionDistanceM as double) / 1000.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Summary card.
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.name.isEmpty ? l10n.competitionUnnamedTask : task.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: l10n.competitionRenameTask,
                      onPressed: () => _renameTask(l10n, task),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _summaryStat(
                      theme,
                      l10n.competitionTotalDistance,
                      '${totalKm.toStringAsFixed(1)} km',
                    ),
                    _summaryStat(
                      theme,
                      l10n.competitionSpeedSection,
                      '${ssKm.toStringAsFixed(1)} km',
                    ),
                    _summaryStat(
                      theme,
                      l10n.competitionTurnpointsCount,
                      '${task.turnpoints.length}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Turnpoints.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.competitionTurnpoints,
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => _addTurnpoint(l10n),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.competitionAddTurnpoint),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: task.turnpoints.length,
          onReorder: (oldIndex, newIndex) =>
              _store.moveTurnpoint(oldIndex, newIndex),
          itemBuilder: (context, index) {
            final tp = task.turnpoints[index];
            return _TurnpointTile(
              // Identity-based key: stable across reorders and unique even for
              // value-equal turnpoints. Index keys break ReorderableListView's
              // element/overlay reparenting (triggering a `_dependents.isEmpty`
              // assertion when a tile's PopupMenuButton/Tooltip is torn down).
              key: ObjectKey(tp),
              index: index,
              turnpoint: tp,
              l10n: l10n,
              onEdit: () => _editTurnpoint(l10n, index, tp),
              onDelete: () => _store.removeTurnpoint(index),
              onRole: (role) => _store.setTurnpointRole(index, role),
            );
          },
        ),
        const SizedBox(height: 16),

        // Start of speed section.
        _buildStartCard(theme, l10n, task),
        const SizedBox(height: 16),

        // Goal.
        _buildGoalCard(theme, l10n, task),
      ],
    );
  }

  Widget _summaryStat(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }

  Widget _buildStartCard(
    ThemeData theme,
    AppLocalizations l10n,
    CompetitionTask task,
  ) {
    final start = task.start;
    final hasSss = task.sssIndex != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.competitionStartSection, style: theme.textTheme.titleSmall),
            if (!hasSss)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.competitionStartHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 4),
              _choiceRow<TaskStartType>(
                label: l10n.competitionStartType,
                value: start?.type ?? TaskStartType.race,
                options: {
                  TaskStartType.race: l10n.competitionStartTypeRace,
                  TaskStartType.elapsedTime:
                      l10n.competitionStartTypeElapsed,
                },
                onChanged: (v) => _store.setStart(
                  (start ?? const TaskStart()).copyWith(type: v),
                ),
              ),
              _choiceRow<TaskStartDirection>(
                label: l10n.competitionStartDirection,
                value: start?.direction ?? TaskStartDirection.exit,
                options: {
                  TaskStartDirection.exit: l10n.competitionStartExit,
                  TaskStartDirection.enter: l10n.competitionStartEnter,
                },
                onChanged: (v) => _store.setStart(
                  (start ?? const TaskStart()).copyWith(direction: v),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.competitionTimeGates,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addTimeGate(l10n, start),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.competitionAddGate),
                  ),
                ],
              ),
              if ((start?.timeGates ?? const []).isEmpty)
                Text(
                  l10n.competitionNoGates,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < start!.timeGates.length; i++)
                      InputChip(
                        label: Text(secondsToClock(start.timeGates[i])),
                        onDeleted: () {
                          final gates = [...start.timeGates]..removeAt(i);
                          _store.setStart(start.copyWith(timeGates: gates));
                        },
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(
    ThemeData theme,
    AppLocalizations l10n,
    CompetitionTask task,
  ) {
    final goal = task.goal;
    final deadline = goal.deadlineSeconds;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.competitionGoalSection, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _choiceRow<TaskGoalType>(
              label: l10n.competitionGoalType,
              value: goal.type,
              options: {
                TaskGoalType.cylinder: l10n.competitionGoalCylinder,
                TaskGoalType.line: l10n.competitionGoalLine,
              },
              onChanged: (v) => _store.setGoal(goal.copyWith(type: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(l10n.competitionDeadline),
              subtitle: Text(
                deadline == null
                    ? l10n.competitionNoDeadline
                    : secondsToClock(deadline),
              ),
              trailing: deadline == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          _store.setGoal(goal.copyWith(clearDeadline: true)),
                    ),
              onTap: () => _pickDeadline(l10n, goal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceRow<T>({
    required String label,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            items: [
              for (final entry in options.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _addTurnpoint(AppLocalizations l10n) async {
    final waypoint = await _pickWaypoint(l10n);
    if (waypoint == null || !mounted) return;
    final radius = await _pickRadius(l10n, 400);
    if (radius == null || !mounted) return;
    await _store.addTurnpoint(
      Turnpoint(waypoint: waypoint, radiusMeters: radius),
    );
  }

  Future<void> _editTurnpoint(
    AppLocalizations l10n,
    int index,
    Turnpoint tp,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(l10n.competitionEditLocation),
              onTap: () => Navigator.of(context).pop('location'),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_checked),
              title: Text(l10n.competitionEditRadius),
              subtitle: Text('${tp.radiusMeters.round()} m'),
              onTap: () => Navigator.of(context).pop('radius'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.competitionEditName),
              subtitle: Text(tp.name),
              onTap: () => Navigator.of(context).pop('name'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'location':
        final waypoint = await _pickWaypoint(l10n, initial: tp.waypoint);
        if (waypoint != null && mounted) {
          await _store.updateTurnpoint(index, tp.copyWith(waypoint: waypoint));
        }
        break;
      case 'radius':
        final radius = await _pickRadius(l10n, tp.radiusMeters);
        if (radius != null && mounted) {
          await _store.updateTurnpoint(index, tp.copyWith(radiusMeters: radius));
        }
        break;
      case 'name':
        final name = await _pickText(
          l10n,
          title: l10n.competitionEditName,
          initial: tp.name,
        );
        if (name != null && mounted) {
          await _store.updateTurnpoint(
            index,
            tp.copyWith(waypoint: tp.waypoint.copyWith(name: name)),
          );
        }
        break;
    }
  }

  /// Picks a waypoint: via map, saved landing points, or manual entry.
  Future<TaskWaypoint?> _pickWaypoint(
    AppLocalizations l10n, {
    TaskWaypoint? initial,
  }) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(l10n.competitionPickOnMap),
              onTap: () => Navigator.of(context).pop('map'),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(l10n.competitionPickLanding),
              onTap: () => Navigator.of(context).pop('landing'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: Text(l10n.competitionPickManual),
              onTap: () => Navigator.of(context).pop('manual'),
            ),
          ],
        ),
      ),
    );
    if (method == null || !mounted) return null;

    switch (method) {
      case 'map':
        // Centre priority: the waypoint being edited, else the task's last
        // turnpoint, else the current device GPS fix (and finally the picker's
        // own fallback). The basemap defaults to the last-used source.
        double? centerLat = initial?.latitude;
        double? centerLon = initial?.longitude;
        if (centerLat == null || centerLon == null) {
          final last = _store.task?.turnpoints;
          if (last != null && last.isNotEmpty) {
            centerLat = last.last.waypoint.latitude;
            centerLon = last.last.waypoint.longitude;
          }
        }
        if (centerLat == null || centerLon == null) {
          final fix = await _resolveCurrentFix();
          if (!mounted) return null;
          centerLat = fix?.$1;
          centerLon = fix?.$2;
        }
        final picked = await showMapPickerSheet(
          context,
          initialLat: centerLat,
          initialLon: centerLon,
          // Open close-in so turnpoint cylinders are easy to place precisely.
          initialZoom: 17,
          resolveCurrentLocation: _resolveCurrentFix,
        );
        if (picked == null || !mounted) return null;
        final name = await _pickText(
          l10n,
          title: l10n.competitionWaypointName,
          initial: initial?.name ?? _suggestName(),
        );
        if (name == null) return null;
        return TaskWaypoint(
          name: name,
          latitude: picked.$1,
          longitude: picked.$2,
          altitudeM: initial?.altitudeM ?? 0,
        );
      case 'landing':
        return _pickFromLandingPoints(l10n);
      case 'manual':
        return _pickManual(l10n, initial: initial);
    }
    return null;
  }

  /// The device's current position: the live flight-data fix when it has one,
  /// otherwise a one-shot device GPS fix. Null when neither is available.
  /// Backs the map picker's "return to current location" button and the
  /// default centre for a brand-new turnpoint.
  Future<(double, double)?> _resolveCurrentFix() async {
    if (!mounted) return null;
    final live = _liveFix();
    if (live != null) return live;
    return _oneShotFix();
  }

  /// A snapshot of the live flight position, or null when the fix is missing
  /// or implausible (origin/out-of-range guards included).
  (double, double)? _liveFix() {
    final data = FlightDataProvider.transformerOf(context).data;
    final valid =
        data.hasFix &&
        data.latitude.isFinite &&
        data.longitude.isFinite &&
        (data.latitude != 0.0 || data.longitude != 0.0) &&
        data.latitude >= -90 &&
        data.latitude <= 90 &&
        data.longitude >= -180 &&
        data.longitude <= 180;
    return valid ? (data.latitude, data.longitude) : null;
  }

  /// One-shot device position fix; null when permissions/services are off or
  /// the platform cannot provide a fix (e.g. desktop without location).
  Future<(double, double)?> _oneShotFix() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<TaskWaypoint?> _pickFromLandingPoints(AppLocalizations l10n) async {
    await LandingPointStore.instance.load();
    if (!mounted) return null;
    final points = LandingPointStore.instance.points;
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.competitionNoLandingPoints)),
      );
      return null;
    }
    return showModalBottomSheet<TaskWaypoint>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in points)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(p.name),
                subtitle: Text(
                  '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
                ),
                onTap: () => Navigator.of(context).pop(
                  TaskWaypoint(
                    name: p.name,
                    latitude: p.latitude,
                    longitude: p.longitude,
                    altitudeM: p.altitudeM ?? 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<TaskWaypoint?> _pickManual(
    AppLocalizations l10n, {
    TaskWaypoint? initial,
  }) async {
    final nameCtrl = TextEditingController(
      text: initial?.name ?? _suggestName(),
    );
    final latCtrl = TextEditingController(
      text: initial == null ? '' : initial.latitude.toStringAsFixed(6),
    );
    final lonCtrl = TextEditingController(
      text: initial == null ? '' : initial.longitude.toStringAsFixed(6),
    );
    final altCtrl = TextEditingController(
      text: initial == null || initial.altitudeM == 0
          ? ''
          : initial.altitudeM.toStringAsFixed(0),
    );
    String? error;
    final result = await showDialog<TaskWaypoint>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.competitionPickManual),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.competitionWaypointName,
                  ),
                ),
                TextField(
                  controller: latCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
                TextField(
                  controller: lonCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
                TextField(
                  controller: altCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.competitionWaypointAltitude,
                    suffixText: 'm',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final lat = double.tryParse(latCtrl.text.trim());
                final lon = double.tryParse(lonCtrl.text.trim());
                final alt = double.tryParse(altCtrl.text.trim()) ?? 0;
                if (lat == null ||
                    lon == null ||
                    lat < -90 ||
                    lat > 90 ||
                    lon < -180 ||
                    lon > 180) {
                  setState(() => error = l10n.competitionInvalidCoordinates);
                  return;
                }
                final name = nameCtrl.text.trim().isEmpty
                    ? _suggestName()
                    : nameCtrl.text.trim();
                Navigator.of(context).pop(
                  TaskWaypoint(
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    altitudeM: alt.isFinite ? alt : 0,
                  ),
                );
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    latCtrl.dispose();
    lonCtrl.dispose();
    altCtrl.dispose();
    return result;
  }

  Future<double?> _pickRadius(AppLocalizations l10n, double initial) {
    return showDialog<double>(
      context: context,
      builder: (context) => _CompetitionRadiusDialog(
        initial: initial,
        l10n: l10n,
      ),
    );
  }

  Future<String?> _pickText(
    AppLocalizations l10n, {
    required String title,
    required String initial,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CompetitionTextEntryDialog(
        title: title,
        initial: initial,
        l10n: l10n,
      ),
    );
    if (result == null) return null;
    return result.isEmpty ? _suggestName() : result;
  }

  String _suggestName() {
    final count = _store.task?.turnpoints.length ?? 0;
    return 'TP${count + 1}';
  }

  Future<void> _addTimeGate(AppLocalizations l10n, TaskStart? start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    final seconds = picked.hour * 3600 + picked.minute * 60;
    final base = start ?? const TaskStart();
    final gates = [...base.timeGates];
    if (!gates.contains(seconds)) gates.add(seconds);
    gates.sort();
    await _store.setStart(base.copyWith(timeGates: gates));
  }

  Future<void> _pickDeadline(AppLocalizations l10n, TaskGoal goal) async {
    final current = goal.deadlineSeconds;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay(hour: current ~/ 3600, minute: (current % 3600) ~/ 60),
    );
    if (picked == null || !mounted) return;
    await _store.setGoal(
      goal.copyWith(deadlineSeconds: picked.hour * 3600 + picked.minute * 60),
    );
  }

  Future<void> _renameTask(AppLocalizations l10n, CompetitionTask task) async {
    final name = await _pickText(
      l10n,
      title: l10n.competitionRenameTask,
      initial: task.name,
    );
    if (name != null && mounted) await _store.setName(name);
  }

  Future<void> _applyLoadedText(AppLocalizations l10n, String? text) async {
    if (text == null || text.trim().isEmpty || !mounted) return;
    final task = CompetitionTask.tryParse(text);
    if (task == null) {
      _snack(l10n.competitionImportFailed);
      return;
    }
    await _store.setTask(task);
    if (mounted) _snack(l10n.competitionImported);
  }

  Future<void> _scanQrCamera(AppLocalizations l10n) async {
    try {
      final text = await scanQrWithCamera(context);
      if (!mounted) return;
      await _applyLoadedText(l10n, text);
    } catch (_) {
      if (mounted) _snack(l10n.competitionScanFailed);
    }
  }

  Future<void> _scanQrImage(AppLocalizations l10n) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.competitionScanImage,
        type: FileType.image,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || !mounted) {
        if (mounted) _snack(l10n.competitionScanFailed);
        return;
      }
      final text = await QrImageDecoder.decodeBytes(bytes);
      if (!mounted) return;
      if (text == null) {
        _snack(l10n.competitionNoQrFound);
        return;
      }
      await _applyLoadedText(l10n, text);
    } catch (_) {
      if (mounted) _snack(l10n.competitionScanFailed);
    }
  }

  Future<void> _downloadFromUrl(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = clip?.text?.trim() ?? '';
    if (clipText.startsWith('http://') || clipText.startsWith('https://')) {
      controller.text = clipText;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.competitionDownloadUrl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: l10n.competitionDownloadUrlHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.competitionDownloadUrlHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.competitionDownload),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || input.trim().isEmpty || !mounted) return;

    _snack(l10n.competitionDownloading);
    final result = await CompetitionTaskDownloader.download(input);
    if (!mounted) return;
    if (result.ok) {
      await _store.setTask(result.task!);
      if (mounted) _snack(l10n.competitionImported);
    } else {
      _snack(_downloadErrorText(l10n, result.error!));
    }
  }

  String _downloadErrorText(AppLocalizations l10n, TaskDownloadError error) {
    switch (error) {
      case TaskDownloadError.invalidUrl:
        return l10n.competitionDownloadInvalidUrl;
      case TaskDownloadError.blockedHost:
        return l10n.competitionDownloadBlocked;
      case TaskDownloadError.tooLarge:
        return l10n.competitionDownloadTooLarge;
      case TaskDownloadError.notATask:
        return l10n.competitionImportFailed;
      case TaskDownloadError.network:
        return l10n.competitionDownloadFailed;
    }
  }

  Future<void> _showQr(AppLocalizations l10n) async {
    final task = _store.task;
    if (task == null) return;
    await showCompetitionTaskQr(context, task);
  }

  Future<void> _importFromFile(AppLocalizations l10n) async {
    try {
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.competitionImportFile,
        type: isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: isAndroid ? null : [CompetitionTaskIO.extension],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      final path = file.path;
      final task = bytes != null
          ? CompetitionTaskIO.instance.parseBytes(bytes)
          : path != null
              ? await CompetitionTaskIO.instance.importFile(path)
              : null;
      if (!mounted) return;
      if (task == null) {
        _snack(l10n.competitionImportFailed);
        return;
      }
      await _store.setTask(task);
      if (mounted) _snack(l10n.competitionImported);
    } catch (_) {
      if (mounted) _snack(l10n.competitionImportFailed);
    }
  }

  Future<void> _importFromCode(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trim().startsWith('XCTSK:')) {
      controller.text = clip.text!.trim();
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.competitionImportCode),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 3,
          decoration: InputDecoration(
            hintText: l10n.competitionImportCodeHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.competitionImport),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    final task = CompetitionTask.tryParse(text);
    if (task == null) {
      _snack(l10n.competitionImportFailed);
      return;
    }
    await _store.setTask(task);
    if (mounted) _snack(l10n.competitionImported);
  }

  Future<void> _exportFile(AppLocalizations l10n) async {
    final task = _store.task;
    if (task == null) return;
    try {
      await CompetitionTaskIO.instance.exportAndShare(task);
    } catch (_) {
      if (mounted) _snack(l10n.competitionExportFailed);
    }
  }

  Future<void> _copyCode(AppLocalizations l10n) async {
    final task = _store.task;
    if (task == null) return;
    await Clipboard.setData(ClipboardData(text: task.toTaskCode()));
    if (mounted) _snack(l10n.competitionCodeCopied);
  }

  Future<void> _confirmClear(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.competitionClearTask),
        content: Text(l10n.competitionClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.competitionClearTask),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.clear();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Owns the controller for the waypoint-name dialog so it stays alive for the
/// full route transition and is disposed with its TextField subtree.
class _CompetitionTextEntryDialog extends StatefulWidget {
  const _CompetitionTextEntryDialog({
    required this.title,
    required this.initial,
    required this.l10n,
  });

  final String title;
  final String initial;
  final AppLocalizations l10n;

  @override
  State<_CompetitionTextEntryDialog> createState() =>
      _CompetitionTextEntryDialogState();
}

class _CompetitionTextEntryDialogState
    extends State<_CompetitionTextEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.l10n.save),
        ),
      ],
    );
  }
}

/// Owns the radius field controller for the full lifetime of its dialog route.
class _CompetitionRadiusDialog extends StatefulWidget {
  const _CompetitionRadiusDialog({
    required this.initial,
    required this.l10n,
  });

  final double initial;
  final AppLocalizations l10n;

  @override
  State<_CompetitionRadiusDialog> createState() =>
      _CompetitionRadiusDialogState();
}

class _CompetitionRadiusDialogState extends State<_CompetitionRadiusDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial.round().toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.competitionEditRadius),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.competitionRadius,
          suffixText: 'm',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(_controller.text.trim());
            if (value == null || value < 1 || value > 200000) {
              setState(() => _error = l10n.competitionInvalidRadius);
              return;
            }
            Navigator.of(context).pop(value);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _TurnpointTile extends StatelessWidget {
  const _TurnpointTile({
    super.key,
    required this.index,
    required this.turnpoint,
    required this.l10n,
    required this.onEdit,
    required this.onDelete,
    required this.onRole,
  });

  final int index;
  final Turnpoint turnpoint;
  final AppLocalizations l10n;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<TurnpointRole> onRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: CircleAvatar(
          radius: 15,
          backgroundColor: _roleColor(theme, turnpoint.role),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                turnpoint.name.isEmpty
                    ? l10n.competitionTurnpointShort(index + 1)
                    : turnpoint.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (turnpoint.role != TurnpointRole.turnpoint) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _roleShort(l10n, turnpoint.role),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${turnpoint.radiusMeters.round()} m · '
          '${turnpoint.latitude.toStringAsFixed(4)}, ${turnpoint.longitude.toStringAsFixed(4)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<TurnpointRole>(
              icon: const Icon(Icons.label_outline),
              tooltip: l10n.competitionSetRole,
              onSelected: onRole,
              itemBuilder: (context) => [
                for (final role in TurnpointRole.values)
                  PopupMenuItem(value: role, child: Text(_roleName(l10n, role))),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  Color _roleColor(ThemeData theme, TurnpointRole role) {
    switch (role) {
      case TurnpointRole.takeoff:
        return const Color(0xFF43A047);
      case TurnpointRole.sss:
        return const Color(0xFF1E88E5);
      case TurnpointRole.ess:
        return const Color(0xFFF4511E);
      case TurnpointRole.turnpoint:
        return theme.colorScheme.primary;
    }
  }

  String _roleName(AppLocalizations l10n, TurnpointRole role) {
    switch (role) {
      case TurnpointRole.takeoff:
        return l10n.competitionRoleTakeoff;
      case TurnpointRole.sss:
        return l10n.competitionRoleSss;
      case TurnpointRole.ess:
        return l10n.competitionRoleEss;
      case TurnpointRole.turnpoint:
        return l10n.competitionRoleTurnpoint;
    }
  }

  String _roleShort(AppLocalizations l10n, TurnpointRole role) {
    switch (role) {
      case TurnpointRole.takeoff:
        return l10n.competitionRoleTakeoff;
      case TurnpointRole.sss:
        return 'SSS';
      case TurnpointRole.ess:
        return 'ESS';
      case TurnpointRole.turnpoint:
        return l10n.competitionRoleTurnpoint;
    }
  }
}
