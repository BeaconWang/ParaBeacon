import 'package:flutter/material.dart';

import '../data/flight_recorder.dart';
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

  void _showDetail(FlightTrack track) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Flight details'),
          content: Column(
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
            ],
          ),
          actions: [
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
