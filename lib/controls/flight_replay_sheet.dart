import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../audio/vario_audio_service.dart';
import '../data/flight_data.dart';
import '../data/flight_recorder.dart';
import '../data/gcj02.dart';
import '../l10n/app_localizations.dart';
import 'map_control.dart' show MapTileSources, MapTileSource;

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
  /// Tile source used for the replay basemap. A neutral online source keeps the
  /// screen self-contained without depending on the live Map control's config.
  static const String _tileSourceId = 'osm';

  final MapController _map = MapController();

  late final Ticker _ticker;
  bool _ready = false;

  /// Playback cursor in **track-relative milliseconds** (0 == first sample).
  double _cursorMs = 0.0;

  /// Total track span in milliseconds (>= 1 to avoid divide-by-zero).
  late final double _spanMs;

  /// Wall-clock timestamp (ms since epoch, from the ticker) of the previous
  /// frame, used to advance [_cursorMs] by real elapsed time × [_speed].
  Duration? _lastTick;

  bool _playing = false;
  double _speed = 1.0;
  bool _audioSync = false;

  /// Active track-coloring mode (affects the map polyline and profile chart).
  TrackColorMode _colorMode = TrackColorMode.vario;

  // Track-wide extrema for the speed/altitude color ramps (computed once).
  double _minAlt = 0, _maxAlt = 0, _minSpd = 0, _maxSpd = 0;

  /// The samples we replay, captured once so the list can't change under us.
  late final List<FlightSample> _samples;

  @override
  void initState() {
    super.initState();
    _samples = List<FlightSample>.of(widget.track.samples);
    final first = _samples.isNotEmpty ? _samples.first.time : DateTime.now();
    final last = _samples.isNotEmpty ? _samples.last.time : first;
    _spanMs = math.max(1.0, last.difference(first).inMilliseconds.toDouble());
    _computeExtrema();
    _ticker = createTicker(_onTick);
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
    _stopAudio();
    _ticker.dispose();
    super.dispose();
  }

  // ── Playback engine ─────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dtMs = (elapsed - last).inMicroseconds / 1000.0;
    if (dtMs <= 0) return;

    var next = _cursorMs + dtMs * _speed;
    if (next >= _spanMs) {
      next = _spanMs;
      _setCursor(next);
      _pause(); // reached the end
      return;
    }
    _setCursor(next);
  }

  void _play() {
    if (_playing || _samples.length < 2) return;
    // Restart from the beginning if we're parked at the end.
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

  /// Moves the cursor and feeds the vario-audio preview (when syncing).
  void _setCursor(double ms) {
    setState(() => _cursorMs = ms.clamp(0.0, _spanMs));
    if (_audioSync && _playing) {
      VarioAudioService.instance.setPreviewSpeed(_currentSample().data.verticalSpeed);
    }
    _followCursor();
  }

  // ── Vario audio (preview takeover so it won't fight the live feed) ────────

  void _startAudio() {
    VarioAudioService.instance.beginPreview(_currentSample().data.verticalSpeed);
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
    final t0 = _samples.first.time;
    final targetMs = _cursorMs;
    // Linear scan is fine: tracks are decimated and the cursor advances
    // monotonically; binary search would be premature optimization here.
    var idx = 0;
    for (var i = 0; i < _samples.length; i++) {
      final rel = _samples[i].time.difference(t0).inMilliseconds.toDouble();
      if (rel <= targetMs) {
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

  // ── Map helpers ─────────────────────────────────────────────────────────

  MapTileSource get _src => MapTileSources.byId(_tileSourceId);

  LatLng _shift(LatLng wgs) {
    if (!_src.requiresGcjShift) return wgs;
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
      if (s.data.hasFix) return _shift(LatLng(s.data.latitude, s.data.longitude));
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final center = _firstFix() ?? _shift(const LatLng(46.5197, 6.6323));
    final cur = _currentSample();
    final hasFix = cur.data.hasFix;

    return SafeArea(
      child: Column(
        children: [
          // Header.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.replayTitle,
                      style: theme.textTheme.titleLarge),
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
                      TileLayer(
                        urlTemplate: _src.urlTemplate,
                        maxNativeZoom: _src.maxZoom.round(),
                        // Rely on flutter_map's own User-Agent (formatted from
                        // this package name) rather than a custom
                        // NetworkTileProvider(headers:). Passing a `const`
                        // headers map threw "Cannot modify unmodifiable map"
                        // (flutter_map merges into it), and a custom UA is also
                        // silently dropped on Android — see MapControl's note.
                        userAgentPackageName: 'com.beacon.parabeacon',
                      ),
                      PolylineLayer(polylines: _buildTrackPolylines()),
                      if (hasFix)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _shift(LatLng(
                                  cur.data.latitude, cur.data.longitude)),
                              width: 34,
                              height: 34,
                              child: _CursorMarker(
                                heading: cur.data.heading,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Live readout for the current cursor time.
                Positioned(
                  left: 8,
                  top: 8,
                  child: _readoutChip(theme, cur),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_samples.length >= 2)
            _AltitudeProfile(
              samples: _samples,
              cursorIndex: _currentIndex(),
              minAlt: _minAlt,
              maxAlt: _maxAlt,
              lineColor: theme.colorScheme.primary,
              fillColor: theme.colorScheme.primary.withAlpha(40),
              cursorColor: theme.colorScheme.secondary,
              gridColor: theme.colorScheme.onSurface.withAlpha(24),
              onSeek: (fraction) {
                if (_playing) _pause();
                _setCursor(fraction * _spanMs);
              },
            ),
          _buildControls(theme),
        ],
      ),
    );
  }

  Widget _readoutChip(ThemeData theme, FlightSample s) {
    final l10n = AppLocalizations.of(context);
    final d = s.data;
    final vario = d.verticalSpeed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l10n.replayReadout(
          '${d.heading.round()}',
          '${d.altitude.round()}',
          '${vario >= 0 ? '+' : ''}${vario.toStringAsFixed(1)}',
        ),
        style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final elapsed = Duration(milliseconds: _cursorMs.round());
    final total = Duration(milliseconds: _spanMs.round());
    final canReplay = _samples.length >= 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                          // Scrubbing pauses playback for precise positioning.
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
                child: Text('${_speed.toStringAsFixed(_speed % 1 == 0 ? 0 : 1)}×'),
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
                l10n.replayNoPointsMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Fits the map camera to the full track bounds once it's laid out.
  void _fitTrack() {
    final pts = <LatLng>[
      for (final s in _samples)
        if (s.data.hasFix)
          _shift(LatLng(s.data.latitude, s.data.longitude)),
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

    LatLng at(int i) => _shift(
        LatLng(_samples[i].data.latitude, _samples[i].data.longitude));

    final out = <Polyline>[];
    int runStart = 0;
    Color runColor = _segmentColor(1, dimmed: 1 > curIdx);

    void flush(int endExclusive) {
      if (endExclusive - runStart < 2) return;
      out.add(Polyline(
        points: [for (int i = runStart; i < endExclusive; i++) at(i)],
        strokeWidth: 3,
        color: runColor,
      ));
    }

    for (int i = 2; i < _samples.length; i++) {
      final c = _segmentColor(i, dimmed: i > curIdx);
      if (c != runColor) {
        flush(i);
        runStart = i - 1; // share the endpoint for visual continuity
        runColor = c;
      }
    }
    flush(_samples.length);
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
    final t = (max - min) > 1e-6 ? ((v - min) / (max - min)).clamp(0.0, 1.0) : 0.5;
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
      child: Icon(Icons.navigation, color: color, size: 30, shadows: const [
        Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
      ]),
    );
  }
}

/// A compact altitude-vs-time profile strip shown under the map. Tapping or
/// dragging seeks the replay cursor to that point in the flight.
class _AltitudeProfile extends StatelessWidget {
  const _AltitudeProfile({
    required this.samples,
    required this.cursorIndex,
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
            child: CustomPaint(
              size: Size.infinite,
              painter: _AltitudeProfilePainter(
                samples: samples,
                cursorIndex: cursorIndex,
                minAlt: minAlt,
                maxAlt: maxAlt,
                lineColor: lineColor,
                fillColor: fillColor,
                cursorColor: cursorColor,
                gridColor: gridColor,
              ),
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
    required this.cursorIndex,
    required this.minAlt,
    required this.maxAlt,
    required this.lineColor,
    required this.fillColor,
    required this.cursorColor,
    required this.gridColor,
  });

  final List<FlightSample> samples;
  final int cursorIndex;
  final double minAlt;
  final double maxAlt;
  final Color lineColor;
  final Color fillColor;
  final Color cursorColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    const padTop = 6.0;
    const padBottom = 6.0;
    final h = size.height - padTop - padBottom;
    final span = (maxAlt - minAlt).abs() < 1e-6 ? 1.0 : (maxAlt - minAlt);

    // Time span for the X axis.
    final t0 = samples.first.time;
    final totalMs = math
        .max(1, samples.last.time.difference(t0).inMilliseconds)
        .toDouble();

    Offset pt(int i) {
      final relMs =
          samples[i].time.difference(t0).inMilliseconds.toDouble();
      final x = (relMs / totalMs) * size.width;
      final norm = (samples[i].data.altitude - minAlt) / span;
      final y = padTop + h * (1.0 - norm.clamp(0.0, 1.0));
      return Offset(x, y);
    }

    // Grid baseline.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, padTop + h),
      Offset(size.width, padTop + h),
      grid,
    );

    // Filled area under the curve.
    final area = Path()..moveTo(0, padTop + h);
    for (var i = 0; i < samples.length; i++) {
      final p = pt(i);
      area.lineTo(p.dx, p.dy);
    }
    area.lineTo(size.width, padTop + h);
    area.close();
    canvas.drawPath(area, Paint()..color = fillColor);

    // The altitude line.
    final line = Path();
    for (var i = 0; i < samples.length; i++) {
      final p = pt(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = lineColor,
    );

    // Cursor.
    final ci = cursorIndex.clamp(0, samples.length - 1);
    final c = pt(ci);
    canvas.drawLine(
      Offset(c.dx, padTop),
      Offset(c.dx, padTop + h),
      Paint()
        ..color = cursorColor
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, 3.5, Paint()..color = cursorColor);
  }

  @override
  bool shouldRepaint(covariant _AltitudeProfilePainter old) {
    return old.samples != samples ||
        old.cursorIndex != cursorIndex ||
        old.minAlt != minAlt ||
        old.maxAlt != maxAlt ||
        old.lineColor != lineColor;
  }
}
