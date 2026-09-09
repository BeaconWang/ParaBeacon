// vario_audio_service.dart
// -----------------------------------------------------------------------------
// Platform-agnostic entry point for the vario audio engine.
//
// The native implementation (`vario_audio_service_io.dart`) uses `dart:ffi` +
// the `flutter_miniaudio` plugin to drive a low-latency PCM stream on
// Windows/macOS/Linux/Android/iOS.
//
// The web build cannot use `dart:ffi`, so we conditionally export a no-op
// stub (`vario_audio_service_web.dart`) that keeps the app compiling and lets
// the rest of the UI (settings sheet, preview panel, etc.) run without audio.
//
// Callers should always import THIS file and never the `_io` / `_web`
// variants directly.
// -----------------------------------------------------------------------------

export 'vario_audio_service_io.dart'
    if (dart.library.js_interop) 'vario_audio_service_web.dart'
    if (dart.library.html) 'vario_audio_service_web.dart';
