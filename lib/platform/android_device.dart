import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Minimal Android device descriptor used to work around vendor-specific audio
/// routing quirks. The values are read once from the host platform through the
/// `com.beacon.parabeacon/device_info` method channel and cached for the rest
/// of the process.
class AndroidDevice {
  AndroidDevice._();

  static const MethodChannel _channel = MethodChannel(
    'com.beacon.parabeacon/device_info',
  );

  /// Cached platform response (`const {}` once resolved, even on failure, so
  /// the channel is only ever queried a single time).
  static Map<String, dynamic>? _cache;

  /// Overrides the resolved device info in tests.
  @visibleForTesting
  static set debugInfo(Map<String, dynamic>? info) => _cache = info;

  /// Whether the running device is a Huawei / Honor handset or runs HarmonyOS.
  ///
  /// These devices silently drop text-to-speech audio tagged with the
  /// navigation-guidance usage unless a real navigation session is active, so
  /// the announcement speaker must avoid that usage on them. Always `false`
  /// off Android.
  static Future<bool> get isHuaweiOrHarmony async {
    final info = await _info();
    return info != null && isHuaweiOrHarmonyInfo(info);
  }

  @visibleForTesting
  static bool isHuaweiOrHarmonyInfo(Map<String, dynamic> info) {
    String str(String key) => info[key]?.toString().toLowerCase() ?? '';
    final identifiers = [
      str('manufacturer'),
      str('brand'),
      str('model'),
      str('product'),
      str('device'),
      str('display'),
    ];
    return info['isHarmonyOS'] == true ||
        identifiers.any(
          (value) =>
              value.contains('huawei') ||
              value.contains('honor') ||
              value.contains('harmony') ||
              value.contains('hongmeng'),
        );
  }

  static Future<Map<String, dynamic>?> _info() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    if (_cache != null) return _cache;
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('getDeviceInfo')
          .timeout(const Duration(seconds: 3));
      _cache = result ?? const <String, dynamic>{};
    } catch (_) {
      // A missing/failed channel must never break speech; treat as "unknown".
      _cache = const <String, dynamic>{};
    }
    return _cache;
  }
}
