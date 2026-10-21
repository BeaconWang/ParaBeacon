import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/flight_derived_stats.dart';
import '../data/flight_recorder.dart';
import '../data/flight_statistics.dart';
import '../data/flight_statistics_share_card_service.dart';
import '../l10n/app_localizations.dart';

/// Opens the flight Statistics screen for [tracks] as a full-screen sheet.
///
/// [selected] controls the scope label in the header (all flights vs. the
/// currently-selected subset).
Future<void> showFlightStatisticsSheet(
  BuildContext context, {
  required List<FlightTrack> tracks,
  required bool selected,
}) {
  final snapshot = List<FlightTrack>.unmodifiable(tracks);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (context) =>
        _FlightStatisticsSheet(tracks: snapshot, selected: selected),
  );
}

enum _StatsPriority { summary, detailed }

enum _StatisticsExportDestination { downloads, share }

class _FlightStatisticsSheet extends StatefulWidget {
  const _FlightStatisticsSheet({required this.tracks, required this.selected});

  final List<FlightTrack> tracks;
  final bool selected;

  @override
  State<_FlightStatisticsSheet> createState() => _FlightStatisticsSheetState();
}

class _FlightStatisticsSheetState extends State<_FlightStatisticsSheet> {
  late FlightStatistics _stats;
  _StatsPriority _priority = _StatsPriority.summary;
  bool _isComputing = false;
  bool _showProgress = false;
  bool _detailsComplete = false;
  String? _detailsError;
  int _completedFlights = 0;
  int _detailedFlights = 0;
  int _jobId = 0;
  bool _shareWhenDetailedReady = false;
  bool _isSharingCard = false;

  Isolate? _worker;
  ReceivePort? _resultsPort;
  ReceivePort? _errorsPort;
  ReceivePort? _exitPort;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _stats = FlightStatistics.compute(widget.tracks, includeDetailed: false);
  }

  @override
  void dispose() {
    _stopDetailedWork();
    super.dispose();
  }

  void _selectPriority(_StatsPriority priority) {
    if (priority == _priority &&
        (priority == _StatsPriority.summary ||
            _isComputing ||
            _detailsComplete)) {
      return;
    }
    if (priority == _StatsPriority.summary) {
      _shareWhenDetailedReady = false;
      _stopDetailedWork();
      setState(() {
        _priority = priority;
        _stats = FlightStatistics.compute(
          widget.tracks,
          includeDetailed: false,
        );
        _detailsComplete = false;
        _detailsError = null;
        _completedFlights = 0;
        _detailedFlights = 0;
      });
      return;
    }
    setState(() => _priority = priority);
    _startDetailedWork();
  }

  Future<void> _startDetailedWork() async {
    _stopDetailedWork();
    final jobId = _jobId;
    _stats = FlightStatistics.compute(widget.tracks, includeDetailed: false);
    _completedFlights = 0;
    _detailedFlights = widget.tracks.where((track) => track.hasSamples).length;
    _detailsComplete = false;
    _detailsError = null;

    if (mounted) setState(() => _isComputing = _detailedFlights > 0);
    if (_detailedFlights == 0) {
      if (mounted) {
        setState(() => _detailsComplete = true);
        _shareAfterDetailsReady(jobId);
      }
      return;
    }

    _progressTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _jobId == jobId && _isComputing) {
        setState(() => _showProgress = true);
      }
    });

    if (kIsWeb) {
      await _computeDetailedOnWeb(jobId);
      return;
    }

    final resultsPort = ReceivePort();
    final errorsPort = ReceivePort();
    final exitPort = ReceivePort();
    _resultsPort = resultsPort;
    _errorsPort = errorsPort;
    _exitPort = exitPort;
    resultsPort.listen((message) => _onWorkerMessage(jobId, message));
    errorsPort.listen((message) {
      if (_jobId == jobId) {
        _finishDetailedWork(jobId, error: '$message');
      }
    });
    exitPort.listen((_) {
      if (_jobId == jobId && _isComputing) {
        _finishDetailedWork(jobId, error: 'worker exited before completion');
      }
    });

    try {
      final worker = await Isolate.spawn<List<Object?>>(
        _computeFlightDetailsInWorker,
        <Object?>[widget.tracks, resultsPort.sendPort],
        onError: errorsPort.sendPort,
        onExit: exitPort.sendPort,
        errorsAreFatal: true,
      );
      if (!mounted || _jobId != jobId || !_isComputing) {
        worker.kill(priority: Isolate.immediate);
        return;
      }
      _worker = worker;
    } catch (error) {
      _finishDetailedWork(jobId, error: '$error');
    }
  }

  Future<void> _computeDetailedOnWeb(int jobId) async {
    try {
      for (var i = 0; i < widget.tracks.length; i++) {
        if (!mounted || _jobId != jobId || !_isComputing) return;
        final track = widget.tracks[i];
        if (!track.hasSamples) continue;
        final details = FlightDerivedStats.compute(track);
        if (!mounted || _jobId != jobId || !_isComputing) return;
        setState(() {
          _stats.addDetailedTrackStats(track, details);
          _completedFlights++;
        });
        await Future<void>.delayed(Duration.zero);
      }
      _finishDetailedWork(jobId);
    } catch (error) {
      _finishDetailedWork(jobId, error: '$error');
    }
  }

  void _onWorkerMessage(int jobId, Object? message) {
    if (!mounted || _jobId != jobId || message is! List || message.isEmpty) {
      return;
    }
    final index = message[0];
    if (index is! int) return;
    if (index == -1) {
      _finishDetailedWork(jobId);
    } else if (index == -2) {
      _finishDetailedWork(
        jobId,
        error: message.length > 1 ? '${message[1]}' : 'calculation failed',
      );
    } else if (index >= 0 &&
        index < widget.tracks.length &&
        message.length > 1 &&
        message[1] is FlightDerivedStats) {
      setState(() {
        _stats.addDetailedTrackStats(
          widget.tracks[index],
          message[1] as FlightDerivedStats,
        );
        _completedFlights++;
      });
    }
  }

  void _finishDetailedWork(int jobId, {String? error}) {
    if (!mounted || _jobId != jobId) return;
    _progressTimer?.cancel();
    _progressTimer = null;
    _worker = null;
    _closeWorkerPorts();
    setState(() {
      _isComputing = false;
      _showProgress = false;
      _detailsComplete = error == null;
      _detailsError = error;
    });
    _shareAfterDetailsReady(jobId);
  }

  void _shareAfterDetailsReady(int jobId) {
    if (!mounted || _jobId != jobId || !_shareWhenDetailedReady) return;
    _shareWhenDetailedReady = false;
    if (!_detailsComplete) {
      _showSnack(AppLocalizations.of(context).statsCalculationFailed);
      return;
    }
    unawaited(_exportStatisticsCard());
  }

  void _requestStatisticsShareCard() {
    if (_isSharingCard || _stats.isEmpty) return;
    if (_isComputing) {
      setState(() => _shareWhenDetailedReady = true);
      return;
    }
    if (!_detailsComplete) {
      _shareWhenDetailedReady = true;
      if (_priority == _StatsPriority.detailed) {
        unawaited(_startDetailedWork());
      } else {
        _selectPriority(_StatsPriority.detailed);
      }
      return;
    }
    unawaited(_exportStatisticsCard());
  }

  Future<void> _exportStatisticsCard() async {
    if (!mounted || _isSharingCard || _stats.isEmpty) return;
    setState(() => _isSharingCard = true);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final service = FlightStatisticsShareCardService.instance;
    try {
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      if (isAndroid) {
        final destination = await _chooseStatisticsExportDestination(l10n);
        if (destination == null || !mounted) return;
        if (destination == _StatisticsExportDestination.downloads) {
          final path = await service.saveToDownloads(
            _stats,
            l10n,
            selected: widget.selected,
            locale: locale,
          );
          if (path != null && mounted) {
            _showSnack(l10n.flightsExportSavedToDownloads);
          }
        } else {
          await service.shareCard(
            _stats,
            l10n,
            selected: widget.selected,
            locale: locale,
          );
          if (mounted) _showSnack(l10n.flightsShareCardSharedFile);
        }
        return;
      }
      final saved = await service.saveToGallery(
        _stats,
        l10n,
        selected: widget.selected,
        locale: locale,
      );
      if (mounted) {
        _showSnack(
          saved ? l10n.flightsShareCardSaved : l10n.flightsShareCardSharedFile,
        );
      }
    } catch (error) {
      if (mounted) _showSnack(l10n.flightsShareCardFailed('$error'));
    } finally {
      if (mounted) setState(() => _isSharingCard = false);
    }
  }

  Future<_StatisticsExportDestination?> _chooseStatisticsExportDestination(
    AppLocalizations l10n,
  ) {
    return showModalBottomSheet<_StatisticsExportDestination>(
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
                  l10n.flightsExportDestinationTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.flightsExportDestinationDownloads),
              onTap: () => Navigator.of(
                context,
              ).pop(_StatisticsExportDestination.downloads),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.flightsExportDestinationShare),
              onTap: () =>
                  Navigator.of(context).pop(_StatisticsExportDestination.share),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _stopDetailedWork() {
    _jobId++;
    _progressTimer?.cancel();
    _progressTimer = null;
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _closeWorkerPorts();
    _isComputing = false;
    _showProgress = false;
  }

  void _closeWorkerPorts() {
    _resultsPort?.close();
    _errorsPort?.close();
    _exitPort?.close();
    _resultsPort = null;
    _errorsPort = null;
    _exitPort = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsTitle),
            Text(
              widget.selected
                  ? l10n.statsScopeSelected(_stats.flightCount)
                  : l10n.statsScopeAll(_stats.flightCount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.flightExportShareCard,
            onPressed: _stats.isEmpty || _isSharingCard
                ? null
                : _requestStatisticsShareCard,
            icon: _isSharingCard
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!_stats.isEmpty) _priorityPicker(l10n),
            if (_showProgress) _progressPanel(theme, l10n),
            if (_detailsError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l10n.statsCalculationFailed,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (_priority == _StatsPriority.detailed &&
                !_isComputing &&
                _detailedFlights == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l10n.statsNoDetailedTracks,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Expanded(
              child: _stats.isEmpty
                  ? _empty(context, theme, l10n)
                  : _StatsBody(stats: _stats, locale: locale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityPicker(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_StatsPriority>(
          segments: [
            ButtonSegment(
              value: _StatsPriority.summary,
              label: Text(l10n.statsPrioritySummary),
              icon: const Icon(Icons.summarize_outlined),
            ),
            ButtonSegment(
              value: _StatsPriority.detailed,
              label: Text(l10n.statsPriorityDetailed),
              icon: const Icon(Icons.analytics_outlined),
            ),
          ],
          selected: {_priority},
          onSelectionChanged: (selection) => _selectPriority(selection.first),
        ),
      ),
    );
  }

  Widget _progressPanel(ThemeData theme, AppLocalizations l10n) {
    final progress = _detailedFlights == 0
        ? null
        : (_completedFlights / _detailedFlights).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 6),
                Text(
                  l10n.statsComputingDetailed(
                    _completedFlights,
                    _detailedFlights,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _selectPriority(_StatsPriority.summary),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insights_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.statsNoData,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.statsNoDataHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

@pragma('vm:entry-point')
void _computeFlightDetailsInWorker(List<Object?> args) {
  final tracks = args[0] as List<FlightTrack>;
  final sendPort = args[1] as SendPort;
  try {
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      if (track.hasSamples) {
        sendPort.send(<Object?>[i, FlightDerivedStats.compute(track)]);
      }
    }
    sendPort.send(const <Object?>[-1, null]);
  } catch (error) {
    sendPort.send(<Object?>[-2, error.toString()]);
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats, required this.locale});

  final FlightStatistics stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Hero summary cards ────────────────────────────────────────────
        _heroGrid(context, theme, l10n),
        const SizedBox(height: 20),

        // ── Overview ───────────────────────────────────────────────────────
        _Section(
          title: l10n.statsSectionOverview,
          icon: Icons.dashboard_outlined,
          child: Column(
            children: [
              _kv(theme, l10n.statsDateRange, _dateRange(l10n)),
              _kv(theme, l10n.statsFirstFlight, _date(stats.firstFlight)),
              _kv(theme, l10n.statsLastFlight, _date(stats.lastFlight)),
              _kv(theme, l10n.statsActiveDays, '${stats.activeDays}'),
              _kv(
                theme,
                l10n.statsFlightsPerDay,
                stats.flightsPerActiveDay.toStringAsFixed(1),
              ),
              _kv(
                theme,
                l10n.statsSampledFlights,
                '${stats.flightsWithSamples} / ${stats.flightCount}',
              ),
            ],
          ),
        ),

        // ── Personal records ─────────────────────────────────────────────
        _Section(
          title: l10n.statsSectionRecords,
          icon: Icons.emoji_events_outlined,
          child: Column(
            children: [
              _record(
                theme,
                l10n,
                l10n.statsLongestFlight,
                stats.longestDuration == null
                    ? null
                    : _hms(stats.longestDuration!.value),
                stats.longestDuration?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsLongestDistance,
                stats.longestTrackDistanceM == null
                    ? null
                    : _km(stats.longestTrackDistanceM!.value, 2),
                stats.longestTrackDistanceM?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsLongestXc,
                stats.longestStraightDistanceM == null
                    ? null
                    : _km(stats.longestStraightDistanceM!.value, 2),
                stats.longestStraightDistanceM?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsBestFaiTriangle,
                stats.bestFaiTriangleM == null
                    ? null
                    : _km(stats.bestFaiTriangleM!.value, 2),
                stats.bestFaiTriangleM?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsMaxDistanceFromStart,
                stats.maxDistanceFromStartM == null
                    ? null
                    : _km(stats.maxDistanceFromStartM!.value, 2),
                stats.maxDistanceFromStartM?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsHighestAltitude,
                stats.highestAltitudeM == null
                    ? null
                    : '${stats.highestAltitudeM!.value.toStringAsFixed(0)} m',
                stats.highestAltitudeM?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsMaxClimb,
                stats.maxClimbMs == null
                    ? null
                    : '${stats.maxClimbMs!.value.toStringAsFixed(1)} m/s',
                stats.maxClimbMs?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsMaxSink,
                stats.maxSinkMs == null
                    ? null
                    : '${stats.maxSinkMs!.value.toStringAsFixed(1)} m/s',
                stats.maxSinkMs?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsMaxSpeed,
                stats.maxSpeedKph == null
                    ? null
                    : '${stats.maxSpeedKph!.value.toStringAsFixed(1)} km/h',
                stats.maxSpeedKph?.track,
              ),
              _record(
                theme,
                l10n,
                l10n.statsBestGlide,
                stats.bestGlideRatio?.value.toStringAsFixed(1),
                stats.bestGlideRatio?.track,
              ),
            ],
          ),
        ),

        // ── Averages ────────────────────────────────────────────────────
        _Section(
          title: l10n.statsSectionAverages,
          icon: Icons.timeline_outlined,
          child: Column(
            children: [
              _kv(theme, l10n.statsAvgDuration, _hms(stats.avgDuration)),
              _kv(
                theme,
                l10n.statsAvgDistance,
                _km(stats.avgTrackDistanceM, 2),
              ),
              _kv(
                theme,
                l10n.statsAvgXcDistance,
                _km(stats.avgStraightDistanceM, 2),
              ),
              _kv(
                theme,
                l10n.statsAvgMaxAltitude,
                '${stats.avgMaxAltitudeM.toStringAsFixed(0)} m',
              ),
              _kv(
                theme,
                l10n.statsAvgSpeed,
                '${stats.avgSpeedKph.toStringAsFixed(1)} km/h',
              ),
              _kv(
                theme,
                l10n.statsAvgGlide,
                stats.avgGlideRatio > 0
                    ? stats.avgGlideRatio.toStringAsFixed(1)
                    : '—',
              ),
            ],
          ),
        ),

        // ── Totals ──────────────────────────────────────────────────────
        _Section(
          title: l10n.statsSectionTotals,
          icon: Icons.summarize_outlined,
          child: Column(
            children: [
              _kv(
                theme,
                l10n.statsTotalAltGained,
                '${stats.totalAltitudeGainedM.toStringAsFixed(0)} m',
              ),
              _kv(
                theme,
                l10n.statsTotalAltLost,
                '${stats.totalAltitudeLostM.toStringAsFixed(0)} m',
              ),
              _kv(theme, l10n.statsTotalThermals, '${stats.totalThermals}'),
              _kv(
                theme,
                l10n.statsTotalMovingTime,
                _hms(stats.totalAirtimeMoving),
              ),
              _kv(theme, l10n.statsTotalSamples, '${stats.totalSamples}'),
            ],
          ),
        ),

        // ── Distributions ────────────────────────────────────────────────
        _Section(
          title: l10n.statsSectionByYear,
          icon: Icons.calendar_today_outlined,
          child: _BarChart(buckets: stats.byYear, locale: locale),
        ),
        _Section(
          title: l10n.statsSectionByMonth,
          icon: Icons.wb_sunny_outlined,
          child: _BarChart(
            buckets: stats.monthsLabeled(_monthLabels()),
            locale: locale,
            hideEmpty: false,
          ),
        ),
        if (stats.byAircraft.isNotEmpty)
          _Section(
            title: l10n.statsSectionByAircraft,
            icon: Icons.paragliding_outlined,
            child: _BarChart(buckets: stats.byAircraft, locale: locale),
          ),
        if (stats.byTakeoffSite.isNotEmpty)
          _Section(
            title: l10n.statsSectionBySite,
            icon: Icons.place_outlined,
            child: _BarChart(buckets: stats.byTakeoffSite, locale: locale),
          ),
      ],
    );
  }

  // ── Hero cards ───────────────────────────────────────────────────────────
  Widget _heroGrid(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final cards = <Widget>[
      _HeroCard(
        icon: Icons.flight_takeoff,
        label: l10n.statsFlights,
        value: '${stats.flightCount}',
      ),
      _HeroCard(
        icon: Icons.timer_outlined,
        label: l10n.statsTotalAirtime,
        value: _hms(stats.totalDuration),
      ),
      _HeroCard(
        icon: Icons.straighten,
        label: l10n.statsTotalDistance,
        value: _km(stats.totalTrackDistanceM, 1),
      ),
      _HeroCard(
        icon: Icons.explore_outlined,
        label: l10n.statsTotalXcDistance,
        value: _km(stats.totalStraightDistanceM, 1),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final c in cards) SizedBox(width: width, child: c)],
        );
      },
    );
  }

  // ── Row builders ───────────────────────────────────────────────────────
  Widget _kv(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _record(
    ThemeData theme,
    AppLocalizations l10n,
    String label,
    String? value,
    FlightTrack? track,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value ?? '—',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: value == null
                      ? theme.colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
              if (value != null && track != null)
                Text(
                  l10n.statsRecordOn(_date(track.startTime)),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Formatting helpers ────────────────────────────────────────────────────
  String _dateRange(AppLocalizations l10n) {
    final a = stats.firstFlight;
    final b = stats.lastFlight;
    if (a == null || b == null) return '—';
    final da = _date(a);
    final db = _date(b);
    return da == db ? da : '$da → $db';
  }

  String _date(DateTime? t) {
    if (t == null) return '—';
    return DateFormat.yMMMd(locale).format(t.toLocal());
  }

  List<String> _monthLabels() {
    final fmt = DateFormat.MMM(locale);
    return [for (var m = 1; m <= 12; m++) fmt.format(DateTime(2020, m))];
  }

  /// Kilometres with [digits] decimals. The caller appends the unit except for
  /// the already-suffixed hero card.
  static String _km(double meters, int digits) =>
      '${(meters / 1000).toStringAsFixed(digits)} km';

  static String _hms(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    final s = d.inSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

/// A titled card section with an icon and a soft surface background.
class _Section extends StatelessWidget {
  const _Section({
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
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// A compact hero statistic card (big value + small label).
class _HeroCard extends StatelessWidget {
  const _HeroCard({
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple dependency-free horizontal bar chart over labelled [buckets].
///
/// Bars are scaled to the busiest bucket's flight count; each row shows the
/// label, the proportional bar and the flight count plus airtime.
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.buckets,
    required this.locale,
    this.hideEmpty = true,
  });

  final List<FlightBucket> buckets;
  final String locale;
  final bool hideEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final shown = hideEmpty
        ? buckets.where((b) => b.count > 0).toList()
        : buckets;
    if (shown.isEmpty) {
      return Text(
        l10n.statsNotEnoughData,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final maxCount = shown
        .map((b) => b.count)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Column(children: [for (final b in shown) _row(theme, b, maxCount)]);
  }

  Widget _row(ThemeData theme, FlightBucket b, int maxCount) {
    final fraction = maxCount == 0 ? 0.0 : b.count / maxCount;
    final h = b.duration.inHours;
    final m = b.duration.inMinutes % 60;
    final airtime = h > 0 ? '${h}h ${m}m' : '${m}m';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              b.label,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: Text(
              b.count == 0 ? '—' : '${b.count} · $airtime',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
