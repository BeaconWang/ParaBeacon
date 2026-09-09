import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/flight_derived_stats.dart';
import '../data/flight_export_service.dart';
import '../data/flight_library_io.dart';
import '../data/flight_recorder.dart';
import '../data/flight_report_service.dart';
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.route, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Flights', style: theme.textTheme.titleLarge),
                ),
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
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
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
            return AlertDialog(
              title: const Text('Flight details'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
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
                      if (track.hasSamples) ...[
                        const SizedBox(height: 8),
                        _sectionLabel(theme, 'Performance'),
                        _detailRow('Straight distance',
                            '${(stats.straightDistanceM / 1000).toStringAsFixed(2)} km'),
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
                              onPressed: () {
                                Navigator.of(context).pop();
                                _replay3D(track);
                              },
                              icon: const Icon(Icons.threed_rotation, size: 18),
                              label: const Text('3D'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                if (track.hasSamples)
                  TextButton.icon(
                    onPressed: () async {
                      final confirmed = await _confirmDeleteSamples();
                      if (confirmed != true) return;
                      _recorder.deleteTrackSamples(track);
                      // Refresh the dialog so the button hides and the replay
                      // action disappears.
                      setDialogState(() {});
                    },
                    icon: const Icon(Icons.data_array),
                    label: Text('Delete samples',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (track.samples.length >= 2)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _replay(track);
                    },
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text('Replay',
                        style: TextStyle(color: theme.colorScheme.primary)),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close',
                      style: TextStyle(color: theme.colorScheme.primary)),
                ),
              ],
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
