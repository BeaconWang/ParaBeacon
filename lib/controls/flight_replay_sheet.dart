import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../audio/vario_audio_service.dart';
import '../data/flight_data.dart';
import '../data/flight_recorder.dart';
import '../data/gcj02.dart';
import '../data/map_tile_cache.dart';
import '../data/offline_tiles_service.dart';
import '../l10n/app_localizations.dart';
import 'map_control.dart' show MapTileSources, MapTileSource;
import 'replay_gaps.dart';

/// Opens the flight replay screen for a completed [track] as a full-screen
/// sheet (feature 6: replay — animated playback on the map with optional
/// vario-audio sync).
///
/// Only flights that still carry per-sample data can be replayed. Flights
/// restored from disk store just the summary (see [FlightTrack]) and therefore
/// cannot be replayed; the caller should gate the entry point on
/// [FlightTrack.samples] being non-empty.
Future<void> showFlightReplaySheet(BuildContext context, FlightTrack track) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Background driven by the theme's bottomSheetTheme (see other sheets).
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (context) => _FlightReplaySheet(track: track),
  );
}

/// How the replay track (and its profile chart) is colored.
enum TrackColorMode { vario, speed, altitude }

class _FlightReplaySheet extends StatefulWidget {
  const _FlightReplaySheet({required this.track});

  final FlightTrack track;

  @override
  State<_FlightReplaySheet> createState() => _FlightReplaySheetState();
}

class _FlightReplaySheetState extends State<_FlightReplaySheet>
    with SingleTickerProviderStateMixin {
  /// Tile source used for the replay basemap. Users can switch it in replay.
  String _tileSourceId = 'osm';
  bool _tileSourceInitialized = false;

  final MapController _map = MapController();
  MapTileCacheProvider? _onlineTileProvider;
  OfflineFirstTileProvider? _offlineFirstTileProvider;

  MapTileCacheProvider get _cachedTileProvider =>
      _onlineTileProvider ??= MapTileCacheProvider();

  OfflineFirstTileProvider get _tileProvider => _offlineFirstTileProvider ??=
      OfflineFirstTileProvider(onlineProvider: _cachedTileProvider);

  late final Ticker _ticker;
  bool _ready = false;

  /// Playback cursor in **track-relative milliseconds** (0 == first sample).
  double _cursorMs = 0.0;

  bool _trimMode = false;
  late RangeValues _trimRange;

  /// Total track span in milliseconds (>= 1 to avoid divide-by-zero).
  late final double _spanMs;

  /// Wall-clock timestamp (ms since epoch, from the ticker) of the previous
  /// frame, used to advance [_cursorMs] by real elapsed time × [_speed].
  Duration? _lastTick;

  bool _playing = false;
  double _speed = 1.0;
  bool _audioSync = false;
  bool _showTelemetry = false;
  bool _telemetryMinimized = false;
  Offset _telemetryOffset = const Offset(8, 8);
  Size? _telemetrySize;

  /// Active track-coloring mode (affects the map polyline and profile chart).
  TrackColorMode _colorMode = TrackColorMode.vario;

  // Track-wide extrema for the speed/altitude color ramps (computed once).
  double _minAlt = 0, _maxAlt = 0, _minSpd = 0, _maxSpd = 0;

  /// The samples we replay, captured once so the list can't change under us.
  late final List<FlightSample> _samples;
  late final List<double> _sampleOffsetsMs;

  /// Missing-data periods (e.g. ground time between merged flights).
  late final List<ReplayGap> _gaps;

  /// Sample indices whose step from the previous sample spans a gap.
  late final Set<int> _gapAfterIndices;
  static final StrokePattern _gapPattern = StrokePattern.dashed(
    segments: const [8, 6],
  );
  List<LatLng>? _cachedTrackPoints;
  String? _cachedTrackPointsSourceId;
  List<Polyline>? _cachedTrackPolylines;
  int? _cachedPolylineCursorIndex;
  TrackColorMode? _cachedPolylineColorMode;
  String? _cachedPolylineSourceId;

  @override
  void initState() {
    super.initState();
    _samples = List<FlightSample>.of(widget.track.samples);
    _trimRange = RangeValues(0, math.max(0, _samples.length - 1).toDouble());
    final first = _samples.isNotEmpty ? _samples.first.time : DateTime.now();
    _sampleOffsetsMs = [
      for (final sample in _samples)
        sample.time.difference(first).inMilliseconds.toDouble(),
    ];
    _spanMs = math.max(
      1.0,
      _sampleOffsetsMs.isEmpty ? 0.0 : _sampleOffsetsMs.last,
    );
    _gaps = replayGapsFor(widget.track, _samples);
    _gapAfterIndices = {for (final gap in _gaps) gap.afterIndex};
    _computeExtrema();
    _ticker = createTicker(_onTick);
    OfflineTilesService.instance.revision.addListener(_onOfflineTilesChanged);
  }

  void _onOfflineTilesChanged() {
    if (!mounted) return;
    _cachedTrackPoints = null;
    _cachedTrackPointsSourceId = null;
    _cachedTrackPolylines = null;
    _cachedPolylineSourceId = null;
    setState(() {});
    _fitTrack();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tileSourceInitialized) return;
    _tileSourceInitialized = true;
    _tileSourceId = Localizations.localeOf(context).languageCode == 'zh'
        ? 'amap-sat'
        : 'osm';
  }

  void _computeExtrema() {
    if (_samples.isEmpty) return;
    _minAlt = double.infinity;
    _maxAlt = double.negativeInfinity;
    _minSpd = double.infinity;
    _maxSpd = double.negativeInfinity;
    for (final s in _samples) {
      final a = s.data.altitude;
      final sp = s.data.groundSpeed;
      if (a < _minAlt) _minAlt = a;
      if (a > _maxAlt) _maxAlt = a;
      if (sp < _minSpd) _minSpd = sp;
      if (sp > _maxSpd) _maxSpd = sp;
    }
    if (!_minAlt.isFinite) _minAlt = 0;
    if (!_maxAlt.isFinite) _maxAlt = 0;
    if (!_minSpd.isFinite) _minSpd = 0;
    if (!_maxSpd.isFinite) _maxSpd = 0;
  }

  @override
  void dispose() {
    OfflineTilesService.instance.revision.removeListener(
      _onOfflineTilesChanged,
    );
    _stopAudio();
    _ticker.dispose();
    super.dispose();
  }

  // ── Playback engine ─────────────────────────────────────────────────────

  double _sampleOffsetMs(int index) {
    if (_samples.isEmpty) return 0.0;
    final safeIndex = index.clamp(0, _samples.length - 1).toInt();
    return _sampleOffsetsMs[safeIndex];
  }

  double get _trimStartMs => _sampleOffsetMs(_trimRange.start.round());
  double get _trimEndMs => _sampleOffsetMs(_trimRange.end.round());

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dtMs = (elapsed - last).inMicroseconds / 1000.0;
    if (dtMs <= 0) return;

    final startMs = _trimMode ? _trimStartMs : 0.0;
    final endMs = _trimMode ? _trimEndMs : _spanMs;
    var next = _cursorMs + dtMs * replaySpeedAt(_gaps, _cursorMs, _speed);
    if (_trimMode && next < startMs) next = startMs;
    if (next >= endMs) {
      _setCursor(endMs);
      _pause();
      return;
    }
    _setCursor(next);
  }

  void _play() {
    if (_playing || _samples.length < 2) return;
    final startMs = _trimMode ? _trimStartMs : 0.0;
    final endMs = _trimMode ? _trimEndMs : _spanMs;
    if (_cursorMs < startMs || _cursorMs >= endMs) _setCursor(startMs);
    setState(() => _playing = true);
    _lastTick = null;
    _ticker.start();
    if (_audioSync) _startAudio();
  }

  void _pause() {
    if (!_playing) return;
    setState(() => _playing = false);
    _ticker.stop();
    _lastTick = null;
    _stopAudio();
  }

  void _togglePlay() => _playing ? _pause() : _play();

  void _cycleSpeed() {
    const steps = [1.0, 2.0, 4.0, 8.0];
    final i = steps.indexOf(_speed);
    setState(() => _speed = steps[(i + 1) % steps.length]);
  }

  void _toggleAudioSync() {
    setState(() => _audioSync = !_audioSync);
    if (_audioSync && _playing) {
      _startAudio();
    } else {
      _stopAudio();
    }
  }

  void _toggleTrimMode() {
    if (_playing) _pause();
    if (_trimMode) {
      setState(() {
        _trimMode = false;
        _trimRange = RangeValues(0, (_samples.length - 1).toDouble());
      });
      return;
    }
    setState(() {
      _trimMode = true;
      _trimRange = RangeValues(0, (_samples.length - 1).toDouble());
    });
  }

  void _applyReplayTrim() {
    if (!_trimMode || _samples.length < 3) return;
    final startIndex = _trimRange.start.round();
    final endIndex = _trimRange.end.round();
    if (endIndex - startIndex < 1 ||
        (startIndex == 0 && endIndex == _samples.length - 1)) {
      return;
    }

    final sourceMatchesSnapshot =
        widget.track.samples.length == _samples.length &&
        List<int>.generate(_samples.length, (index) => index).every(
          (index) => identical(widget.track.samples[index], _samples[index]),
        );
    if (!sourceMatchesSnapshot) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).replayTrimUnavailable),
        ),
      );
      return;
    }

    _pause();
    final trimmed = FlightRecorder.instance.trimTrackSamples(
      widget.track,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    if (!trimmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).replayTrimUnavailable),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).flightDetailTrimApplied),
      ),
    );
    Navigator.of(context).pop();
  }

  /// Moves the cursor and feeds the vario-audio preview (when syncing).
  void _setCursor(double ms) {
    final previousIndex = _currentIndex();
    setState(() => _cursorMs = ms.clamp(0.0, _spanMs));
    if (_audioSync && _playing) {
      VarioAudioService.instance.setPreviewSpeed(
        replayGapAt(_gaps, _cursorMs) != null
            ? 0.0
            : _currentSample().data.verticalSpeed,
      );
    }
    if (_currentIndex() != previousIndex) _followCursor();
  }

  // ── Vario audio (preview takeover so it won't fight the live feed) ────────

  void _startAudio() {
    VarioAudioService.instance.beginPreview(
      _currentSample().data.verticalSpeed,
    );
  }

  void _stopAudio() {
    VarioAudioService.instance.endPreview();
  }

  // ── Sample lookup ─────────────────────────────────────────────────────────

  /// The sample at (or just before) the current cursor time.
  FlightSample _currentSample() {
    if (_samples.isEmpty) {
      return FlightSample(time: DateTime.now(), data: FlightData.empty);
    }
    return _samples[_currentIndex()];
  }

  int _currentIndex() {
    if (_samples.isEmpty) return 0;
    var low = 0;
    var high = _sampleOffsetsMs.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (_sampleOffsetsMs[mid] <= _cursorMs) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return (low - 1).clamp(0, _samples.length - 1).toInt();
  }

  // ── Map helpers ─────────────────────────────────────────────────────────

  MapTileSource get _src => MapTileSources.byId(_tileSourceId);

  String _mapSourceLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case 'none':
        return l10n.settingMapSourceNone;
      case 'osm':
        return l10n.settingMapSourceOsm;
      case 'osmfr':
        return l10n.settingMapSourceOsmFr;
      case 'carto-dark':
        return l10n.settingMapSourceCartoDark;
      case 'carto-voyager':
        return l10n.settingMapSourceCartoVoyager;
      case 'amap':
        return l10n.settingMapSourceAmap;
      case 'amap-sat':
        return l10n.settingMapSourceAmapSat;
      default:
        return MapTileSources.byId(id).label;
    }
  }

  LatLng _shift(LatLng wgs) {
    if (OfflineTilesService.instance.isActive || !_src.requiresGcjShift) {
      return wgs;
    }
    final p = Gcj02.wgsToGcj(wgs.latitude, wgs.longitude);
    return LatLng(p[0], p[1]);
  }

  void _followCursor() {
    if (!_ready) return;
    final s = _currentSample();
    if (!s.data.hasFix) return;
    final pos = _shift(LatLng(s.data.latitude, s.data.longitude));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ready) _map.move(pos, _map.camera.zoom);
    });
  }

  LatLng? _firstFix() {
    for (final s in _samples) {
      if (s.data.hasFix) {
        return _shift(LatLng(s.data.latitude, s.data.longitude));
      }
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final offlineActive = OfflineTilesService.instance.isActive;
    final center = _firstFix() ?? _shift(const LatLng(46.5197, 6.6323));
    final cur = _currentSample();
    final hasFix = cur.data.hasFix;
    final activeGap = replayGapAt(_gaps, _cursorMs);

    return SafeArea(
      child: Column(
        children: [
          // Header.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.replayTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showTelemetry
                        ? Icons.monitor_heart
                        : Icons.monitor_heart_outlined,
                  ),
                  tooltip: _showTelemetry ? l10n.close : l10n.dataMonitorTitle,
                  onPressed: () =>
                      setState(() => _showTelemetry = !_showTelemetry),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.layers_outlined),
                  tooltip: l10n.settingMapSource,
                  initialValue: _tileSourceId,
                  onSelected: (id) {
                    if (id == _tileSourceId) return;
                    setState(() => _tileSourceId = id);
                    _fitTrack();
                    _followCursor();
                  },
                  itemBuilder: (context) => [
                    for (final src in MapTileSources.all)
                      PopupMenuItem(
                        value: src.id,
                        child: Text(_mapSourceLabel(l10n, src.id)),
                      ),
                  ],
                ),
                PopupMenuButton<TrackColorMode>(
                  icon: const Icon(Icons.palette_outlined),
                  tooltip: l10n.replayColorBy,
                  initialValue: _colorMode,
                  onSelected: (m) => setState(() => _colorMode = m),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: TrackColorMode.vario,
                      child: Text(l10n.replayColorVario),
                    ),
                    PopupMenuItem(
                      value: TrackColorMode.speed,
                      child: Text(l10n.replayColorSpeed),
                    ),
                    PopupMenuItem(
                      value: TrackColorMode.altitude,
                      child: Text(l10n.replayColorAltitude),
                    ),
                  ],
                ),
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13,
                      minZoom: 2,
                      maxZoom: _src.maxZoom,
                      onMapReady: () {
                        _ready = true;
                        _fitTrack();
                      },
                    ),
                    children: [
                      if (offlineActive || !_src.isNone)
                        TileLayer(
                          key: ValueKey<String>(
                            'replay-$_tileSourceId-${offlineActive ? OfflineTilesService.instance.activeFileName : 'online'}-r${OfflineTilesService.instance.revision.value}',
                          ),
                          tileProvider: _tileProvider,
                          urlTemplate: _src.isNone ? null : _src.urlTemplate,
                          maxNativeZoom: offlineActive
                              ? 19
                              : _src.maxZoom.round(),
                          // Provides a package identity fallback; the shared
                          // map-cache client applies the configured UA.
                          userAgentPackageName: 'com.beacon.parabeacon',
                        ),
                      PolylineLayer(polylines: _buildTrackPolylines()),
                      if (hasFix)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _shift(
                                LatLng(cur.data.latitude, cur.data.longitude),
                              ),
                              width: 34,
                              height: 34,
                              child: _CursorMarker(
                                heading: cur.data.heading,
                                color: activeGap != null
                                    ? replayGapColor
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (activeGap != null)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(child: ReplayGapBanner(gap: activeGap)),
                    ),
                  ),
                // Telemetry follows the current replay sample on every tick/seek.
                if (_showTelemetry)
                  LayoutBuilder(
                    builder: (context, bounds) => Stack(
                      children: [
                        Positioned(
                          left: _telemetryOffset.dx,
                          top: _telemetryOffset.dy,
                          child: _telemetryPanel(theme, cur, bounds),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_samples.length >= 2)
            _AltitudeProfile(
              samples: _samples,
              cursorIndex: _currentIndex(),
              cursorFraction: (_cursorMs / _spanMs).clamp(0.0, 1.0),
              gaps: _gaps,
              gapAfterIndices: _gapAfterIndices,
              spanMs: _spanMs,
              minAlt: _minAlt,
              maxAlt: _maxAlt,
              lineColor: theme.colorScheme.primary,
              fillColor: theme.colorScheme.primary.withAlpha(40),
              cursorColor: theme.colorScheme.secondary,
              gridColor: theme.colorScheme.onSurface.withAlpha(24),
              onSeek: (fraction) => _setCursor(fraction * _spanMs),
            ),
          _buildControls(theme),
        ],
      ),
    );
  }

  double _telemetryPanelWidth(BoxConstraints bounds) {
    final maxWidth = math.max(0.0, bounds.maxWidth - 16);
    final minWidth = math.min(200.0, maxWidth);
    return (_telemetrySize?.width ?? math.min(360.0, maxWidth))
        .clamp(minWidth, maxWidth)
        .toDouble();
  }

  double _telemetryPanelMaxHeight(BoxConstraints bounds, bool minimized) {
    final maxHeight = math.max(0.0, bounds.maxHeight - 16);
    if (minimized) return math.min(60.0, maxHeight);
    final defaultContentHeight = math.min(
      bounds.maxHeight * 0.32,
      MediaQuery.sizeOf(context).height * 0.32,
    );
    final minHeight = math.min(150.0, maxHeight);
    return (_telemetrySize?.height ?? defaultContentHeight + 84)
        .clamp(minHeight, maxHeight)
        .toDouble();
  }

  void _moveTelemetryPanel(Offset delta, BoxConstraints bounds) {
    final maxLeft = math.max(
      0.0,
      bounds.maxWidth - _telemetryPanelWidth(bounds),
    );
    final maxTop = math.max(
      0.0,
      bounds.maxHeight - _telemetryPanelMaxHeight(bounds, _telemetryMinimized),
    );
    setState(() {
      _telemetryOffset = Offset(
        (_telemetryOffset.dx + delta.dx).clamp(0.0, maxLeft).toDouble(),
        (_telemetryOffset.dy + delta.dy).clamp(0.0, maxTop).toDouble(),
      );
    });
  }

  void _resizeTelemetryPanel(Offset delta, BoxConstraints bounds) {
    final maxWidth = math.max(0.0, bounds.maxWidth - 16);
    final maxHeight = math.max(0.0, bounds.maxHeight - 16);
    final minWidth = math.min(200.0, maxWidth);
    final minHeight = math.min(150.0, maxHeight);
    final currentSize = Size(
      _telemetryPanelWidth(bounds),
      _telemetryPanelMaxHeight(bounds, false),
    );
    final nextWidth = (currentSize.width + delta.dx)
        .clamp(minWidth, maxWidth)
        .toDouble();
    final nextHeight = (currentSize.height + delta.dy)
        .clamp(minHeight, maxHeight)
        .toDouble();
    setState(() {
      _telemetrySize = Size(nextWidth, nextHeight);
      _telemetryOffset = Offset(
        _telemetryOffset.dx.clamp(0.0, bounds.maxWidth - nextWidth).toDouble(),
        _telemetryOffset.dy
            .clamp(0.0, bounds.maxHeight - nextHeight)
            .toDouble(),
      );
    });
  }

  void _toggleTelemetryMinimized(BoxConstraints bounds) {
    final minimized = !_telemetryMinimized;
    final maxTop = math.max(
      0.0,
      bounds.maxHeight - _telemetryPanelMaxHeight(bounds, minimized),
    );
    setState(() {
      _telemetryMinimized = minimized;
      _telemetryOffset = Offset(
        _telemetryOffset.dx,
        _telemetryOffset.dy.clamp(0.0, maxTop).toDouble(),
      );
    });
  }

  Widget _telemetryPanel(
    ThemeData theme,
    FlightSample sample,
    BoxConstraints bounds,
  ) {
    final l10n = AppLocalizations.of(context);
    final data = sample.data;
    String optionalNumber(double? value, int decimals) =>
        value == null ? '—' : value.toStringAsFixed(decimals);
    final sampleTime = data.timestamp ?? sample.time;
    final glideRatioValue = data.groundSpeed / 3.6 / -data.verticalSpeed;
    final glideRatio =
        !data.hasFix ||
            data.verticalSpeed >= -0.1 ||
            !glideRatioValue.isFinite ||
            glideRatioValue <= 0
        ? '—'
        : glideRatioValue >= 100
        ? '99+'
        : glideRatioValue.toStringAsFixed(1);
    final altitudeDelta = data.baroAltitude == null || data.gpsAltitude == null
        ? '—'
        : '${data.baroAltitude! >= data.gpsAltitude! ? '+' : ''}${(data.baroAltitude! - data.gpsAltitude!).toStringAsFixed(1)} m';
    final speedMs = data.groundSpeed / 3.6;
    final totalEnergyAltitude =
        (data.altitude + speedMs * speedMs / (2 * 9.80665)).toStringAsFixed(1);
    final metrics = <(String, String)>[
      (l10n.dataMonitorTimestamp, _formatSampleTime(sampleTime)),
      (
        l10n.dataMonitorFix,
        data.hasFix ? l10n.dataMonitorYes : l10n.dataMonitorNo,
      ),
      (
        l10n.dataMonitorVerticalSpeed,
        '${data.verticalSpeed >= 0 ? '+' : ''}${data.verticalSpeed.toStringAsFixed(2)} m/s',
      ),
      (
        l10n.dataMonitorGroundSpeed,
        '${data.groundSpeed.toStringAsFixed(1)} km/h',
      ),
      (l10n.dataMonitorAltitude, '${data.altitude.toStringAsFixed(1)} m'),
      (
        l10n.dataMonitorBaroAltitude,
        '${optionalNumber(data.baroAltitude, 1)} m',
      ),
      (l10n.dataMonitorGpsAltitude, '${optionalNumber(data.gpsAltitude, 1)} m'),
      (l10n.dataMonitorLatitude, '${data.latitude.toStringAsFixed(6)}°'),
      (l10n.dataMonitorLongitude, '${data.longitude.toStringAsFixed(6)}°'),
      (l10n.dataMonitorHeading, '${data.heading.toStringAsFixed(0)}°'),
      (l10n.dataMonitorGpsAccuracy, '${optionalNumber(data.gpsAccuracy, 1)} m'),
      (l10n.dataMonitorSatellites, data.satellites?.toString() ?? '—'),
      (l10n.dataMonitorWindSpeed, '${data.windSpeed.toStringAsFixed(1)} km/h'),
      (
        l10n.dataMonitorWindDirection,
        '${data.windDirection.toStringAsFixed(0)}°',
      ),
      (l10n.dataMonitorPressure, '${optionalNumber(data.pressure, 1)} hPa'),
      (
        l10n.dataMonitorTemperature,
        '${optionalNumber(data.temperature, 1)} °C',
      ),
      (
        l10n.dataMonitorBattery,
        data.battery == null ? '—' : '${data.battery}%',
      ),
      (
        l10n.dataMonitorHeartRate,
        data.heartRate == null ? '—' : '${data.heartRate} bpm',
      ),
    ];
    final derivedMetrics = <(String, String)>[
      (l10n.dataMonitorGlideRatio, glideRatio),
      (l10n.dataMonitorHeading, _cardinal8(data.heading)),
      (
        l10n.dataMonitorWindDir,
        _cardinal8(
          data.windDirection,
          chinese: Localizations.localeOf(context).languageCode == 'zh',
        ),
      ),
      (l10n.dataMonitorBaroGpsDelta, altitudeDelta),
      (l10n.dataMonitorTotalEnergy, '$totalEnergyAltitude m'),
    ];
    final panelWidth = _telemetryPanelWidth(bounds);
    final panelHeight = _telemetryPanelMaxHeight(bounds, _telemetryMinimized);

    return SizedBox(
      width: panelWidth,
      height: panelHeight,
      child: Card(
        color: theme.colorScheme.surface.withAlpha(238),
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) =>
                          _moveTelemetryPanel(details.delta, bounds),
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_indicator,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.monitor_heart_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              l10n.dataMonitorTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.replayTitle,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _telemetryMinimized
                        ? l10n.dataMonitorRestore
                        : l10n.dataMonitorMinimize,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => _toggleTelemetryMinimized(bounds),
                    icon: Icon(
                      _telemetryMinimized ? Icons.open_in_full : Icons.minimize,
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (!_telemetryMinimized) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: metrics.length + derivedMetrics.length + 1,
                    itemBuilder: (context, index) {
                      if (index < metrics.length) {
                        final metric = metrics[index];
                        return _telemetryMetric(
                          theme,
                          metric.$1,
                          metric.$2,
                          index,
                        );
                      }
                      if (index == metrics.length) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 7, 4, 3),
                          child: Text(
                            l10n.dataMonitorDerived.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      final metric = derivedMetrics[index - metrics.length - 1];
                      return _telemetryMetric(
                        theme,
                        metric.$1,
                        metric.$2,
                        index,
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Tooltip(
                    message: l10n.dataMonitorResize,
                    child: Semantics(
                      button: true,
                      label: l10n.dataMonitorResize,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) =>
                            _resizeTelemetryPanel(details.delta, bounds),
                        child: SizedBox(
                          width: 28,
                          height: 20,
                          child: Icon(
                            Icons.south_east,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _telemetryMetric(
    ThemeData theme,
    String label,
    String value,
    int index,
  ) {
    return Container(
      color: index.isEven
          ? Colors.transparent
          : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _cardinal8(double degrees, {bool chinese = false}) {
    const englishLabels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    const chineseLabels = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    final labels = chinese ? chineseLabels : englishLabels;
    final normalized = ((degrees % 360) + 360) % 360;
    return labels[((normalized / 45).round()) % 8];
  }

  String _formatSampleTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  void _updateTrimRange(RangeValues value) {
    final maxIndex = _samples.length - 1;
    final movingStart =
        (value.start - _trimRange.start).abs() >
        (value.end - _trimRange.end).abs();
    var startIndex = value.start.round().clamp(0, maxIndex);
    var endIndex = value.end.round().clamp(0, maxIndex);
    if (endIndex - startIndex < 1) {
      if (movingStart) {
        endIndex = (startIndex + 1).clamp(1, maxIndex);
        startIndex = endIndex - 1;
      } else {
        startIndex = (endIndex - 1).clamp(0, maxIndex - 1);
        endIndex = startIndex + 1;
      }
    }
    setState(() {
      _trimRange = RangeValues(startIndex.toDouble(), endIndex.toDouble());
    });

    if (_playing) _pause();
    final cursorIndex = movingStart ? startIndex : endIndex;
    final cursorMs = _samples[cursorIndex].time
        .difference(_samples.first.time)
        .inMilliseconds
        .toDouble();
    _setCursor(cursorMs);
  }

  Widget _buildControls(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final elapsed = Duration(milliseconds: _cursorMs.round());
    final total = Duration(milliseconds: _spanMs.round());
    final canReplay = _samples.length >= 2;
    final canTrim = _samples.length > 2;
    final maxSampleIndex = math.max(0, _samples.length - 1);
    final firstIndex = _trimRange.start.round().clamp(0, maxSampleIndex);
    final lastIndex = _trimRange.end.round().clamp(0, maxSampleIndex);
    final keptCount = lastIndex - firstIndex + 1;
    final removedCount = _samples.length - keptCount;
    final canApplyTrim =
        canTrim && removedCount > 0 && lastIndex - firstIndex >= 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_trimMode) ...[
            Text(
              l10n.flightDetailTrimDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: _playing ? l10n.replayPause : l10n.replayPlay,
                  visualDensity: VisualDensity.compact,
                  onPressed: canReplay ? _togglePlay : null,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Text(
                    '${_fmt(elapsed)}  |  ${_fmt(total)}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            _ReplayTrimTimeline(
              samples: _samples,
              trimRange: _trimRange,
              cursorFraction: (_cursorMs / _spanMs).clamp(0.0, 1.0),
              spanMs: _spanMs,
              gaps: _gaps,
              gapAfterIndices: _gapAfterIndices,
              minAlt: _minAlt,
              maxAlt: _maxAlt,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              profileColor: theme.colorScheme.primary,
              selectionColor: const Color(0xFFFFC107),
              onTrimChanged: canTrim ? _updateTrimRange : null,
              onSeek: (fraction) => _setCursor(fraction * _spanMs),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.flightDetailTrimFrom(
                        _formatSampleTime(_samples[firstIndex].time),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.flightDetailTrimThrough(
                        _formatSampleTime(_samples[lastIndex].time),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                l10n.flightDetailTrimCounts(keptCount, removedCount),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _toggleTrimMode,
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: canApplyTrim ? _applyReplayTrim : null,
                  icon: const Icon(Icons.content_cut, size: 18),
                  label: Text(l10n.flightDetailTrimApply),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Text(_fmt(elapsed), style: theme.textTheme.labelMedium),
                Expanded(
                  child: replayGapSlider(
                    context: context,
                    gaps: _gaps,
                    spanMs: _spanMs,
                    slider: Slider(
                      value: _spanMs <= 0 ? 0 : _cursorMs.clamp(0.0, _spanMs),
                      max: _spanMs,
                      // Scrubbing keeps the current play/pause state.
                      onChanged: canReplay ? _setCursor : null,
                    ),
                  ),
                ),
                Text(_fmt(total), style: theme.textTheme.labelMedium),
              ],
            ),
            ReplayGapSummary(gaps: _gaps),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay),
                  tooltip: l10n.replayRestart,
                  onPressed: canReplay
                      ? () {
                          _pause();
                          _setCursor(0);
                        }
                      : null,
                ),
                IconButton.filled(
                  iconSize: 32,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                  tooltip: _playing ? l10n.replayPause : l10n.replayPlay,
                  onPressed: canReplay ? _togglePlay : null,
                ),
                TextButton(
                  onPressed: canReplay ? _cycleSpeed : null,
                  child: Text(
                    '${_speed.toStringAsFixed(_speed % 1 == 0 ? 0 : 1)}×',
                  ),
                ),
                IconButton(
                  icon: Icon(_audioSync ? Icons.volume_up : Icons.volume_off),
                  tooltip: _audioSync
                      ? l10n.replayVarioSoundOn
                      : l10n.replayVarioSoundOff,
                  color: _audioSync ? theme.colorScheme.primary : null,
                  onPressed: canReplay ? _toggleAudioSync : null,
                ),
                IconButton(
                  icon: const Icon(Icons.content_cut),
                  tooltip: l10n.flightDetailTrimLog,
                  color: canTrim ? theme.colorScheme.primary : null,
                  onPressed: canTrim ? _toggleTrimMode : null,
                ),
              ],
            ),
            if (!canReplay)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.replayNoPointsMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<LatLng> _trackPoints() {
    if (_cachedTrackPoints != null &&
        _cachedTrackPointsSourceId == _tileSourceId) {
      return _cachedTrackPoints!;
    }
    final points = List<LatLng>.generate(
      _samples.length,
      (index) => _shift(
        LatLng(_samples[index].data.latitude, _samples[index].data.longitude),
      ),
      growable: false,
    );
    _cachedTrackPoints = points;
    _cachedTrackPointsSourceId = _tileSourceId;
    return points;
  }

  /// Fits the map camera to the full track bounds once it's laid out.
  void _fitTrack() {
    final trackPoints = _trackPoints();
    final pts = <LatLng>[
      for (var i = 0; i < _samples.length; i++)
        if (_samples[i].data.hasFix) trackPoints[i],
    ];
    if (pts.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ready) return;
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(48),
        ),
      );
    });
  }

  /// Full track as vario-coloured polyline runs (same 7-level ramp as the live
  /// Map control), with the not-yet-reached portion dimmed.
  List<Polyline> _buildTrackPolylines() {
    if (_samples.length < 2) return const [];
    final curIdx = _currentIndex();
    final cached = _cachedTrackPolylines;
    if (cached != null &&
        _cachedPolylineCursorIndex == curIdx &&
        _cachedPolylineColorMode == _colorMode &&
        _cachedPolylineSourceId == _tileSourceId) {
      return cached;
    }

    final points = _trackPoints();
    final out = <Polyline>[];
    int runStart = _gapAfterIndices.contains(1) ? 1 : 0;
    Color runColor = _segmentColor(
      runStart + 1 < _samples.length ? runStart + 1 : runStart,
      dimmed: runStart + 1 > curIdx,
    );

    void flush(int endExclusive) {
      if (endExclusive - runStart < 2) return;
      out.add(
        Polyline(
          points: [for (int i = runStart; i < endExclusive; i++) points[i]],
          strokeWidth: 3,
          color: runColor,
        ),
      );
    }

    for (int i = 2; i < _samples.length; i++) {
      if (_gapAfterIndices.contains(i)) {
        // Never draw a track line across a missing-data period.
        flush(i);
        runStart = i;
        runColor = _segmentColor(
          math.min(i + 1, _samples.length - 1),
          dimmed: i + 1 > curIdx,
        );
        continue;
      }
      final c = _segmentColor(i, dimmed: i > curIdx);
      if (c != runColor && i - 1 > runStart) {
        flush(i);
        runStart = i - 1; // share the endpoint for visual continuity
        runColor = c;
      } else if (c != runColor) {
        runColor = c;
      }
    }
    flush(_samples.length);
    // Dashed connectors mark where data is missing between two fixes.
    for (final gap in _gaps) {
      final before = _samples[gap.afterIndex - 1];
      final after = _samples[gap.afterIndex];
      if (!before.data.hasFix || !after.data.hasFix) continue;
      out.add(
        Polyline(
          points: [points[gap.afterIndex - 1], points[gap.afterIndex]],
          strokeWidth: 3,
          color: gap.afterIndex > curIdx
              ? replayGapColor.withAlpha(110)
              : replayGapColor,
          pattern: _gapPattern,
        ),
      );
    }
    _cachedTrackPolylines = out;
    _cachedPolylineCursorIndex = curIdx;
    _cachedPolylineColorMode = _colorMode;
    _cachedPolylineSourceId = _tileSourceId;
    return out;
  }

  /// Color for track segment ending at sample [i] under the active color mode.
  Color _segmentColor(int i, {required bool dimmed}) {
    final d = _samples[i].data;
    switch (_colorMode) {
      case TrackColorMode.vario:
        return _varioColor(d.verticalSpeed, dimmed: dimmed);
      case TrackColorMode.speed:
        return _rampColor(d.groundSpeed, _minSpd, _maxSpd, dimmed: dimmed);
      case TrackColorMode.altitude:
        return _rampColor(d.altitude, _minAlt, _maxAlt, dimmed: dimmed);
    }
  }

  /// Blue→red ramp across [min]..[max]; used for the speed & altitude modes.
  Color _rampColor(double v, double min, double max, {required bool dimmed}) {
    final t = (max - min) > 1e-6
        ? ((v - min) / (max - min)).clamp(0.0, 1.0)
        : 0.5;
    final c = Color.lerp(const Color(0xFF3B82F6), const Color(0xFFFF3B30), t)!;
    return dimmed ? c.withAlpha(60) : c;
  }

  /// 7-level vario colour ramp (matches [MapControl]); [dimmed] fades the
  /// portion of the track the replay cursor hasn't reached yet.
  Color _varioColor(double v, {required bool dimmed}) {
    Color c;
    if (v.isNaN) {
      c = const Color(0xFFBAC9CC);
    } else if (v >= 3.0) {
      c = const Color(0xFF13FF43);
    } else if (v >= 1.5) {
      c = const Color(0xFF72FF70);
    } else if (v >= 0.3) {
      c = const Color(0xFFD4FF6A);
    } else if (v > -0.3) {
      c = const Color(0xFFBAC9CC);
    } else if (v > -1.5) {
      c = const Color(0xFF6AB7FF);
    } else if (v > -3.0) {
      c = const Color(0xFF3B82F6);
    } else {
      c = const Color(0xFFFF3B30);
    }
    return dimmed ? c.withAlpha(60) : c;
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

/// A small triangular cursor marker rotated to the sample heading.
class _CursorMarker extends StatelessWidget {
  const _CursorMarker({required this.heading, required this.color});

  final double heading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180.0,
      child: Icon(
        Icons.navigation,
        color: color,
        size: 30,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}

/// A compact altitude-vs-time profile strip shown under the map. Tapping or
/// dragging seeks the replay cursor to that point in the flight.
class _AltitudeProfile extends StatelessWidget {
  const _AltitudeProfile({
    required this.samples,
    required this.cursorIndex,
    required this.cursorFraction,
    required this.gaps,
    required this.gapAfterIndices,
    required this.spanMs,
    required this.minAlt,
    required this.maxAlt,
    required this.lineColor,
    required this.fillColor,
    required this.cursorColor,
    required this.gridColor,
    required this.onSeek,
  });

  final List<FlightSample> samples;
  final int cursorIndex;
  final double cursorFraction;
  final List<ReplayGap> gaps;
  final Set<int> gapAfterIndices;
  final double spanMs;
  final double minAlt;
  final double maxAlt;
  final Color lineColor;
  final Color fillColor;
  final Color cursorColor;
  final Color gridColor;

  /// Called with a 0..1 fraction of the flight when the user taps/drags.
  final void Function(double fraction) onSeek;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void seek(Offset local) {
            final f = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onSeek(f);
          }

          return GestureDetector(
            onTapDown: (d) => seek(d.localPosition),
            onHorizontalDragUpdate: (d) => seek(d.localPosition),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _AltitudeProfilePainter(
                      samples: samples,
                      gaps: gaps,
                      gapAfterIndices: gapAfterIndices,
                      spanMs: spanMs,
                      minAlt: minAlt,
                      maxAlt: maxAlt,
                      lineColor: lineColor,
                      fillColor: fillColor,
                      gridColor: gridColor,
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _AltitudeCursorPainter(
                    samples: samples,
                    cursorIndex: cursorIndex,
                    cursorFraction: cursorFraction,
                    inGap: replayGapAt(gaps, cursorFraction * spanMs) != null,
                    minAlt: minAlt,
                    maxAlt: maxAlt,
                    cursorColor: cursorColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AltitudeProfilePainter extends CustomPainter {
  _AltitudeProfilePainter({
    required this.samples,
    required this.gaps,
    required this.gapAfterIndices,
    required this.spanMs,
    required this.minAlt,
    required this.maxAlt,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<FlightSample> samples;
  final List<ReplayGap> gaps;
  final Set<int> gapAfterIndices;
  final double spanMs;
  final double minAlt;
  final double maxAlt;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    const padTop = 6.0;
    const padBottom = 6.0;
    final h = size.height - padTop - padBottom;
    final span = (maxAlt - minAlt).abs() < 1e-6 ? 1.0 : (maxAlt - minAlt);
    final t0 = samples.first.time;
    final totalMs = math
        .max(1, samples.last.time.difference(t0).inMilliseconds)
        .toDouble();
    final points = <Offset>[
      for (final sample in samples)
        Offset(
          (sample.time.difference(t0).inMilliseconds / totalMs) * size.width,
          padTop +
              h *
                  (1.0 -
                      ((sample.data.altitude - minAlt) / span).clamp(0.0, 1.0)),
        ),
    ];

    canvas.drawLine(
      Offset(0, padTop + h),
      Offset(size.width, padTop + h),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    paintReplayGapBands(
      canvas,
      gaps: gaps,
      spanMs: totalMs,
      left: 0,
      right: size.width,
      top: 0,
      bottom: size.height,
    );

    // One filled area + line per contiguous run; runs break at data gaps.
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = lineColor;
    final areaPaint = Paint()..color = fillColor;
    var runStart = 0;
    void drawRun(int endExclusive) {
      if (endExclusive - runStart < 1) return;
      final first = points[runStart];
      final last = points[endExclusive - 1];
      final area = Path()..moveTo(first.dx, padTop + h);
      final line = Path()..moveTo(first.dx, first.dy);
      for (var i = runStart; i < endExclusive; i++) {
        area.lineTo(points[i].dx, points[i].dy);
        if (i > runStart) line.lineTo(points[i].dx, points[i].dy);
      }
      area
        ..lineTo(last.dx, padTop + h)
        ..close();
      canvas.drawPath(area, areaPaint);
      canvas.drawPath(line, linePaint);
    }

    for (var i = 1; i < points.length; i++) {
      if (gapAfterIndices.contains(i)) {
        drawRun(i);
        runStart = i;
      }
    }
    drawRun(points.length);
  }

  @override
  bool shouldRepaint(covariant _AltitudeProfilePainter old) {
    return old.samples != samples ||
        old.gaps != gaps ||
        old.spanMs != spanMs ||
        old.minAlt != minAlt ||
        old.maxAlt != maxAlt ||
        old.lineColor != lineColor ||
        old.fillColor != fillColor ||
        old.gridColor != gridColor;
  }
}

class _AltitudeCursorPainter extends CustomPainter {
  const _AltitudeCursorPainter({
    required this.samples,
    required this.cursorIndex,
    required this.cursorFraction,
    required this.inGap,
    required this.minAlt,
    required this.maxAlt,
    required this.cursorColor,
  });

  final List<FlightSample> samples;
  final int cursorIndex;
  final double cursorFraction;
  final bool inGap;
  final double minAlt;
  final double maxAlt;
  final Color cursorColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    const padTop = 6.0;
    const padBottom = 6.0;
    final h = size.height - padTop - padBottom;
    final span = (maxAlt - minAlt).abs() < 1e-6 ? 1.0 : (maxAlt - minAlt);
    final t0 = samples.first.time;
    final totalMs = math
        .max(1, samples.last.time.difference(t0).inMilliseconds)
        .toDouble();
    final index = cursorIndex.clamp(0, samples.length - 1);
    final sample = samples[index];
    // Inside a gap the cursor keeps moving with time but has no altitude.
    final x = inGap
        ? cursorFraction.clamp(0.0, 1.0) * size.width
        : (sample.time.difference(t0).inMilliseconds / totalMs) * size.width;
    final color = inGap ? replayGapColor : cursorColor;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, padTop), Offset(x, padTop + h), paint);
    if (inGap) return;
    final norm = (sample.data.altitude - minAlt) / span;
    final y = padTop + h * (1.0 - norm.clamp(0.0, 1.0));
    canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AltitudeCursorPainter old) =>
      old.samples != samples ||
      old.cursorIndex != cursorIndex ||
      old.cursorFraction != cursorFraction ||
      old.inGap != inGap ||
      old.minAlt != minAlt ||
      old.maxAlt != maxAlt ||
      old.cursorColor != cursorColor;
}

enum _TrimDragTarget { start, end, cursor }

class _ReplayTrimTimeline extends StatefulWidget {
  const _ReplayTrimTimeline({
    required this.samples,
    required this.trimRange,
    required this.cursorFraction,
    required this.spanMs,
    required this.gaps,
    required this.gapAfterIndices,
    required this.minAlt,
    required this.maxAlt,
    required this.backgroundColor,
    required this.profileColor,
    required this.selectionColor,
    required this.onTrimChanged,
    required this.onSeek,
  });

  final List<FlightSample> samples;
  final RangeValues trimRange;
  final double cursorFraction;
  final double spanMs;
  final List<ReplayGap> gaps;
  final Set<int> gapAfterIndices;
  final double minAlt;
  final double maxAlt;
  final Color backgroundColor;
  final Color profileColor;
  final Color selectionColor;
  final ValueChanged<RangeValues>? onTrimChanged;
  final ValueChanged<double> onSeek;

  @override
  State<_ReplayTrimTimeline> createState() => _ReplayTrimTimelineState();
}

class _ReplayTrimTimelineState extends State<_ReplayTrimTimeline> {
  static const double _horizontalInset = 9;
  _TrimDragTarget _dragTarget = _TrimDragTarget.cursor;

  double _fractionForIndex(double index) {
    if (widget.samples.length < 2 || widget.spanMs <= 0) return 0;
    final safeIndex = index.round().clamp(0, widget.samples.length - 1);
    final elapsed = widget.samples[safeIndex].time
        .difference(widget.samples.first.time)
        .inMilliseconds
        .toDouble();
    return (elapsed / widget.spanMs).clamp(0.0, 1.0);
  }

  double _fractionAtX(double x, double width) {
    final usableWidth = math.max(1.0, width - 2 * _horizontalInset);
    return ((x - _horizontalInset) / usableWidth).clamp(0.0, 1.0);
  }

  double _xForFraction(double fraction, double width) {
    return _horizontalInset +
        fraction.clamp(0.0, 1.0) * (width - 2 * _horizontalInset);
  }

  int _nearestSampleIndex(double fraction) {
    final targetMs = fraction.clamp(0.0, 1.0) * widget.spanMs;
    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < widget.samples.length; i++) {
      final sampleMs = widget.samples[i].time
          .difference(widget.samples.first.time)
          .inMilliseconds
          .toDouble();
      final distance = (sampleMs - targetMs).abs();
      if (distance < nearestDistance) {
        nearest = i;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  void _startDrag(DragStartDetails details, double width) {
    final x = details.localPosition.dx;
    final startX = _xForFraction(
      _fractionForIndex(widget.trimRange.start),
      width,
    );
    final endX = _xForFraction(_fractionForIndex(widget.trimRange.end), width);
    final startDistance = (x - startX).abs();
    final endDistance = (x - endX).abs();
    if (startDistance <= 24 && startDistance <= endDistance) {
      _dragTarget = _TrimDragTarget.start;
    } else if (endDistance <= 24) {
      _dragTarget = _TrimDragTarget.end;
    } else {
      _dragTarget = _TrimDragTarget.cursor;
      widget.onSeek(_fractionAtX(x, width));
    }
  }

  void _updateDrag(DragUpdateDetails details, double width) {
    final fraction = _fractionAtX(details.localPosition.dx, width);
    if (_dragTarget == _TrimDragTarget.cursor) {
      widget.onSeek(fraction);
      return;
    }

    final onTrimChanged = widget.onTrimChanged;
    if (onTrimChanged == null) return;
    final index = _nearestSampleIndex(fraction);
    final start = widget.trimRange.start.round();
    final end = widget.trimRange.end.round();
    if (_dragTarget == _TrimDragTarget.start) {
      final nextStart = index.clamp(0, end - 1).toDouble();
      onTrimChanged(RangeValues(nextStart, end.toDouble()));
    } else {
      final nextEnd = index
          .clamp(start + 1, widget.samples.length - 1)
          .toDouble();
      onTrimChanged(RangeValues(start.toDouble(), nextEnd));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('replay-trim-timeline'),
      height: 76,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cursorX = _xForFraction(widget.cursorFraction, width);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => widget.onSeek(
                    _fractionAtX(details.localPosition.dx, width),
                  ),
                  onHorizontalDragStart: (details) =>
                      _startDrag(details, width),
                  onHorizontalDragUpdate: (details) =>
                      _updateDrag(details, width),
                  child: CustomPaint(
                    painter: _ReplayTrimTimelinePainter(
                      samples: widget.samples,
                      trimRange: widget.trimRange,
                      spanMs: widget.spanMs,
                      gaps: widget.gaps,
                      gapAfterIndices: widget.gapAfterIndices,
                      minAlt: widget.minAlt,
                      maxAlt: widget.maxAlt,
                      backgroundColor: widget.backgroundColor,
                      profileColor: widget.profileColor,
                      selectionColor: widget.selectionColor,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: cursorX - 1,
                top: -12,
                child: IgnorePointer(
                  child: Container(
                    width: 2,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReplayTrimTimelinePainter extends CustomPainter {
  _ReplayTrimTimelinePainter({
    required this.samples,
    required this.trimRange,
    required this.spanMs,
    required this.gaps,
    required this.gapAfterIndices,
    required this.minAlt,
    required this.maxAlt,
    required this.backgroundColor,
    required this.profileColor,
    required this.selectionColor,
  });

  final List<FlightSample> samples;
  final RangeValues trimRange;
  final double spanMs;
  final List<ReplayGap> gaps;
  final Set<int> gapAfterIndices;
  final double minAlt;
  final double maxAlt;
  final Color backgroundColor;
  final Color profileColor;
  final Color selectionColor;

  double _fractionForIndex(int index) {
    if (samples.length < 2 || spanMs <= 0) return 0;
    final elapsed = samples[index].time
        .difference(samples.first.time)
        .inMilliseconds
        .toDouble();
    return (elapsed / spanMs).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2 || size.width <= 0 || size.height <= 0) return;
    const inset = 9.0;
    final timeline = Rect.fromLTRB(
      inset,
      2,
      size.width - inset,
      size.height - 2,
    );
    final roundedTimeline = RRect.fromRectAndRadius(
      timeline,
      const Radius.circular(10),
    );
    canvas.drawRRect(roundedTimeline, Paint()..color = backgroundColor);
    canvas.save();
    canvas.clipRRect(roundedTimeline);

    final width = timeline.width;
    final height = timeline.height;
    double xForFraction(double fraction) =>
        timeline.left + fraction.clamp(0.0, 1.0) * width;
    final startX = xForFraction(_fractionForIndex(trimRange.start.round()));
    final endX = xForFraction(_fractionForIndex(trimRange.end.round()));

    final divisions = math.min(8, math.max(1, samples.length - 1));
    for (var i = 1; i < divisions; i++) {
      final x = timeline.left + width * i / divisions;
      canvas.drawLine(
        Offset(x, timeline.top),
        Offset(x, timeline.bottom),
        Paint()
          ..color = Colors.white.withAlpha(20)
          ..strokeWidth = 1,
      );
    }

    final altitudeSpan = (maxAlt - minAlt).abs() < 1e-6 ? 1.0 : maxAlt - minAlt;
    final points = <Offset>[];
    for (var i = 0; i < samples.length; i++) {
      final fraction = _fractionForIndex(i);
      final normalized = ((samples[i].data.altitude - minAlt) / altitudeSpan)
          .clamp(0.0, 1.0);
      points.add(
        Offset(
          xForFraction(fraction),
          timeline.top + 8 + (height - 16) * (1 - normalized),
        ),
      );
    }

    paintReplayGapBands(
      canvas,
      gaps: gaps,
      spanMs: spanMs,
      left: timeline.left,
      right: timeline.right,
      top: timeline.top,
      bottom: timeline.bottom,
    );

    final profileFill = Paint()..color = profileColor.withAlpha(65);
    final profileStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = profileColor;
    var runStart = 0;
    void drawRun(int endExclusive) {
      if (endExclusive - runStart < 1) return;
      final area = Path()..moveTo(points[runStart].dx, timeline.bottom);
      final profile = Path()..moveTo(points[runStart].dx, points[runStart].dy);
      for (var i = runStart; i < endExclusive; i++) {
        area.lineTo(points[i].dx, points[i].dy);
        if (i > runStart) profile.lineTo(points[i].dx, points[i].dy);
      }
      area
        ..lineTo(points[endExclusive - 1].dx, timeline.bottom)
        ..close();
      canvas.drawPath(area, profileFill);
      canvas.drawPath(profile, profileStroke);
    }

    for (var i = 1; i < points.length; i++) {
      if (gapAfterIndices.contains(i)) {
        drawRun(i);
        runStart = i;
      }
    }
    drawRun(points.length);

    final outsidePaint = Paint()..color = Colors.black.withAlpha(92);
    if (startX > timeline.left) {
      canvas.drawRect(
        Rect.fromLTRB(timeline.left, timeline.top, startX, timeline.bottom),
        outsidePaint,
      );
    }
    if (endX < timeline.right) {
      canvas.drawRect(
        Rect.fromLTRB(endX, timeline.top, timeline.right, timeline.bottom),
        outsidePaint,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(startX, timeline.top, endX, timeline.bottom),
      Paint()..color = selectionColor.withAlpha(28),
    );

    final handlePaint = Paint()..color = selectionColor;
    for (final x in [startX, endX]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, timeline.center.dy),
            width: 6,
            height: 34,
          ),
          const Radius.circular(3),
        ),
        handlePaint,
      );
      canvas.drawLine(
        Offset(x - 1.5, timeline.center.dy - 4),
        Offset(x + 1.5, timeline.center.dy - 4),
        Paint()
          ..color = Colors.black.withAlpha(100)
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        Offset(x - 1.5, timeline.center.dy + 4),
        Offset(x + 1.5, timeline.center.dy + 4),
        Paint()
          ..color = Colors.black.withAlpha(100)
          ..strokeWidth = 1,
      );
    }

    canvas.drawRRect(
      roundedTimeline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = selectionColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReplayTrimTimelinePainter old) {
    return old.samples != samples ||
        old.trimRange != trimRange ||
        old.spanMs != spanMs ||
        old.gaps != gaps ||
        old.minAlt != minAlt ||
        old.maxAlt != maxAlt ||
        old.backgroundColor != backgroundColor ||
        old.profileColor != profileColor ||
        old.selectionColor != selectionColor;
  }
}
