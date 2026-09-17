import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/equipment_store.dart';
import '../data/flight_derived_stats.dart';
import '../data/flight_export_service.dart';
import '../data/flight_library_io.dart';
import '../data/flight_recorder.dart';
import '../data/flight_report_service.dart';
import '../data/flight_share_card_service.dart';
import '../data/geo_name_settings.dart';
import '../data/reverse_geocoder_service.dart';
import '../l10n/app_localizations.dart';
import 'flight_replay_sheet.dart';

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

    return SafeArea(
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
    );
  }

  /// Builds the header. When the action buttons don't fit next to the title
  /// on a single row, they wrap onto a second row below the title.
  Widget _buildHeader(ThemeData theme, List<FlightTrack> tracks) {
    final actions = _headerActions(tracks);
    // Approximate width of a single IconButton (48px default touch target).
    const buttonWidth = 48.0;
    // Minimum width we want to reserve for the title before wrapping.
    const minTitleWidth = 120.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actionsWidth = actions.length * buttonWidth;
          // Leading icon (24) + gap (10) + title + actions.
          final needed = 24 + 10 + minTitleWidth + actionsWidth;
          final fitsOnOneRow = needed <= constraints.maxWidth;

          final titleRow = Row(
            children: [
              Icon(Icons.route, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(AppLocalizations.of(context).flights,
                    style: theme.textTheme.titleLarge),
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
                child: Wrap(
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
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
        tooltip: l10n.flightsImportLibrary,
        onPressed: _importLibrary,
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
        icon: const Icon(Icons.travel_explore),
        tooltip: l10n.flightsPlaceNameSettings,
        onPressed: _openGeoSettings,
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
          Icon(Icons.route_outlined,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(l10n.flightsNoneRecorded,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
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

  Widget _trackTile(ThemeData theme, FlightTrack track) {
    final l10n = AppLocalizations.of(context);
    final canReplay = track.samples.length >= 2;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.flight, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(_fmtDateTime(track.startTime)),
      subtitle: Text(
        l10n.flightsListSubtitle(
          _fmtDuration(track.duration),
          (track.distanceM / 1000).toStringAsFixed(2),
          track.pointCount,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip:
                canReplay ? l10n.flightsReplay : l10n.flightsNoPointsToReplay,
            onPressed: canReplay ? () => _replay(track) : null,
          ),
          IconButton(
            icon: const Icon(Icons.threed_rotation),
            tooltip:
                canReplay ? l10n.flights3dReplay : l10n.flightsNoPointsToReplay,
            onPressed: canReplay ? () => _replay3D(track) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => _recorder.deleteTrack(track),
          ),
        ],
      ),
      onTap: () => _showDetail(track),
    );
  }

  void _replay(FlightTrack track) {
    showFlightReplaySheet(context, track);
  }

  void _replay3D(FlightTrack track) {
    showFlightReplaySheet(context, track, initial3D: true);
  }

  // ── Share card ─────────────────────────────────────────────────────────

  Future<void> _saveShareCard(FlightTrack track) async {
    final l10n = AppLocalizations.of(context);
    try {
      final saved =
          await FlightShareCardService.instance.saveToGallery(track);
      _snack(saved
          ? l10n.flightsShareCardSaved
          : l10n.flightsShareCardSharedFile);
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
      final takeoff = await ReverseGeocoderService.instance
          .tryLookup(fixes.first.data.latitude, fixes.first.data.longitude);
      final landing = await ReverseGeocoderService.instance
          .tryLookup(fixes.last.data.latitude, fixes.last.data.longitude);
      if (takeoff != null) track.takeoffSite = takeoff;
      if (landing != null) track.landingSite = landing;
      _recorder.persistTrackMeta(track);
      _snack(takeoff == null && landing == null
          ? l10n.flightsNoPlaceNames
          : l10n.flightsSiteNamesUpdated);
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
        text: track.gliderName ?? EquipmentStore.instance.glider ?? '');
    final harness = TextEditingController(
        text: track.harnessName ?? EquipmentStore.instance.harness ?? '');
    final helmet = TextEditingController(
        text: track.helmetName ?? EquipmentStore.instance.helmet ?? '');

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

  // ── Place-name (reverse geocoding) settings ──────────────────────────────

  Future<void> _openGeoSettings() async {
    await GeoNameSettings.instance.load();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final settings = GeoNameSettings.instance;
    final keyCtrl = TextEditingController(text: settings.amapKey ?? '');
    var auto = settings.autoLookup;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text(l10n.placeNameLookup),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.placeNameLookupDescription),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.placeNameAmapKeyLabel,
                  ),
                  obscureText: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.placeNameAutoLookup),
                  value: auto,
                  onChanged: (v) => setInner(() => auto = v),
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
      ),
    );

    if (saved != true) return;
    final key = keyCtrl.text.trim();
    await settings.setAmapKey(key.isEmpty ? null : key);
    await settings.setAutoLookup(auto);
    _snack(l10n.placeNameSettingsSaved);
  }

  // ── Per-flight export ──────────────────────────────────────────────────

  Future<void> _exportGpx(FlightTrack track) =>
      _runExport(() => FlightExportService.instance.shareGpx(track), 'GPX');

  Future<void> _exportIgc(FlightTrack track) =>
      _runExport(() => FlightExportService.instance.shareIgc(track), 'IGC');

  Future<void> _exportPdf(FlightTrack track) =>
      _runExport(() => FlightReportService.instance.sharePdf(track), 'PDF');

  Future<void> _runExport(
      Future<String> Function() action, String label) async {
    final l10n = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      _snack(l10n.flightsExportFailed(label, '$e'));
    }
  }

  // ── Library import / export ────────────────────────────────────────────

  Future<void> _exportLibrary(List<FlightTrack> tracks) async {
    final l10n = AppLocalizations.of(context);
    try {
      await FlightLibraryIO.instance.exportAndShare(tracks);
    } catch (e) {
      _snack(l10n.flightsLibraryExportFailed('$e'));
    }
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
      _snack(result.failed > 0
          ? l10n.flightsImportResultFailed(
              result.added, result.skipped, result.failed)
          : l10n.flightsImportResult(result.added, result.skipped));
    } catch (e) {
      _snack(l10n.flightsImportFailed('$e'));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                      _detailRow(l10n.flightDetailStart,
                          _fmtDateTime(track.startTime)),
                      _detailRow(
                          l10n.flightDetailEnd,
                          track.endTime != null
                              ? _fmtDateTime(track.endTime!)
                              : '—'),
                      _detailRow(l10n.flightDetailDuration,
                          _fmtDuration(track.duration)),
                      _detailRow(l10n.flightDetailDistance,
                          '${(track.distanceM / 1000).toStringAsFixed(2)} km'),
                      _detailRow(l10n.flightDetailMaxAltitude,
                          '${track.maxAltitude.toStringAsFixed(0)} m'),
                      _detailRow(l10n.flightDetailMinAltitude,
                          '${track.minAltitude.toStringAsFixed(0)} m'),
                      _detailRow(l10n.flightDetailMaxClimb,
                          '${track.maxClimb.toStringAsFixed(1)} m/s'),
                      _detailRow(l10n.flightDetailMaxSink,
                          '${track.maxSink.toStringAsFixed(1)} m/s'),
                      _detailRow(l10n.flightDetailSamples,
                          '${track.pointCount}'),
                      if ((track.takeoffSite?.isNotEmpty ?? false) ||
                          (track.landingSite?.isNotEmpty ?? false)) ...[
                        _detailRow(l10n.flightDetailTakeoff,
                            track.takeoffSite ?? '—'),
                        _detailRow(l10n.flightDetailLanding,
                            track.landingSite ?? '—'),
                      ],
                      if (track.hasEquipment) ...[
                        const SizedBox(height: 8),
                        _sectionLabel(theme, l10n.equipment),
                        if (track.gliderName?.isNotEmpty ?? false)
                          _detailRow(
                              l10n.equipmentGlider, track.gliderName!),
                        if (track.harnessName?.isNotEmpty ?? false)
                          _detailRow(
                              l10n.equipmentHarness, track.harnessName!),
                        if (track.helmetName?.isNotEmpty ?? false)
                          _detailRow(
                              l10n.equipmentHelmet, track.helmetName!),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            await _editEquipment(track);
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(track.hasEquipment
                              ? l10n.equipmentEdit
                              : l10n.equipmentAdd),
                        ),
                      ),
                      if (track.hasSamples) ...[
                        const SizedBox(height: 8),
                        _sectionLabel(theme, l10n.flightDetailPerformance),
                        _detailRow(l10n.flightDetailStraightDistance,
                            '${(stats.straightDistanceM / 1000).toStringAsFixed(2)} km'),
                        _detailRow(l10n.flightDetailXcDistance,
                            '${(stats.xcDistanceM / 1000).toStringAsFixed(2)} km'),
                        if (stats.faiTriangleM > 0)
                          _detailRow(
                              l10n.flightDetailFaiTriangle,
                              '${(stats.faiTriangleM / 1000).toStringAsFixed(2)} km'
                              '${stats.faiClosed ? ' (${l10n.flightDetailFaiClosed})' : ''}'),
                        _detailRow(l10n.flightDetailMaxFromStart,
                            '${(stats.maxDistanceFromStartM / 1000).toStringAsFixed(2)} km'),
                        _detailRow(l10n.flightDetailAvgGroundSpeed,
                            '${stats.avgGroundSpeedKph.toStringAsFixed(1)} km/h'),
                        _detailRow(l10n.flightDetailAvgCruiseSpeed,
                            '${stats.avgCruiseSpeedKph.toStringAsFixed(1)} km/h'),
                        _detailRow(l10n.flightDetailMaxSpeed,
                            '${stats.maxSpeedKph.toStringAsFixed(1)} km/h'),
                        _detailRow(l10n.flightDetailAvgClimb,
                            '${stats.avgClimbMs.toStringAsFixed(1)} m/s'),
                        _detailRow(l10n.flightDetailAvgSink,
                            '${stats.avgSinkMs.toStringAsFixed(1)} m/s'),
                        _detailRow(
                            l10n.flightDetailAvgGlideRatio,
                            stats.avgGlideRatio > 0
                                ? stats.avgGlideRatio.toStringAsFixed(1)
                                : '—'),
                        _detailRow(l10n.flightDetailTrackEfficiency,
                            '${(stats.trackEfficiency * 100).toStringAsFixed(0)} %'),
                        _detailRow(l10n.flightDetailThermals,
                            '${stats.thermalCount}'),
                        _detailRow(l10n.flightDetailAltGained,
                            '${stats.altitudeGainedM.toStringAsFixed(0)} m'),
                        _detailRow(l10n.flightDetailAltLost,
                            '${stats.altitudeLostM.toStringAsFixed(0)} m'),
                        _detailRow(l10n.flightDetailClimbTime,
                            _fmtDuration(stats.climbTime)),
                        _detailRow(l10n.flightDetailGlideTime,
                            _fmtDuration(stats.glideTime)),
                        _detailRow(l10n.flightDetailSinkTime,
                            _fmtDuration(stats.sinkTime)),
                        _detailRow(l10n.flightDetailMovingTime,
                            _fmtDuration(stats.movingTime)),
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
                              icon:
                                  const Icon(Icons.description_outlined, size: 18),
                              label: const Text('IGC'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _exportPdf(track),
                              icon:
                                  const Icon(Icons.picture_as_pdf_outlined, size: 18),
                              label: const Text('PDF'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _saveShareCard(track),
                              icon: const Icon(Icons.image_outlined, size: 18),
                              label: Text(l10n.flightExportShareCard),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _resolveSites(track);
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.place_outlined, size: 18),
                              label: Text(l10n.flightDetailSiteNames),
                            ),
                          ],
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
}
