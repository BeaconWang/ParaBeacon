import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Requests the runtime permissions each platform needs for BLE scanning.
///
/// Only invoked on iOS/Android (guarded by [BleSupport] upstream), so the
/// `dart:io` platform checks here are safe.
class BlePermissions {
  const BlePermissions._();

  /// Returns true when all required permissions have been granted.
  static Future<bool> ensureGranted() async {
    if (Platform.isAndroid) {
      // Android 12+ uses the bluetoothScan/Connect permissions; on older
      // versions those are no-ops and location is used instead.
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      final connectOk =
          statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final locationOk =
          statuses[Permission.locationWhenInUse]?.isGranted ?? false;

      return (scanOk && connectOk) || locationOk;
    }

    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted || status.isLimited;
    }

    // Other platforms are never reached because BLE is gated to mobile.
    return true;
  }
}
