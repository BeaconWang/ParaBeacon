import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_tracking_socket_contract.dart';

class _WebLiveTrackingSocketConnector implements LiveTrackingSocketConnector {
  @override
  WebSocketChannel connect(
    Uri uri, {
    required Map<String, String> headers,
    required Duration pingInterval,
  }) {
    if (headers.isNotEmpty) {
      throw UnsupportedError(
        'Browser WebSocket APIs do not support custom authorization headers.',
      );
    }
    return HtmlWebSocketChannel.connect(uri);
  }
}

LiveTrackingSocketConnector createLiveTrackingSocketConnector() =>
    _WebLiveTrackingSocketConnector();
