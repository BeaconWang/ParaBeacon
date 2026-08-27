// vario_audio_example.dart
// -----------------------------------------------------------------------------
// Integration snippet (NOT a demo UI, NOT a main()).
//
// Shows the correct way to drive [VarioAudioService] from this project's
// existing barometer/flight-data pipeline. Two variants are shown:
//
//   A) Bridging the app's ChangeNotifier `FlightDataView` (recommended here).
//   B) A raw Stream / Timer barometer callback (generic reference).
//
// Both simply call `updateSpeed(...)` at 20-50 Hz. The service does the rest.
// Delete this file if you wire the service up directly in your own widgets.
// -----------------------------------------------------------------------------

import 'dart:async';

import '../data/flight_data.dart';
import 'vario_audio_service.dart';
import 'vario_config.dart';

// ---------------------------------------------------------------------------
// Variant A — bridge a FlightDataView (ChangeNotifier) to audio.
//
// Attach one of these near where the data-transform layer is created
// (e.g. in `_ParaBeaconAppState.initState`). It listens to the unified feed
// and forwards vertical speed to the vario on every notification.
// ---------------------------------------------------------------------------

/// Connects a [FlightDataView] to a [VarioAudioService] for its lifetime.
///
/// ```dart
/// // in _ParaBeaconAppState.initState():
/// _dataSource = BluetoothSensorFlightDataSource()..start();
/// _transformer = FlightDataTransformer(rawSource: _dataSource);
/// _varioBridge = VarioAudioBridge(source: _transformer);
/// await _varioBridge.attach();          // safe to fire-and-forget
///
/// // in dispose():
/// _varioBridge.dispose();
/// ```
class VarioAudioBridge {
  final FlightDataView source;
  final VarioAudioService audio;

  VarioAudioBridge({
    required this.source,
    VarioAudioService? audio,
    VarioAudioConfig config = VarioAudioConfig.xcTrack,
  }) : audio = audio ?? VarioAudioService(config: config);

  bool _attached = false;
  double? _lastSpeed;

  /// Initializes audio and starts forwarding vertical speed.
  ///
  /// If audio initialization fails (e.g. no audio device / plugin missing on
  /// this platform), the listener is not registered and the app keeps running
  /// silently rather than crashing.
  Future<void> attach() async {
    if (_attached) return;
    try {
      await audio.init();
    } catch (e) {
      // Audio unavailable: run silently. Surface the reason in debug only.
      assert(() {
        // ignore: avoid_print
        print('VarioAudioBridge: audio init failed, running muted: $e');
        return true;
      }());
      return;
    }
    source.addListener(_onData);
    _attached = true;
    // Push the current value immediately so the sound reflects vertical speed
    // right away rather than waiting for the next data tick.
    _onData();
  }

  void _onData() {
    // The source already applies debug overrides in `data`. The vario sound is
    // strictly a function of this value.
    final vs = source.data.verticalSpeed;
    // Skip redundant updates; identical speeds produce identical audio, so
    // there is no need to touch the engine.
    if (_lastSpeed != null && (vs - _lastSpeed!).abs() < 1e-4) return;
    _lastSpeed = vs;
    audio.updateSpeed(vs);
  }

  /// Mute/volume proxies so the settings UI can talk to one object.
  void setMuted(bool muted) => audio.setMuted(muted);
  void setVolume(double volume) => audio.setVolume(volume);

  /// Swap the sound profile at runtime (e.g. user picks a profile in settings).
  void setConfig(VarioAudioConfig config) => audio.setConfig(config);

  void dispose() {
    if (!_attached) return;
    _attached = false;
    source.removeListener(_onData);
    audio.dispose();
  }
}

// ---------------------------------------------------------------------------
// Variant B — generic Stream / Timer barometer wiring (reference only).
//
// Use this shape if your real barometer exposes a Stream<double> of vertical
// speed, or if you compute vs on a periodic Timer from raw pressure.
// ---------------------------------------------------------------------------

/// Example: drive the vario from a `Stream<double>` of vertical speed (m/s).
Future<StreamSubscription<double>> driveFromStream(
  Stream<double> verticalSpeedStream, {
  VarioAudioService? service,
}) async {
  final vario = service ?? VarioAudioService.instance;
  await vario.init();

  // A real baro stream at 20-50 Hz maps 1:1 onto updateSpeed().
  final sub = verticalSpeedStream.listen(
    vario.updateSpeed,
    onError: (_) => vario.updateSpeed(0.0), // fail safe to silence
  );
  return sub; // caller cancels + calls vario.dispose() on teardown
}

/// Example: compute vertical speed on a 25 Hz Timer from a pressure sensor and
/// feed the vario. Replace [readAltitudeMeters] with your real sensor read.
class TimerBaroVarioExample {
  final VarioAudioService vario;
  final double Function() readAltitudeMeters;

  Timer? _timer;
  double? _lastAlt;
  int? _lastTsMicros;

  TimerBaroVarioExample({
    required this.readAltitudeMeters,
    VarioAudioService? vario,
  }) : vario = vario ?? VarioAudioService.instance;

  Future<void> start({int hz = 25}) async {
    await vario.init();
    final period = Duration(microseconds: (1000000 / hz).round());
    _timer = Timer.periodic(period, (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final alt = readAltitudeMeters();
    if (_lastAlt != null && _lastTsMicros != null) {
      final dt = (now - _lastTsMicros!) / 1e6;
      if (dt > 0) {
        final vs = (alt - _lastAlt!) / dt; // m/s
        vario.updateSpeed(vs);
      }
    }
    _lastAlt = alt;
    _lastTsMicros = now;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    vario.dispose();
  }
}
