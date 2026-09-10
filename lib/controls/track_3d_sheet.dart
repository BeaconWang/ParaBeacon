import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/vario_audio_service.dart';
import '../data/flight_data.dart';
import '../data/flight_recorder.dart';
import '../l10n/app_localizations.dart';
import 'track_3d_painter.dart';

/// Opens a 3D replay of a completed [track] as a full-screen sheet.
///
/// The track is rendered as a projected 3D polyline (X/Y ground plane, Z =
/// altitude) that the user can orbit (single-finger drag) and vertically
/// exaggerate (pinch). A playback cursor animates along the track with optional
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
  late final Ticker _ticker;

  // Camera orientation.
  double _yaw = -0.6; // radians, around the vertical (Z) axis
  double _pitch = 0.9; // radians, tilt toward the horizon
  double _zScale = 1.0; // vertical exaggeration (0.1 .. 3.0)

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
    final last = _samples.isNotEmpty ? _samples.last.time : first;
    _spanMs = math.max(1.0, last.difference(first).inMilliseconds.toDouble());
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _stopAudio();
    _ticker.dispose();
    super.dispose();
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dtMs = (elapsed - last).inMicroseconds / 1000.0;
    if (dtMs <= 0) return;
    final next = _cursorMs + dtMs * _speed;
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
      VarioAudioService.instance
          .setPreviewSpeed(_currentSample().data.verticalSpeed);
    }
  }

  void _startAudio() =>
      VarioAudioService.instance.beginPreview(_currentSample().data.verticalSpeed);
  void _stopAudio() => VarioAudioService.instance.endPreview();

  FlightSample _currentSample() {
    if (_samples.isEmpty) {
      return FlightSample(time: DateTime.now(), data: FlightData.empty);
    }
    final t0 = _samples.first.time;
    var idx = 0;
    for (var i = 0; i < _samples.length; i++) {
      final rel = _samples[i].time.difference(t0).inMilliseconds.toDouble();
      if (rel <= _cursorMs) {
        idx = i;
      } else {
        break;
      }
    }
    return _samples[idx];
  }

  int _currentIndex() {
    if (_samples.isEmpty) return 0;
    final t0 = _samples.first.time;
    var idx = 0;
    for (var i = 0; i < _samples.length; i++) {
      final rel = _samples[i].time.difference(t0).inMilliseconds.toDouble();
      if (rel <= _cursorMs) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canReplay = _samples.length >= 2;
    final cur = _currentSample();

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
                  child: Text(l10n.replay3dTitle,
                      style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  tooltip: l10n.replay3dResetView,
                  onPressed: () => setState(() {
                    _yaw = -0.6;
                    _pitch = 0.9;
                    _zScale = 1.0;
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
            child: _GestureCanvas(
              yaw: _yaw,
              pitch: _pitch,
              zScale: _zScale,
              samples: _samples,
              cursorIndex: _currentIndex(),
              onOrbit: (dx, dy) => setState(() {
                _yaw += dx * 0.01;
                _pitch = (_pitch + dy * 0.01).clamp(0.15, 1.45);
              }),
              onZoom: (factor) => setState(() {
                _zScale = (_zScale * factor).clamp(0.1, 3.0);
              }),
            ),
          ),
          const Divider(height: 1),
          _readout(theme, cur),
          _controls(theme, canReplay),
        ],
      ),
    );
  }

  Widget _readout(ThemeData theme, FlightSample s) {
    final l10n = AppLocalizations.of(context);
    final d = s.data;
    final v = d.verticalSpeed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat(theme, l10n.replay3dStatAlt, '${d.altitude.round()} m'),
          _stat(theme, l10n.replay3dStatSpd,
              '${d.groundSpeed.toStringAsFixed(0)} km/h'),
          _stat(theme, l10n.replay3dStatVario,
              '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} m/s'),
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                child: Slider(
                  value: _spanMs <= 0 ? 0 : _cursorMs.clamp(0.0, _spanMs),
                  max: _spanMs,
                  onChanged: canReplay
                      ? (v) {
                          if (_playing) _pause();
                          _setCursor(v);
                        }
                      : null,
                ),
              ),
              Text(_fmt(total), style: theme.textTheme.labelMedium),
            ],
          ),
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
                    '${_speed.toStringAsFixed(_speed % 1 == 0 ? 0 : 1)}×'),
              ),
              IconButton(
                icon: Icon(_audioSync ? Icons.volume_up : Icons.volume_off),
                tooltip:
                    _audioSync ? l10n.replayVarioSoundOn : l10n.replayVarioSoundOff,
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
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

/// Handles orbit (single-finger drag) and vertical-exaggeration (pinch)
/// gestures over the 3D [Track3DPainter].
class _GestureCanvas extends StatefulWidget {
  const _GestureCanvas({
    required this.yaw,
    required this.pitch,
    required this.zScale,
    required this.samples,
    required this.cursorIndex,
    required this.onOrbit,
    required this.onZoom,
  });

  final double yaw;
  final double pitch;
  final double zScale;
  final List<FlightSample> samples;
  final int cursorIndex;
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
    return GestureDetector(
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
          cursorIndex: widget.cursorIndex,
          gridColor: theme.colorScheme.onSurface.withAlpha(30),
          background: theme.colorScheme.surface,
        ),
        size: Size.infinite,
      ),
    );
  }
}
