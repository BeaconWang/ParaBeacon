import 'dart:io';

import 'package:flutter/services.dart';

/// Saves generated flight export files into the Android Downloads collection.
/// Android's system document picker is used on versions before scoped storage.
class FlightFileOutputService {
  FlightFileOutputService._();
  static final FlightFileOutputService instance = FlightFileOutputService._();

  static const MethodChannel _channel = MethodChannel(
    'com.beacon.parabeacon/flight_library',
  );

  Future<String?> saveToDownloads({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Downloads export is only available on Android.');
    }
    return _channel.invokeMethod<String>('saveFlightFile', {
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': Uint8List.fromList(bytes),
    });
  }
}
