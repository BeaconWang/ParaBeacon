import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/flight_aircraft_editor.dart';
import '../data/equipment_store.dart';
import '../data/flight_derived_stats.dart';
import '../data/flight_export_service.dart';
import '../data/flight_library_io.dart';
import '../data/flight_recorder.dart';
import '../data/flight_report_service.dart';
import '../data/flight_share_card_service.dart';
import '../data/geo_name_settings.dart';
import '../data/igc_import_service.dart';
import '../data/reverse_geocoder_service.dart';
import '../l10n/app_localizations.dart';
import 'flight_replay_sheet.dart';
import 'flight_statistics_sheet.dart';
import 'track_3d_sheet.dart';

/// Where imported flights come from (see [_FlightsSheetState._showImportMenu]).
enum _ImportSource {
  /// A `.pbflights` library bundle exported by this app.
  library,

  /// A folder of XCTrack `.igc` tracklogs.
  xcTrackFolder,
}

/// How the user selects XCTrack `.igc` tracklogs on Android (see
/// [_FlightsSheetState._importXcTrackAndroid]).
enum _IgcPickMode {
  /// Grant access to a whole folder (no file-count limit).
  folder,

  /// Multi-select individual files (capped at ~1000 by the system picker).
  files,
}

/// Opens the Flights screen (all recorded flights) as a full-screen sheet.
Future<void> showFlightsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Background driven by the theme's bottomSheetTheme (see other sheets).
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (context) => const _FlightsSheet(),
  );
}

class _FlightsSheet extends StatefulWidget {
  const _FlightsSheet();

  @override
  State<_FlightsSheet> createState() => _FlightsSheetState();
}

class _FlightsSheetState extends State<_FlightsSheet> {
  final FlightRecorder _recorder = FlightRecorder.instance;
  final Set<FlightTrack> _selectedTracks = <FlightTrack>{};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _recorder.addListener(_onChanged);
    // Prime the equipment defaults and geo settings for the editors/actions.
    EquipmentStore.instance.load();
    GeoNameSettings.instance.load();
  }

  @override
  void dispose() {
    _recorder.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tracks = _recorder.tracks;

    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header.
            _buildHeader(theme, tracks),
            const Divider(height: 1),
            Expanded(
              child: tracks.isEmpty
                  ? _empty(theme)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: tracks.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _trackTile(theme, tracks[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the header. When the action buttons don't fit next to the title
  /// on a single row, they wrap onto a second row below the title.
  Widget _buildHeader(ThemeData theme, List<FlightTrack> tracks) {
    final actions = _headerActions(tracks);
    // Compact IconButtons use a 40px target width.
    const buttonWidth = 40.0;

    final titleText = _selectionMode
        ? '${AppLocalizations.of(context).flights} (${_selectedTracks.length})'
        : AppLocalizations.of(context).flights;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actionsWidth = actions.length * buttonWidth;
          // Measure the actual title width so the row only wraps when the
          // title and buttons would genuinely collide, instead of reserving
          // a fixed amount that leaves a large gap in the middle.
          final titlePainter = TextPainter(
            text: TextSpan(text: titleText, style: theme.textTheme.titleLarge),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          // Leading icon (24) + gap (10) + title + actions.
          final needed = 24 + 10 + titlePainter.width + actionsWidth;
          final fitsOnOneRow = needed <= constraints.maxWidth;

          final titleRow = Row(
            children: [
              Icon(
                _selectionMode ? Icons.checklist : Icons.route,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titleText,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (fitsOnOneRow) ...actions,
            ],
          );

          if (fitsOnOneRow) return titleRow;

          // Not enough room: title on the first row, buttons wrapped below.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(alignment: WrapAlignment.end, children: actions),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The set of header action buttons, in display order.
  List<Widget> _headerActions(List<FlightTrack> tracks) {
    final l10n = AppLocalizations.of(context);
    if (_selectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.insights_outlined),
          tooltip: l10n.flightsStatisticsSelected,
          onPressed: _selectedTracks.isEmpty
              ? null
              : () => _showStatistics(_selectedTracks.toList(), selected: true),
        ),
        IconButton(
          icon: const Icon(Icons.file_upload_outlined),
          tooltip: l10n.flightsExportSelected,
          onPressed: _selectedTracks.isEmpty
              ? null
              : () => _exportLibrary(_selectedTracks.toList()),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: _leaveSelectionMode,
        ),
      ];
    }
    return [
      // DEBUG ONLY — inject a random flight record for testing.
      if (kDebugMode)
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: l10n.flightsAddRandomDebug,
          onPressed: () => _recorder.addRandomDebugTrack(),
        ),
      IconButton(
        icon: const Icon(Icons.file_download_outlined),
        tooltip: l10n.flightsImport,
        onPressed: _showImportMenu,
      ),
      if (tracks.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.insights_outlined),
          tooltip: l10n.flightsStatisticsAll,
          onPressed: () => _showStatistics(tracks, selected: false),
        ),
      if (tracks.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.file_upload_outlined),
          tooltip: l10n.flightsExportLibrary,
          onPressed: () => _exportLibrary(tracks),
        ),
      if (tracks.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: l10n.flightsClearAll,
          onPressed: _confirmClearAll,
        ),
      IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.close,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }

  Widget _empty(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.route_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.flightsNoneRecorded,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.flightsStartToRecord,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Enters selection mode from a long-press and selects [track].
  void _enterSelectionModeWith(FlightTrack track) {
    if (_selectionMode) {
      _toggleTrackSelection(track);
      return;
    }
    setState(() {
      _selectionMode = true;
      _selectedTracks
        ..clear()
        ..add(track);
    });
  }

  void _leaveSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedTracks.clear();
    });
  }

  void _toggleTrackSelection(FlightTrack track) {
    setState(() {
      if (!_selectedTracks.add(track)) _selectedTracks.remove(track);
    });
  }

  Widget _trackTile(ThemeData theme, FlightTrack track) {
    final l10n = AppLocalizations.of(context);
    final canReplay = track.samples.length >= 2;
    final selected = _selectedTracks.contains(track);
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 0),
      leading: _selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (_) => _toggleTrackSelection(track),
            )
          : CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.flight,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _fmtDateTime(track.startTime),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (track.isAutoFlight) ...[
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  l10n.flightButtonAuto,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        l10n.flightsListSubtitle(
          _fmtDuration(track.duration),
          (track.distanceM / 1000).toStringAsFixed(2),
          track.pointCount,
        ),
      ),
      trailing: _selectionMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: canReplay
                      ? l10n.flightsReplay
                      : l10n.flightsNoPointsToReplay,
                  onPressed: canReplay ? () => _replay(track) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.threed_rotation),
                  tooltip: canReplay
                      ? l10n.flights3dReplay
                      : l10n.flightsNoPointsToReplay,
                  onPressed: canReplay ? () => _replay3D(track) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.delete,
                  onPressed: () => _confirmDeleteTrack(track),
                ),
              ],
            ),
      selected: _selectionMode && selected,
      onTap: _selectionMode
          ? () => _toggleTrackSelection(track)
          : () => _showDetail(track),
      onLongPress: () => _enterSelectionModeWith(track),
    );
  }

  void _replay(FlightTrack track) {
    showFlightReplaySheet(context, track);
  }

  void _replay3D(FlightTrack track) {
    showTrack3DSheet(context, track);
  }

  void _showStatistics(List<FlightTrack> tracks, {required bool selected}) {
    if (tracks.isEmpty) return;
    showFlightStatisticsSheet(context, tracks: tracks, selected: selected);
  }

  // ── Share card ─────────────────────────────────────────────────────────

  Future<void> _saveShareCard(FlightTrack track) async {
    final l10n = AppLocalizations.of(context);
    try {
      final saved = await FlightShareCardService.instance.saveToGallery(
        track,
        l10n,
      );
      _snack(
        saved ? l10n.flightsShareCardSaved : l10n.flightsShareCardSharedFile,
      );
    } catch (e) {
      _snack(l10n.flightsShareCardFailed('$e'));
    }
  }

  // ── Reverse-geocoded site names ──────────────────────────────────────────

  Future<void> _resolveSites(FlightTrack track) async {
    final l10n = AppLocalizations.of(context);
    await GeoNameSettings.instance.load();
    if (!GeoNameSettings.instance.isConfigured) {
      _snack(l10n.flightsSetAmapKeyFirst);
      return;
    }
    final fixes = track.samples.where((s) => s.data.hasFix).toList();
    if (fixes.length < 2) {
      _snack(l10n.flightsNoPointsToLocate);
      return;
    }
    _snack(l10n.flightsLookingUpSites);
    try {
      final takeoff = await ReverseGeocoderService.instance.tryLookup(
        fixes.first.data.latitude,
        fixes.first.data.longitude,
      );
      final landing = await ReverseGeocoderService.instance.tryLookup(
        fixes.last.data.latitude,
        fixes.last.data.longitude,
      );
      if (takeoff != null) track.takeoffSite = takeoff;
      if (landing != null) track.landingSite = landing;
      _recorder.persistTrackMeta(track);
      _snack(
        takeoff == null && landing == null
            ? l10n.flightsNoPlaceNames
            : l10n.flightsSiteNamesUpdated,
      );
    } catch (e) {
      _snack(l10n.flightsLookupFailed('$e'));
    }
  }

  // ── Equipment editor ─────────────────────────────────────────────────────

  Future<void> _editEquipment(FlightTrack track) async {
    await EquipmentStore.instance.load();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final glider = TextEditingController(
      text: track.gliderName ?? EquipmentStore.instance.glider ?? '',
    );
    final harness = TextEditingController(
      text: track.harnessName ?? EquipmentStore.instance.harness ?? '',
    );
    final helmet = TextEditingController(
      text: track.helmetName ?? EquipmentStore.instance.helmet ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.equipment),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: glider,
                decoration: InputDecoration(labelText: l10n.equipmentGlider),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: harness,
                decoration: InputDecoration(labelText: l10n.equipmentHarness),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: helmet,
                decoration: InputDecoration(labelText: l10n.equipmentHelmet),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved != true) return;
    String? norm(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    track.gliderName = norm(glider);
    track.harnessName = norm(harness);
    track.helmetName = norm(helmet);
    _recorder.persistTrackMeta(track);
    // Remember as defaults for the next flight.
    await EquipmentStore.instance.remember(
      glider: track.gliderName,
      harness: track.harnessName,
      helmet: track.helmetName,
    );
  }

  Future<void> _editAircraft(FlightTrack track) async {
    final draft = await showFlightAircraftEditor(context, track);
    if (!mounted || draft == null) return;

    String? normalize(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    track
      ..aircraftFaiClass = draft.faiClass
      ..aircraftManufacturer = normalize(draft.manufacturer)
      ..aircraftModel = normalize(draft.model)
      ..aircraftName = normalize(draft.name)
      ..aircraftCategory = normalize(draft.category)
      ..aircraftTandem = draft.tandem
      ..aircraftEngineType = draft.engineType
      ..aircraftTrimSpeedKmh = draft.trimSpeedKmh
      ..aircraftGoalGlideRatio = draft.goalGlideRatio;
    _recorder.persistTrackMeta(track);
  }

  // ── Per-flight export ──────────────────────────────────────────────────

  Future<void> _exportGpx(FlightTrack track) =>
      _runExport(() => FlightExportService.instance.shareGpx(track), 'GPX');

  Future<void> _exportIgc(FlightTrack track) =>
      _runExport(() => FlightExportService.instance.shareIgc(track), 'IGC');

  Future<void> _exportPdf(FlightTrack track) {
    final l10n = AppLocalizations.of(context);
    return _runExport(
      () => FlightReportService.instance.sharePdf(track, l10n),
      'PDF',
    );
  }

  Future<void> _runExport(
    Future<String> Function() action,
    String label,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      _snack(l10n.flightsExportFailed(label, '$e'));
    }
  }

  // ── Library import / export ────────────────────────────────────────────

  /// Presents the import-source chooser: a `.pbflights` bundle, or a folder of
  /// XCTrack `.igc` tracklogs.
  Future<void> _showImportMenu() async {
    final l10n = AppLocalizations.of(context);
    // The note explains the Android-only tracklog location / copy-to-Download
    // workaround, so only surface it on Android.
    final showNote = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final choice = await showModalBottomSheet<_ImportSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: Text(l10n.flightsImportLibrary),
              onTap: () => Navigator.of(context).pop(_ImportSource.library),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.flightsImportXcTrack),
              subtitle: showNote ? Text(l10n.flightsImportXcTrackNote) : null,
              isThreeLine: showNote,
              onTap: () =>
                  Navigator.of(context).pop(_ImportSource.xcTrackFolder),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _ImportSource.library:
        await _importLibrary();
      case _ImportSource.xcTrackFolder:
        await _importXcTrackFolder();
    }
  }

  /// Imports XCTrack `.igc` tracklogs.
  ///
  ///  * **Android** — the user first chooses how to select: a *folder* (via the
  ///    Storage Access Framework; the native side reads every `.igc` inside it
  ///    with no file-count limit) or individual *files* (multi-select, capped
  ///    at ~1000 by the system picker).
  ///  * **iOS** — the pilot selects the `.igc` files (the picker returns
  ///    readable bytes).
  ///  * **Desktop** — a picked folder is readable through `dart:io`, so the
  ///    whole directory is scanned.
  Future<void> _importXcTrackFolder() async {
    final l10n = AppLocalizations.of(context);
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    try {
      final FlightImportResult? result;
      if (isAndroid) {
        final mode = await _chooseIgcPickMode(l10n);
        if (mode == null || !mounted) return; // cancelled
        result = mode == _IgcPickMode.folder
            ? await _importXcTrackAndroidFolder(l10n)
            : await _importXcTrackFiles(l10n);
      } else if (isIos) {
        result = await _importXcTrackFiles(l10n);
      } else {
        result = await _importXcTrackDirectory(l10n);
      }
      if (!mounted || result == null) return;
      if (result.total == 0) {
        _snack(l10n.flightsImportNoIgc);
        return;
      }
      _snack(
        result.failed > 0
            ? l10n.flightsImportResultFailed(
                result.added,
                result.skipped,
                result.failed,
              )
            : l10n.flightsImportResult(result.added, result.skipped),
      );
    } catch (e) {
      if (mounted) _snack(l10n.flightsImportFailed('$e'));
    }
  }

  /// Android: asks whether to select a folder or individual files.
  Future<_IgcPickMode?> _chooseIgcPickMode(AppLocalizations l10n) {
    return showModalBottomSheet<_IgcPickMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.flightsImportXcTrackPickMode,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.flightsImportModeFolder),
              subtitle: Text(l10n.flightsImportModeFolderNote),
              onTap: () => Navigator.of(context).pop(_IgcPickMode.folder),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(l10n.flightsImportModeFiles),
              subtitle: Text(l10n.flightsImportModeFilesNote),
              onTap: () => Navigator.of(context).pop(_IgcPickMode.files),
            ),
          ],
        ),
      ),
    );
  }

  /// Android path: pick a folder via SAF and import every `.igc` in it
  /// (recursively), with no file-count limit.
  Future<FlightImportResult?> _importXcTrackAndroidFolder(
    AppLocalizations l10n,
  ) async {
    final result = await IgcImportService.instance.importAndroidFolder();
    // Surface the "importing" hint only once a folder was actually chosen.
    if (result != null && result.total > 0 && mounted) {
      _snack(l10n.flightsImportingXcTrack);
    }
    return result;
  }

  /// Pick one or more `.igc` files and import their bytes (iOS, or Android when
  /// the user chose file-selection mode).
  Future<FlightImportResult?> _importXcTrackFiles(AppLocalizations l10n) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.flightsImportXcTrack,
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );
    final files = picked?.files;
    if (files == null || files.isEmpty || !mounted) return null;
    final contents = <List<int>>[];
    for (final f in files) {
      final name = f.name.toLowerCase();
      if (!name.endsWith('.${IgcImportService.extension}')) continue;
      final bytes = f.bytes;
      if (bytes != null) contents.add(bytes);
    }
    if (contents.isEmpty) {
      _snack(l10n.flightsImportNoIgc);
      return null;
    }
    _snack(l10n.flightsImportingXcTrack);
    return IgcImportService.instance.importContents(contents);
  }

  /// Desktop path: pick a folder and scan it recursively for `.igc` files.
  Future<FlightImportResult?> _importXcTrackDirectory(
    AppLocalizations l10n,
  ) async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.flightsImportXcTrack,
    );
    if (dirPath == null || !mounted) return null;
    _snack(l10n.flightsImportingXcTrack);
    return IgcImportService.instance.importDirectory(dirPath);
  }

  Future<void> _exportLibrary(List<FlightTrack> tracks) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FlightLibraryIO.instance.exportAndShare(tracks);
      if (result == null) return;
      if (_selectionMode) _leaveSelectionMode();
      await _showExportResultDialog(result);
    } catch (e) {
      _snack(l10n.flightsLibraryExportFailed('$e'));
    }
  }

  Future<void> _showExportResultDialog(FlightExportResult result) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          icon: Icon(
            Icons.check_circle_outline,
            color: theme.colorScheme.primary,
          ),
          title: Text(l10n.flightsExportDoneTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.savedToDevice
                    ? l10n.flightsExportDoneSaved
                    : l10n.flightsExportDoneShared,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _exportDetailRow(
                theme,
                l10n.flightsExportDetailFlights,
                '${result.flightCount}',
              ),
              _exportDetailRow(
                theme,
                l10n.flightsExportDetailFileName,
                result.fileName,
              ),
              _exportDetailRow(
                theme,
                l10n.flightsExportDetailSize,
                _formatBytes(result.byteSize),
              ),
              if (result.savedToDevice && result.destination != null)
                _exportDetailRow(
                  theme,
                  l10n.flightsExportDetailLocation,
                  _describeDestination(result.destination!),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Widget _exportDetailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  /// Presents a readable destination for an Android document URI, falling back
  /// to the raw value when it is not a recognizable path.
  String _describeDestination(String destination) {
    if (destination.contains('ParaBeacon')) {
      return 'Downloads/ParaBeacon';
    }
    final decoded = Uri.decodeFull(destination);
    final marker = decoded.lastIndexOf('/');
    if (marker >= 0 && marker < decoded.length - 1) {
      return decoded.substring(marker + 1);
    }
    return decoded;
  }

  Future<void> _importLibrary() async {
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [FlightLibraryIO.extension, 'zip'],
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      final result = await FlightLibraryIO.instance.importFile(path);
      _snack(
        result.failed > 0
            ? l10n.flightsImportResultFailed(
                result.added,
                result.skipped,
                result.failed,
              )
            : l10n.flightsImportResult(result.added, result.skipped),
      );
    } catch (e) {
      _snack(l10n.flightsImportFailed('$e'));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showDetail(FlightTrack track) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final stats = FlightDerivedStats.compute(track);
            final maxAltGainM = track.maxAltGainM;
            final elevationDropM = track.elevationDropM;
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(l10n.flightDetailsTitle),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    if (track.hasSamples)
                      IconButton(
                        icon: const Icon(Icons.data_array),
                        tooltip: l10n.flightDetailDeleteSamples,
                        color: theme.colorScheme.error,
                        onPressed: () async {
                          final confirmed = await _confirmDeleteSamples();
                          if (confirmed != true) return;
                          _recorder.deleteTrackSamples(track);
                          setDialogState(() {});
                        },
                      ),
                    if (track.samples.length > 2)
                      IconButton(
                        icon: const Icon(Icons.content_cut),
                        tooltip: l10n.flightDetailTrimLog,
                        color: theme.colorScheme.primary,
                        onPressed: () async {
                          final range = await _chooseTrimRange(track);
                          if (range == null) return;
                          _recorder.trimTrackSamples(
                            track,
                            startIndex: range.start.round(),
                            endIndex: range.end.round(),
                          );
                          setDialogState(() {});
                        },
                      ),
                    if (track.hasSamples)
                      IconButton(
                        icon: const Icon(Icons.threed_rotation),
                        tooltip: l10n.flights3dReplay,
                        color: theme.colorScheme.primary,
                        onPressed: () {
                          Navigator.of(context).pop();
                          _replay3D(track);
                        },
                      ),
                    if (track.samples.length >= 2)
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        tooltip: l10n.flightsReplay,
                        color: theme.colorScheme.primary,
                        onPressed: () {
                          Navigator.of(context).pop();
                          _replay(track);
                        },
                      ),
                  ],
                ),
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _sectionLabel(theme, l10n.flightDetailFlight),
                        _detailRow(
                          l10n.flightDetailStart,
                          _fmtDateTime(track.firstRecordedTime),
                        ),
                        _detailRow(
                          l10n.flightDetailEnd,
                          track.endTime != null
                              ? _fmtDateTime(track.lastRecordedTime)
                              : '—',
                        ),
                        _detailRow(
                          l10n.flightDetailDuration,
                          _fmtDuration(track.duration),
                        ),
                        _detailRow(
                          l10n.flightDetailSamples,
                          '${track.pointCount}',
                        ),
                        if (track.pilotName?.isNotEmpty ?? false)
                          _detailRow(l10n.flightDetailPilot, track.pilotName!),
                        const SizedBox(height: 8),
                        _sectionLabel(theme, l10n.flightDetailRoute),
                        _detailRow(
                          l10n.flightDetailDistance,
                          '${(track.distanceM / 1000).toStringAsFixed(2)} km',
                        ),
                        ...() {
                          final takeoff = _endpointText(
                            track.takeoffSite,
                            track.takeoffLatitude,
                            track.takeoffLongitude,
                            track.takeoffAltitude,
                          );
                          final landing = _endpointText(
                            track.landingSite,
                            track.landingLatitude,
                            track.landingLongitude,
                            track.landingAltitude,
                          );
                          return [
                            if (takeoff != null)
                              _detailRow(l10n.flightDetailTakeoff, takeoff),
                            if (landing != null)
                              _detailRow(l10n.flightDetailLanding, landing),
                          ];
                        }(),
                        const SizedBox(height: 8),
                        _sectionLabel(theme, l10n.flightDetailAltitude),
                        _detailRow(
                          l10n.flightDetailMaxAltitude,
                          '${track.maxAltitude.toStringAsFixed(0)} m',
                        ),
                        _detailRow(
                          l10n.flightDetailMinAltitude,
                          '${track.minAltitude.toStringAsFixed(0)} m',
                        ),
                        _detailRow(
                          l10n.flightDetailMaxClimb,
                          '${track.maxClimb.toStringAsFixed(1)} m/s',
                        ),
                        _detailRow(
                          l10n.flightDetailMaxSink,
                          '${track.maxSink.toStringAsFixed(1)} m/s',
                        ),
                        const SizedBox(height: 8),
                        _sectionLabel(theme, l10n.flightDetailAircraft),
                        if (track.hasAircraftInformation) ...[
                          if (track.aircraftFaiClass?.isNotEmpty ?? false)
                            _detailRow(
                              l10n.flightDetailAircraftClass,
                              track.aircraftFaiClass!,
                            ),
                          if (track.aircraftManufacturer?.isNotEmpty ?? false)
                            _detailRow(
                              l10n.flightDetailAircraftManufacturer,
                              track.aircraftManufacturer!,
                            ),
                          if (track.aircraftModel?.isNotEmpty ?? false)
                            _detailRow(
                              l10n.flightDetailAircraftModel,
                              track.aircraftModel!,
                            ),
                          if (track.aircraftName?.isNotEmpty ?? false)
                            _detailRow(
                              l10n.flightDetailAircraftName,
                              track.aircraftName!,
                            ),
                          if (track.aircraftCategory?.isNotEmpty ?? false)
                            _detailRow(
                              l10n.flightDetailAircraftCategory,
                              track.aircraftCategory!,
                            ),
                          if (track.aircraftTandem != null)
                            _detailRow(
                              l10n.flightDetailAircraftTandem,
                              track.aircraftTandem!
                                  ? l10n.aircraftTandemYes
                                  : l10n.aircraftTandemNo,
                            ),
                          if (track.aircraftEngineType?.isNotEmpty ?? false)
                            _detailRow(
                              l10n.flightDetailAircraftEngine,
                              track.aircraftEngineType!,
                            ),
                          if (track.aircraftTrimSpeedKmh != null)
                            _detailRow(
                              l10n.flightDetailAircraftTrimSpeed,
                              '${track.aircraftTrimSpeedKmh!.toStringAsFixed(1)} km/h',
                            ),
                          if (track.aircraftGoalGlideRatio != null)
                            _detailRow(
                              l10n.flightDetailAircraftGlideRatio,
                              track.aircraftGoalGlideRatio!.toStringAsFixed(2),
                            ),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              await _editAircraft(track);
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(l10n.flightDetailAircraftEdit),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _sectionLabel(theme, l10n.equipment),
                        if (track.hasEquipment) ...[
                          if (track.gliderName?.isNotEmpty ?? false)
                            _detailRow(l10n.equipmentGlider, track.gliderName!),
                          if (track.harnessName?.isNotEmpty ?? false)
                            _detailRow(
                              l10n.equipmentHarness,
                              track.harnessName!,
                            ),
                          if (track.helmetName?.isNotEmpty ?? false)
                            _detailRow(l10n.equipmentHelmet, track.helmetName!),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              await _editEquipment(track);
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(
                              track.hasEquipment
                                  ? l10n.equipmentEdit
                                  : l10n.equipmentAdd,
                            ),
                          ),
                        ),
                        if (track.hasSamples) ...[
                          const SizedBox(height: 8),
                          _sectionLabel(theme, l10n.flightDetailPerformance),
                          _sectionLabel(theme, l10n.flightDetailRouteMetrics),
                          _detailRow(
                            l10n.flightDetailStraightDistance,
                            '${(stats.straightDistanceM / 1000).toStringAsFixed(2)} km',
                          ),
                          if (stats.threeTurnpointM > 0)
                            _detailRow(
                              l10n.flightDetailThreeTurnpoints,
                              _routeText(
                                stats.threeTurnpointM,
                                stats.threeTurnpointLegsM,
                              ),
                            ),
                          if (stats.faiTriangleM > 0)
                            _detailRow(
                              l10n.flightDetailFaiTriangle,
                              _triangleText(
                                l10n,
                                stats.faiTriangleM,
                                stats.faiTriangleLegsM,
                                stats.faiClosingM,
                                stats.faiClosed,
                              ),
                            ),
                          if (stats.flatTriangleM > 0)
                            _detailRow(
                              l10n.flightDetailFlatTriangle,
                              _triangleText(
                                l10n,
                                stats.flatTriangleM,
                                stats.flatTriangleLegsM,
                                stats.flatClosingM,
                                stats.flatClosed,
                              ),
                            ),
                          _detailRow(
                            l10n.flightDetailMaxFromStart,
                            '${(stats.maxDistanceFromStartM / 1000).toStringAsFixed(2)} km',
                          ),
                          _detailRow(
                            l10n.flightDetailTrackEfficiency,
                            '${(stats.trackEfficiency * 100).toStringAsFixed(0)} %',
                          ),
                          _sectionLabel(theme, l10n.flightDetailSpeedGlide),
                          _detailRow(
                            l10n.flightDetailAvgGroundSpeed,
                            '${stats.avgGroundSpeedKph.toStringAsFixed(1)} km/h',
                          ),
                          _detailRow(
                            l10n.flightDetailAvgCruiseSpeed,
                            '${stats.avgCruiseSpeedKph.toStringAsFixed(1)} km/h',
                          ),
                          _detailRow(
                            l10n.flightDetailMaxSpeed,
                            '${stats.maxSpeedKph.toStringAsFixed(1)} km/h',
                          ),
                          _detailRow(
                            l10n.flightDetailAvgGlideRatio,
                            stats.avgGlideRatio > 0
                                ? stats.avgGlideRatio.toStringAsFixed(1)
                                : '—',
                          ),
                          _sectionLabel(theme, l10n.flightDetailClimbAltitude),
                          _detailRow(
                            l10n.flightDetailAvgClimb,
                            '${stats.avgClimbMs.toStringAsFixed(1)} m/s',
                          ),
                          _detailRow(
                            l10n.flightDetailAvgSink,
                            '${stats.avgSinkMs.toStringAsFixed(1)} m/s',
                          ),
                          _detailRow(
                            l10n.flightDetailThermals,
                            '${stats.thermalCount}',
                          ),
                          _detailRow(
                            l10n.flightDetailAltGained,
                            '${stats.altitudeGainedM.toStringAsFixed(0)} m',
                          ),
                          _detailRow(
                            l10n.flightDetailAltLost,
                            '${stats.altitudeLostM.toStringAsFixed(0)} m',
                          ),
                          _detailRow(
                            l10n.flightDetailMaxAltGain,
                            '${(maxAltGainM ?? stats.maxAltGainM).toStringAsFixed(0)} m',
                          ),
                          _detailRow(
                            l10n.flightDetailElevationDrop,
                            '${(elevationDropM ?? stats.elevationDropM).toStringAsFixed(0)} m',
                          ),
                          _sectionLabel(theme, l10n.flightDetailTimeBreakdown),
                          _detailRow(
                            l10n.flightDetailClimbTime,
                            _fmtDuration(stats.climbTime),
                          ),
                          _detailRow(
                            l10n.flightDetailGlideTime,
                            _fmtDuration(stats.glideTime),
                          ),
                          _detailRow(
                            l10n.flightDetailSinkTime,
                            _fmtDuration(stats.sinkTime),
                          ),
                          _detailRow(
                            l10n.flightDetailMovingTime,
                            _fmtDuration(stats.movingTime),
                          ),
                          const SizedBox(height: 8),
                          _sectionLabel(theme, l10n.flightDetailExport),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _exportGpx(track),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('GPX'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _exportIgc(track),
                                icon: const Icon(
                                  Icons.description_outlined,
                                  size: 18,
                                ),
                                label: const Text('IGC'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _exportPdf(track),
                                icon: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 18,
                                ),
                                label: const Text('PDF'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _saveShareCard(track),
                                icon: const Icon(
                                  Icons.image_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.flightExportShareCard),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await _resolveSites(track);
                                  setDialogState(() {});
                                },
                                icon: const Icon(
                                  Icons.place_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.flightDetailSiteNames),
                              ),
                            ],
                          ),
                        ],
                        if (!track.hasSamples &&
                            (maxAltGainM != null ||
                                elevationDropM != null)) ...[
                          const SizedBox(height: 8),
                          _sectionLabel(theme, l10n.flightDetailAltitude),
                          if (maxAltGainM != null)
                            _detailRow(
                              l10n.flightDetailMaxAltGain,
                              '${maxAltGainM.toStringAsFixed(0)} m',
                            ),
                          if (elevationDropM != null)
                            _detailRow(
                              l10n.flightDetailElevationDrop,
                              '${elevationDropM.toStringAsFixed(0)} m',
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<RangeValues?> _chooseTrimRange(FlightTrack track) {
    final l10n = AppLocalizations.of(context);
    final maxIndex = track.samples.length - 1;
    var range = RangeValues(0, maxIndex.toDouble());
    return showDialog<RangeValues>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstIndex = range.start.round();
          final lastIndex = range.end.round();
          final keptCount = lastIndex - firstIndex + 1;
          final removedCount = track.samples.length - keptCount;
          return AlertDialog(
            title: Text(l10n.flightDetailTrimLog),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.flightDetailTrimDescription),
                const SizedBox(height: 16),
                Text(
                  l10n.flightDetailTrimFrom(
                    _fmtDateTime(track.samples[firstIndex].time),
                  ),
                ),
                RangeSlider(
                  values: range,
                  min: 0,
                  max: maxIndex.toDouble(),
                  labels: RangeLabels('${firstIndex + 1}', '${lastIndex + 1}'),
                  onChanged: (value) {
                    var nextStart = value.start.round().clamp(0, maxIndex);
                    var nextEnd = value.end.round().clamp(0, maxIndex);
                    if (nextEnd - nextStart < 1) {
                      final movingStart =
                          (value.start - range.start).abs() >
                          (value.end - range.end).abs();
                      if (movingStart) {
                        nextEnd = (nextStart + 1).clamp(1, maxIndex);
                        nextStart = nextEnd - 1;
                      } else {
                        nextStart = (nextEnd - 1).clamp(0, maxIndex - 1);
                        nextEnd = nextStart + 1;
                      }
                    }
                    setDialogState(() {
                      range = RangeValues(
                        nextStart.toDouble(),
                        nextEnd.toDouble(),
                      );
                    });
                  },
                ),
                Text(
                  l10n.flightDetailTrimThrough(
                    _fmtDateTime(track.samples[lastIndex].time),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.flightDetailTrimCounts(keptCount, removedCount)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: removedCount == 0
                    ? null
                    : () => Navigator.of(dialogContext).pop(range),
                child: Text(l10n.flightDetailTrimApply),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _confirmDeleteSamples() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.flightsDeleteSamplesTitle),
        content: Text(l10n.flightsDeleteSamplesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          const SizedBox(width: 16),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.flightsClearAllTitle),
        content: Text(l10n.flightsClearAllMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.flightsClearAll),
          ),
        ],
      ),
    );
    if (confirmed == true) _recorder.clearTracks();
  }

  Future<void> _confirmDeleteTrack(FlightTrack track) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.flightsDeleteTitle),
        content: Text(l10n.flightsDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) _recorder.deleteTrack(track);
  }

  static String _fmtDateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// Formats a lat/lon pair the way XCTrack shows launch/landing, e.g.
  /// `22.8311°N, 114.7010°E`. Returns null when either value is missing.
  static String? _fmtCoords(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}°$ns, '
        '${lon.abs().toStringAsFixed(4)}°$ew';
  }

  /// Formats a distance in km with two decimals.
  static String _km(double m) => '${(m / 1000).toStringAsFixed(2)} km';

  /// Formats a list of leg lengths as `a / b / c` using meters below 1 km and
  /// km above, keeping the row readable.
  static String _legsText(List<double> legsM) {
    String one(double m) =>
        m >= 1000 ? '${(m / 1000).toStringAsFixed(2)}km' : '${m.round()}m';
    return legsM.map(one).join(' / ');
  }

  /// A free-distance route row: total plus its legs.
  static String _routeText(double totalM, List<double> legsM) {
    final legs = legsM.isNotEmpty ? ' · ${_legsText(legsM)}' : '';
    return '${_km(totalM)}$legs';
  }

  /// A triangle row: scored distance, the three legs, the closing gap and a
  /// "closed" marker when the circuit closes tightly.
  static String _triangleText(
    AppLocalizations l10n,
    double totalM,
    List<double> legsM,
    double closingM,
    bool closed,
  ) {
    final legs = legsM.isNotEmpty ? ' · ${_legsText(legsM)}' : '';
    final closing = closingM > 0
        ? ' · ${l10n.flightDetailClosing} ${closingM.round()} m'
        : '';
    final mark = closed ? ' (${l10n.flightDetailFaiClosed})' : '';
    return '${_km(totalM)}$legs$closing$mark';
  }

  /// Combines an optional site name with its coordinates and altitude for a
  /// launch/landing detail row. Returns a string like
  /// `Site (22.8311°N, 114.7010°E · 300 m)`, degrading gracefully when parts
  /// are missing, or null when nothing is known.
  static String? _endpointText(
    String? site,
    double? lat,
    double? lon,
    double? altitude,
  ) {
    final hasSite = site != null && site.isNotEmpty;
    final coords = _fmtCoords(lat, lon);
    final parts = <String>[];
    if (coords != null) parts.add(coords);
    if (altitude != null) parts.add('${altitude.round()} m');
    final detail = parts.join(' · ');
    if (hasSite && detail.isNotEmpty) return '$site ($detail)';
    if (hasSite) return site;
    return detail.isNotEmpty ? detail : null;
  }
}
