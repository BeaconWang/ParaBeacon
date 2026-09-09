import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../audio/vario_audio_service.dart';
import '../data/flight_data.dart';
import '../data/flight_recorder.dart';
import '../data/gcj02.dart';
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

  /// The samples we replay, captured once so the list can't change under us.
  late final List<FlightSample> _samples;

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
                  child: Text('Replay', style: theme.textTheme.titleLarge),
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
          _buildControls(theme),
        ],
      ),
    );
  }

  Widget _readoutChip(ThemeData theme, FlightSample s) {
    final d = s.data;
    final vario = d.verticalSpeed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'HDG ${d.heading.round()}°  ·  ALT ${d.altitude.round()}m  ·  '
        '${vario >= 0 ? '+' : ''}${vario.toStringAsFixed(1)} m/s',
        style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
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
                tooltip: 'Restart',
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
                tooltip: _playing ? 'Pause' : 'Play',
                onPressed: canReplay ? _togglePlay : null,
              ),
              TextButton(
                onPressed: canReplay ? _cycleSpeed : null,
                child: Text('${_speed.toStringAsFixed(_speed % 1 == 0 ? 0 : 1)}×'),
              ),
              IconButton(
                icon: Icon(_audioSync ? Icons.volume_up : Icons.volume_off),
                tooltip: _audioSync ? 'Vario sound on' : 'Vario sound off',
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
    double vario(int i) => _samples[i].data.verticalSpeed;

    final out = <Polyline>[];
    int runStart = 0;
    Color runColor = _varioColor(vario(1), dimmed: 1 > curIdx);

    void flush(int endExclusive) {
      if (endExclusive - runStart < 2) return;
      out.add(Polyline(
        points: [for (int i = runStart; i < endExclusive; i++) at(i)],
        strokeWidth: 3,
        color: runColor,
      ));
    }

    for (int i = 2; i < _samples.length; i++) {
      final c = _varioColor(vario(i), dimmed: i > curIdx);
      if (c != runColor) {
        flush(i);
        runStart = i - 1; // share the endpoint for visual continuity
        runColor = c;
      }
    }
    flush(_samples.length);
    return out;
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
