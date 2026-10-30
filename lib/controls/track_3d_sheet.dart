import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/vario_audio_service.dart';
import '../data/flight_data.dart';
import '../data/flight_recorder.dart';
import '../data/track_3d_settings.dart';
import '../l10n/app_localizations.dart';
import 'replay_gaps.dart';
import 'track_3d_map.dart';
import 'track_3d_painter.dart';

/// Opens a 3D replay of a completed [track] as a full-screen sheet.
///
/// The track is rendered as a projected 3D polyline (X/Y ground plane, Z =
/// altitude) that the user can orbit (single-finger drag) and zoom (pinch or
/// mouse wheel). A playback cursor animates along the track with optional
/// vario-audio sync, mirroring [showFlightReplaySheet].
///
/// Only flights that still carry per-sample data can be replayed; the caller
/// should gate the entry point on [FlightTrack.hasSamples].
Future<void> showTrack3DSheet(BuildContext context, FlightTrack track) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (context) => _Track3DSheet(track: track),
  );
}

class _Track3DSheet extends StatefulWidget {
  const _Track3DSheet({required this.track});

  final FlightTrack track;

  @override
  State<_Track3DSheet> createState() => _Track3DSheetState();
}

class _Track3DSheetState extends State<_Track3DSheet>
    with SingleTickerProviderStateMixin {
  late final List<FlightSample> _samples;
  late final List<double> _sampleOffsetsMs;
  late final Track3DGeometryCache _geometryCache;
  late final Ticker _ticker;
  Track3DGroundMap? _groundMap;
  bool _loadingGroundMap = false;

  /// Missing-data periods (e.g. ground time between merged flights).
  late final List<ReplayGap> _gaps;
  late final Set<int> _gapAfterIndices;

  // Camera orientation.
  double _yaw = -0.6; // radians, around the vertical (Z) axis
  double _pitch = 0.9; // radians, tilt toward the horizon
  double _zScale = 1.0; // vertical exaggeration
  double _zoom = 1.0; // uniform scene zoom (0.5 .. 4.0)

  // Playback.
  double _cursorMs = 0.0;
  late final double _spanMs;
  Duration? _lastTick;
  bool _playing = false;
  double _speed = 1.0;
  bool _audioSync = false;

  @override
  void initState() {
    super.initState();
    _samples = List<FlightSample>.of(widget.track.samples);
    final first = _samples.isNotEmpty ? _samples.first.time : DateTime.now();
    _sampleOffsetsMs = [
      for (final sample in _samples)
        sample.time.difference(first).inMilliseconds.toDouble(),
    ];
    _spanMs = math.max(
      1.0,
      _sampleOffsetsMs.isEmpty ? 0.0 : _sampleOffsetsMs.last,
    );
    _geometryCache = Track3DGeometryCache(_samples);
    _gaps = replayGapsFor(widget.track, _samples);
    _gapAfterIndices = {for (final gap in _gaps) gap.afterIndex};
    _ticker = createTicker(_onTick);
    Track3DSettings.instance.addListener(_onTrack3DSettingsChanged);
    if (Track3DSettings.instance.showGroundMap) {
      unawaited(_loadGroundMap());
    }
  }

  @override
  void dispose() {
    Track3DSettings.instance.removeListener(_onTrack3DSettingsChanged);
    _groundMap?.dispose();
    _stopAudio();
    _ticker.dispose();
    super.dispose();
  }

  void _onTrack3DSettingsChanged() {
    if (!mounted) return;
    setState(() {});
    if (Track3DSettings.instance.showGroundMap &&
        _groundMap == null &&
        !_loadingGroundMap) {
      unawaited(_loadGroundMap());
    }
  }

  Future<void> _loadGroundMap() async {
    if (_loadingGroundMap || !Track3DSettings.instance.showGroundMap) return;
    _loadingGroundMap = true;
    Track3DGroundMap? loadedMap;
    try {
      loadedMap = await Track3DGroundMap.load(_samples);
    } catch (_) {
      // The replay remains usable when map tiles are unavailable.
    }
    if (!mounted) {
      loadedMap?.dispose();
      return;
    }
    setState(() {
      _groundMap = loadedMap;
      _loadingGroundMap = false;
    });
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dtMs = (elapsed - last).inMicroseconds / 1000.0;
    if (dtMs <= 0) return;
    final next = _cursorMs + dtMs * replaySpeedAt(_gaps, _cursorMs, _speed);
    if (next >= _spanMs) {
      _setCursor(_spanMs);
      _pause();
      return;
    }
    _setCursor(next);
  }

  void _play() {
    if (_playing || _samples.length < 2) return;
    if (_cursorMs >= _spanMs) _cursorMs = 0.0;
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
    const steps = [1.0, 2.0, 4.0, 8.0, 16.0];
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

  void _setCursor(double ms) {
    setState(() => _cursorMs = ms.clamp(0.0, _spanMs));
    if (_audioSync && _playing) {
      VarioAudioService.instance.setPreviewSpeed(
        replayGapAt(_gaps, _cursorMs) != null
            ? 0.0
            : _currentSample().data.verticalSpeed,
      );
    }
  }

  void _startAudio() => VarioAudioService.instance.beginPreview(
    _currentSample().data.verticalSpeed,
  );
  void _stopAudio() => VarioAudioService.instance.endPreview();

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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canReplay = _samples.length >= 2;
    final cur = _currentSample();
    final activeGap = replayGapAt(_gaps, _cursorMs);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.threed_rotation, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.replay3dTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  tooltip: l10n.replay3dResetView,
                  onPressed: () => setState(() {
                    _yaw = -0.6;
                    _pitch = 0.9;
                    _zScale = 1.0;
                    _zoom = 1.0;
                  }),
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
                  child: _GestureCanvas(
                    yaw: _yaw,
                    pitch: _pitch,
                    zScale: _zScale,
                    zoom: _zoom,
                    groundMap: Track3DSettings.instance.showGroundMap
                        ? _groundMap
                        : null,
                    samples: _samples,
                    cursorIndex: _currentIndex(),
                    geometryCache: _geometryCache,
                    gapAfterIndices: _gapAfterIndices,
                    cursorInGap: activeGap != null,
                    onOrbit: (dx, dy) => setState(() {
                      _yaw += dx * 0.01;
                      _pitch = (_pitch + dy * 0.01).clamp(0.15, 1.45);
                    }),
                    onZoom: (factor) => setState(() {
                      _zoom = (_zoom * factor).clamp(0.5, 4.0);
                    }),
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
              ],
            ),
          ),
          const Divider(height: 1),
          _readout(theme, cur, inGap: activeGap != null),
          _controls(theme, canReplay),
        ],
      ),
    );
  }

  Widget _readout(ThemeData theme, FlightSample s, {bool inGap = false}) {
    final l10n = AppLocalizations.of(context);
    final d = s.data;
    final v = d.verticalSpeed;
    final noData = l10n.replayDataGapNoData;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat(
            theme,
            l10n.replay3dStatAlt,
            inGap ? noData : '${d.altitude.round()} m',
          ),
          _stat(
            theme,
            l10n.replay3dStatSpd,
            inGap ? noData : '${d.groundSpeed.toStringAsFixed(0)} km/h',
          ),
          _stat(
            theme,
            l10n.replay3dStatVario,
            inGap ? noData : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} m/s',
          ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }

  Widget _controls(ThemeData theme, bool canReplay) {
    final l10n = AppLocalizations.of(context);
    final elapsed = Duration(milliseconds: _cursorMs.round());
    final total = Duration(milliseconds: _spanMs.round());
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            ],
          ),
          if (!canReplay)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'This flight has no recorded track points to replay.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

/// Handles orbit (single-finger drag) and whole-scene zoom (pinch or mouse
/// wheel) over the 3D [Track3DPainter].
class _GestureCanvas extends StatefulWidget {
  const _GestureCanvas({
    required this.yaw,
    required this.pitch,
    required this.zScale,
    required this.zoom,
    required this.groundMap,
    required this.samples,
    required this.cursorIndex,
    required this.geometryCache,
    required this.gapAfterIndices,
    required this.cursorInGap,
    required this.onOrbit,
    required this.onZoom,
  });

  final double yaw;
  final double pitch;
  final double zScale;
  final double zoom;
  final Track3DGroundMap? groundMap;
  final List<FlightSample> samples;
  final int cursorIndex;
  final Track3DGeometryCache geometryCache;
  final Set<int> gapAfterIndices;
  final bool cursorInGap;
  final void Function(double dx, double dy) onOrbit;
  final void Function(double factor) onZoom;

  @override
  State<_GestureCanvas> createState() => _GestureCanvasState();
}

class _GestureCanvasState extends State<_GestureCanvas> {
  double _lastScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          widget.onZoom(math.exp(-event.scrollDelta.dy * 0.0015));
        }
      },
      child: GestureDetector(
        onScaleStart: (_) => _lastScale = 1.0,
        onScaleUpdate: (d) {
          if (d.pointerCount >= 2) {
            final factor = d.scale / (_lastScale == 0 ? 1 : _lastScale);
            _lastScale = d.scale;
            widget.onZoom(factor);
          } else {
            widget.onOrbit(d.focalPointDelta.dx, d.focalPointDelta.dy);
          }
        },
        child: CustomPaint(
          painter: Track3DPainter(
            samples: widget.samples,
            yaw: widget.yaw,
            pitch: widget.pitch,
            zScale: widget.zScale,
            zoom: widget.zoom,
            groundMap: widget.groundMap,
            cursorIndex: widget.cursorIndex,
            geometryCache: widget.geometryCache,
            gapAfterIndices: widget.gapAfterIndices,
            cursorInGap: widget.cursorInGap,
            gapColor: replayGapColor,
            gridColor: theme.colorScheme.onSurface.withAlpha(64),
            background: theme.colorScheme.surface,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
