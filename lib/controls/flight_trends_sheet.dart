import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/flight_recorder.dart';
import '../data/flight_statistics.dart';
import '../l10n/app_localizations.dart';

Future<void> showFlightTrendsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (_) => const _FlightTrendsSheet(),
  );
}

class _FlightTrendsSheet extends StatefulWidget {
  const _FlightTrendsSheet();

  @override
  State<_FlightTrendsSheet> createState() => _FlightTrendsSheetState();
}

class _FlightTrendsSheetState extends State<_FlightTrendsSheet> {
  final FlightRecorder _recorder = FlightRecorder.instance;
  late List<FlightTrack> _tracks;
  FlightTrack? _firstTrack;
  FlightTrack? _secondTrack;

  @override
  void initState() {
    super.initState();
    _tracks = _recorder.tracks;
    _selectComparisonFlights();
    _recorder.addListener(_onTracksChanged);
  }

  @override
  void dispose() {
    _recorder.removeListener(_onTracksChanged);
    super.dispose();
  }

  void _onTracksChanged() {
    setState(() {
      _tracks = _recorder.tracks;
      _selectComparisonFlights();
    });
  }

  void _selectComparisonFlights() {
    if (!_tracks.contains(_firstTrack)) {
      _firstTrack = _tracks.isNotEmpty ? _tracks.first : null;
    }
    if (!_tracks.contains(_secondTrack) || _secondTrack == _firstTrack) {
      _secondTrack = _tracks.length > 1 ? _tracks[1] : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.flightTrends),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.trendsOverview),
              Tab(text: l10n.trendsCompare),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildOverview(context), _buildComparison(context)],
        ),
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.trendsNoFlights,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    final stats = FlightStatistics.compute(_tracks, includeDetailed: false);
    final maxClimbs = _tracks.map((track) => track.maxClimb).toList();
    final avgPeakClimb = maxClimbs.isEmpty
        ? 0.0
        : maxClimbs.reduce((a, b) => a + b) / maxClimbs.length;
    final recentTracks = _tracks.take(12).toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final width = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: _TrendMetricCard(
                    icon: Icons.flight_outlined,
                    label: l10n.trendsFlights,
                    value: '${stats.flightCount}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _TrendMetricCard(
                    icon: Icons.timer_outlined,
                    label: l10n.statsTotalAirtime,
                    value: _formatDuration(l10n, stats.totalDuration),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _TrendMetricCard(
                    icon: Icons.timelapse,
                    label: l10n.trendsAverageFlight,
                    value: _formatDuration(l10n, stats.avgDuration),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _TrendMetricCard(
                    icon: Icons.trending_up,
                    label: l10n.trendsAveragePeakClimb,
                    value: '${avgPeakClimb.toStringAsFixed(1)} m/s',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _TrendSection(
          title: l10n.trendsAirtimeByYear,
          icon: Icons.calendar_month_outlined,
          child: _AirtimeByYearChart(buckets: stats.byYear),
        ),
        const SizedBox(height: 16),
        _TrendSection(
          title: l10n.trendsPeakClimbByFlight,
          icon: Icons.trending_up,
          child: _PeakClimbChart(tracks: recentTracks),
        ),
      ],
    );
  }

  Widget _buildComparison(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_tracks.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.trendsNeedTwoFlights,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final first = _firstTrack ?? _tracks.first;
    final second = _secondTrack ?? _tracks[1];
    final locale = Localizations.localeOf(context).toString();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FlightPicker(
          label: l10n.trendsFlightA,
          tracks: _tracks,
          value: first,
          locale: locale,
          onChanged: (track) {
            if (track == null) return;
            setState(() {
              _firstTrack = track;
              if (_secondTrack == track) {
                _secondTrack = _tracks.firstWhere((item) => item != track);
              }
            });
          },
        ),
        const SizedBox(height: 12),
        _FlightPicker(
          label: l10n.trendsFlightB,
          tracks: _tracks,
          value: second,
          locale: locale,
          onChanged: (track) {
            if (track == null) return;
            setState(() {
              _secondTrack = track;
              if (_firstTrack == track) {
                _firstTrack = _tracks.firstWhere((item) => item != track);
              }
            });
          },
        ),
        const SizedBox(height: 24),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _ComparisonHeader(first: first, second: second, locale: locale),
              const Divider(height: 1),
              _ComparisonRow(
                label: l10n.trendsDuration,
                first: _formatDuration(l10n, first.duration),
                second: _formatDuration(l10n, second.duration),
              ),
              _ComparisonRow(
                label: l10n.trendsTrackDistance,
                first: '${(first.distanceM / 1000).toStringAsFixed(1)} km',
                second: '${(second.distanceM / 1000).toStringAsFixed(1)} km',
              ),
              _ComparisonRow(
                label: l10n.trendsMaxAltitude,
                first: '${first.maxAltitude.toStringAsFixed(0)} m',
                second: '${second.maxAltitude.toStringAsFixed(0)} m',
              ),
              _ComparisonRow(
                label: l10n.trendsStrongestClimb,
                first: '${first.maxClimb.toStringAsFixed(1)} m/s',
                second: '${second.maxClimb.toStringAsFixed(1)} m/s',
              ),
              _ComparisonRow(
                label: l10n.trendsStrongestSink,
                first: '${first.maxSink.toStringAsFixed(1)} m/s',
                second: '${second.maxSink.toStringAsFixed(1)} m/s',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDuration(AppLocalizations l10n, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return l10n.trendsDurationValue(hours, minutes);
}

class _TrendMetricCard extends StatelessWidget {
  const _TrendMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _AirtimeByYearChart extends StatelessWidget {
  const _AirtimeByYearChart({required this.buckets});

  final List<FlightBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final maxMinutes = buckets.fold<int>(
      0,
      (maximum, bucket) => math.max(maximum, bucket.duration.inMinutes),
    );
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final bucket in buckets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(bucket.label, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxMinutes == 0
                          ? 0
                          : bucket.duration.inMinutes / maxMinutes,
                      minHeight: 10,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 84,
                  child: Text(
                    '${bucket.count} · ${bucket.duration.inHours} h',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PeakClimbChart extends StatelessWidget {
  const _PeakClimbChart({required this.tracks});

  final List<FlightTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final maxClimb = tracks.fold<double>(
      0,
      (maximum, track) => math.max(maximum, track.maxClimb),
    );

    return Column(
      children: [
        for (final track in tracks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 94,
                  child: Text(
                    DateFormat.Md(locale).format(track.startTime.toLocal()),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxClimb <= 0 ? 0 : track.maxClimb / maxClimb,
                      minHeight: 10,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${track.maxClimb.toStringAsFixed(1)} m/s',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FlightPicker extends StatelessWidget {
  const _FlightPicker({
    required this.label,
    required this.tracks,
    required this.value,
    required this.locale,
    required this.onChanged,
  });

  final String label;
  final List<FlightTrack> tracks;
  final FlightTrack value;
  final String locale;
  final ValueChanged<FlightTrack?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FlightTrack>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: [
            for (final track in tracks)
              DropdownMenuItem(
                value: track,
                child: Text(
                  _trackLabel(track, locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

String _trackLabel(FlightTrack track, String locale) {
  final date = DateFormat.yMMMd(
    locale,
  ).add_Hm().format(track.startTime.toLocal());
  final site = track.takeoffSite?.trim();
  return site == null || site.isEmpty ? date : '$date · $site';
}

class _ComparisonHeader extends StatelessWidget {
  const _ComparisonHeader({
    required this.first,
    required this.second,
    required this.locale,
  });

  final FlightTrack first;
  final FlightTrack second;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          Expanded(
            child: Text(
              _trackLabel(first, locale),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _trackLabel(second, locale),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.first,
    required this.second,
    this.isLast = false,
  });

  final String label;
  final String first;
  final String second;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Expanded(
                child: Text(
                  first,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  second,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}
