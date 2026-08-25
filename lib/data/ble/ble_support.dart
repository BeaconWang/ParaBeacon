import 'package:flutter/foundation.dart';

/// Reports whether the current platform has a real BLE implementation.
///
/// `flutter_blue_plus` ships iOS, Android, macOS, Linux and web
/// implementations but **no Windows** plugin. To keep the app compiling and
/// running on Windows (and to honor the requirement that BLE only works on
/// iOS/Android), every entry point into the BLE service is gated behind this
/// check. On unsupported platforms the service degrades to a harmless no-op.
class BleSupport {
  const BleSupport._();

  /// True only on the mobile platforms we wire BLE up for.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  /// Human-readable reason shown in the UI when BLE is unavailable.
  static String get unsupportedReason =>
      'Bluetooth sensors are only available on iOS and Android.';
}
