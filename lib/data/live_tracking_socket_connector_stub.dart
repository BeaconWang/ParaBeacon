import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_tracking_socket_contract.dart';

class _UnsupportedLiveTrackingSocketConnector
    implements LiveTrackingSocketConnector {
  @override
  WebSocketChannel connect(
    Uri uri, {
    required Map<String, String> headers,
    required Duration pingInterval,
  }) => throw UnsupportedError('WebSocket transport is unavailable.');
}

LiveTrackingSocketConnector createLiveTrackingSocketConnector() =>
    _UnsupportedLiveTrackingSocketConnector();
