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
import 'flight_replay_sheet.dart';
import 'track_3d_sheet.dart';

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
                child: Text('Flights', style: theme.textTheme.titleLarge),
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
    return [
      // DEBUG ONLY — inject a random flight record for testing.
      if (kDebugMode)
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Add random flight (debug)',
          onPressed: () => _recorder.addRandomDebugTrack(),
        ),
      IconButton(
        icon: const Icon(Icons.file_download_outlined),
        tooltip: 'Import library (.pbflights)',
        onPressed: _importLibrary,
      ),
      if (tracks.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.file_upload_outlined),
          tooltip: 'Export library (.pbflights)',
          onPressed: () => _exportLibrary(tracks),
        ),
      if (tracks.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Clear all',
          onPressed: _confirmClearAll,
        ),
      IconButton(
        icon: const Icon(Icons.travel_explore),
        tooltip: 'Place-name lookup settings',
        onPressed: _openGeoSettings,
      ),
      IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_outlined,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No flights recorded yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 4),
          Text(
            'Start a flight to record a track.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackTile(ThemeData theme, FlightTrack track) {
    final canReplay = track.samples.length >= 2;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.flight, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(_fmtDateTime(track.startTime)),
      subtitle: Text(
        '${_fmtDuration(track.duration)} · '
        '${(track.distanceM / 1000).toStringAsFixed(2)} km · '
        '${track.pointCount} pts',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: canReplay
                ? 'Replay'
                : 'No track points to replay',
            onPressed: canReplay ? () => _replay(track) : null,
          ),
          IconButton(
            icon: const Icon(Icons.threed_rotation),
            tooltip: canReplay ? '3D replay' : 'No track points to replay',
            onPressed: canReplay ? () => _replay3D(track) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
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
    showTrack3DSheet(context, track);
  }

  // ── Share card ─────────────────────────────────────────────────────────

  Future<void> _saveShareCard(FlightTrack track) async {
    try {
      final saved =
          await FlightShareCardService.instance.saveToGallery(track);
      _snack(saved
          ? 'Share card saved to gallery'
          : 'Saved to a file and opened the share sheet');
    } catch (e) {
      _snack('Share card failed: $e');
    }
  }

  // ── Reverse-geocoded site names ──────────────────────────────────────────

  Future<void> _resolveSites(FlightTrack track) async {
    await GeoNameSettings.instance.load();
    if (!GeoNameSettings.instance.isConfigured) {
      _snack('Set an AMap key in place-name settings first.');
      return;
    }
    final fixes = track.samples.where((s) => s.data.hasFix).toList();
    if (fixes.length < 2) {
      _snack('This flight has no track points to locate.');
      return;
    }
    _snack('Looking up site names…');
    try {
      final takeoff = await ReverseGeocoderService.instance
          .tryLookup(fixes.first.data.latitude, fixes.first.data.longitude);
      final landing = await ReverseGeocoderService.instance
          .tryLookup(fixes.last.data.latitude, fixes.last.data.longitude);
      if (takeoff != null) track.takeoffSite = takeoff;
      if (landing != null) track.landingSite = landing;
      _recorder.persistTrackMeta(track);
      _snack(takeoff == null && landing == null
          ? 'No place names found for these coordinates.'
          : 'Site names updated.');
    } catch (e) {
      _snack('Lookup failed: $e');
    }
  }

  // ── Equipment editor ─────────────────────────────────────────────────────

  Future<void> _editEquipment(FlightTrack track) async {
    await EquipmentStore.instance.load();
    if (!mounted) return;
    final glider = TextEditingController(
        text: track.gliderName ?? EquipmentStore.instance.glider ?? '');
    final harness = TextEditingController(
        text: track.harnessName ?? EquipmentStore.instance.harness ?? '');
    final helmet = TextEditingController(
        text: track.helmetName ?? EquipmentStore.instance.helmet ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Equipment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: glider,
                decoration: const InputDecoration(labelText: 'Glider'),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: harness,
                decoration: const InputDecoration(labelText: 'Harness'),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: helmet,
                decoration: const InputDecoration(labelText: 'Helmet'),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
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
    final settings = GeoNameSettings.instance;
    final keyCtrl = TextEditingController(text: settings.amapKey ?? '');
    var auto = settings.autoLookup;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Place-name lookup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reverse-geocode takeoff/landing coordinates to place names '
                  'using the AMap (AutoNavi) web service. Requests only ever go '
                  'to restapi.amap.com.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'AMap web-service key',
                  ),
                  obscureText: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-lookup after each flight'),
                  value: auto,
                  onChanged: (v) => setInner(() => auto = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final key = keyCtrl.text.trim();
    await settings.setAmapKey(key.isEmpty ? null : key);
    await settings.setAutoLookup(auto);
    _snack('Place-name settings saved.');
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
    try {
      await action();
    } catch (e) {
      _snack('$label export failed: $e');
    }
  }

  // ── Library import / export ────────────────────────────────────────────

  Future<void> _exportLibrary(List<FlightTrack> tracks) async {
    try {
      await FlightLibraryIO.instance.exportAndShare(tracks);
    } catch (e) {
      _snack('Library export failed: $e');
    }
  }

  Future<void> _importLibrary() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [FlightLibraryIO.extension, 'zip'],
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      final result = await FlightLibraryIO.instance.importFile(path);
      _snack('Imported ${result.added} · skipped ${result.skipped}'
          '${result.failed > 0 ? ' · failed ${result.failed}' : ''}');
    } catch (e) {
      _snack('Import failed: $e');
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final stats = FlightDerivedStats.compute(track);
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Flight details'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    if (track.hasSamples)
                      IconButton(
                        icon: const Icon(Icons.data_array),
                        tooltip: 'Delete samples',
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
                        tooltip: '3D Replay',
                        color: theme.colorScheme.primary,
                        onPressed: () {
                          Navigator.of(context).pop();
                          _replay3D(track);
                        },
                      ),
                    if (track.samples.length >= 2)
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        tooltip: 'Replay',
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
                      _detailRow('Start', _fmtDateTime(track.startTime)),
                      _detailRow(
                          'End',
                          track.endTime != null
                              ? _fmtDateTime(track.endTime!)
                              : '—'),
                      _detailRow('Duration', _fmtDuration(track.duration)),
                      _detailRow('Distance',
                          '${(track.distanceM / 1000).toStringAsFixed(2)} km'),
                      _detailRow('Max altitude',
                          '${track.maxAltitude.toStringAsFixed(0)} m'),
                      _detailRow('Min altitude',
                          '${track.minAltitude.toStringAsFixed(0)} m'),
                      _detailRow('Max climb',
                          '${track.maxClimb.toStringAsFixed(1)} m/s'),
                      _detailRow('Max sink',
                          '${track.maxSink.toStringAsFixed(1)} m/s'),
                      _detailRow('Samples', '${track.pointCount}'),
                      if ((track.takeoffSite?.isNotEmpty ?? false) ||
                          (track.landingSite?.isNotEmpty ?? false)) ...[
                        _detailRow('Takeoff', track.takeoffSite ?? '—'),
                        _detailRow('Landing', track.landingSite ?? '—'),
                      ],
                      if (track.hasEquipment) ...[
                        const SizedBox(height: 8),
                        _sectionLabel(theme, 'Equipment'),
                        if (track.gliderName?.isNotEmpty ?? false)
                          _detailRow('Glider', track.gliderName!),
                        if (track.harnessName?.isNotEmpty ?? false)
                          _detailRow('Harness', track.harnessName!),
                        if (track.helmetName?.isNotEmpty ?? false)
                          _detailRow('Helmet', track.helmetName!),
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
                              ? 'Edit equipment'
                              : 'Add equipment'),
                        ),
                      ),
                      if (track.hasSamples) ...[
                        const SizedBox(height: 8),
                        _sectionLabel(theme, 'Performance'),
                        _detailRow('Straight distance',
                            '${(stats.straightDistanceM / 1000).toStringAsFixed(2)} km'),
                        _detailRow('XC distance',
                            '${(stats.xcDistanceM / 1000).toStringAsFixed(2)} km'),
                        if (stats.faiTriangleM > 0)
                          _detailRow(
                              'FAI triangle',
                              '${(stats.faiTriangleM / 1000).toStringAsFixed(2)} km'
                              '${stats.faiClosed ? ' (closed)' : ''}'),
                        _detailRow('Max from start',
                            '${(stats.maxDistanceFromStartM / 1000).toStringAsFixed(2)} km'),
                        _detailRow('Avg ground speed',
                            '${stats.avgGroundSpeedKph.toStringAsFixed(1)} km/h'),
                        _detailRow('Avg cruise speed',
                            '${stats.avgCruiseSpeedKph.toStringAsFixed(1)} km/h'),
                        _detailRow('Max speed',
                            '${stats.maxSpeedKph.toStringAsFixed(1)} km/h'),
                        _detailRow('Avg climb',
                            '${stats.avgClimbMs.toStringAsFixed(1)} m/s'),
                        _detailRow('Avg sink',
                            '${stats.avgSinkMs.toStringAsFixed(1)} m/s'),
                        _detailRow(
                            'Avg glide ratio',
                            stats.avgGlideRatio > 0
                                ? stats.avgGlideRatio.toStringAsFixed(1)
                                : '—'),
                        _detailRow('Track efficiency',
                            '${(stats.trackEfficiency * 100).toStringAsFixed(0)} %'),
                        _detailRow('Thermals', '${stats.thermalCount}'),
                        _detailRow('Alt gained',
                            '${stats.altitudeGainedM.toStringAsFixed(0)} m'),
                        _detailRow('Alt lost',
                            '${stats.altitudeLostM.toStringAsFixed(0)} m'),
                        _detailRow(
                            'Climb time', _fmtDuration(stats.climbTime)),
                        _detailRow(
                            'Glide time', _fmtDuration(stats.glideTime)),
                        _detailRow('Sink time', _fmtDuration(stats.sinkTime)),
                        _detailRow(
                            'Moving time', _fmtDuration(stats.movingTime)),
                        const SizedBox(height: 8),
                        _sectionLabel(theme, 'Export'),
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
                              label: const Text('Share card'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _resolveSites(track);
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.place_outlined, size: 18),
                              label: const Text('Site names'),
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
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sample data?'),
        content: const Text(
          'This removes the per-point track data (position/altitude/vario) '
          'for this flight. The flight and its summary stay in the log, but it '
          'can no longer be replayed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all flights?'),
        content: const Text('This removes every recorded flight.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
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
