// vario_audio_service_web.dart
// -----------------------------------------------------------------------------
// Web (JavaScript) stub of the vario audio service.
//
// The real engine in `vario_audio_service_io.dart` uses `dart:ffi` and the
// native `flutter_miniaudio` plugin, neither of which is available in the
// browser. To keep the rest of the app compiling and running on the web, this
// file provides an API-compatible no-op replacement that is selected via a
// conditional import in `vario_audio_service.dart`.
//
// All methods are safe to call and simply do nothing (or return sensible
// defaults). If in the future we want audible feedback on the web, this is the
// place to plug in a WebAudio-based implementation — the public surface is
// already fixed by the IO version.
// -----------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'vario_config.dart';

/// No-op stand-in for the native [VarioAudioService] on web builds.
///
/// Mirrors the public API of `vario_audio_service_io.dart` so callers can be
/// platform-agnostic. Every method is a no-op; the getters return the last
/// mute/volume values written so the settings UI still behaves consistently.
class VarioAudioService {
  /// Shared singleton for a single global vario.
  static final VarioAudioService instance = VarioAudioService();

  VarioAudioService({VarioAudioConfig config = VarioAudioConfig.xcTrack})
      : _config = config;

  VarioAudioConfig _config;
  bool _muted = false;
  double _volume = 1.0;
  bool _gateOpen = true;
  bool _previewActive = false;
  bool _previewMuted = false;

  VarioAudioConfig get config => _config;

  bool get isPreviewActive => _previewActive;

  void beginPreview([double initialSpeed = 0.0]) {
    _previewActive = true;
    _previewMuted = false;
  }

  void setPreviewSpeed(double verticalSpeed) {
    // No audio on web: ignore.
  }

  void setPreviewMuted(bool muted) {
    _previewMuted = muted;
  }

  bool get isPreviewMuted => _previewMuted;

  void endPreview() {
    _previewActive = false;
    _previewMuted = false;
  }

  void setConfig(VarioAudioConfig config) {
    _config = config;
  }

  Future<void> init() async {
    if (kDebugMode) {
      debugPrint(
        'VarioAudioService: running on web — audio disabled (FFI unavailable).',
      );
    }
  }

  void updateSpeed(double verticalSpeed) {
    // No audio on web: ignore.
  }

  void setMuted(bool isMuted) {
    _muted = isMuted;
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  void setGateOpen(bool open) {
    _gateOpen = open;
  }

  bool get isGateOpen => _gateOpen;

  bool get isMuted => _muted;
  double get volume => _volume;

  void dispose() {
    // Nothing to release on web.
  }
}
