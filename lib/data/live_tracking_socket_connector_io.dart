import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_tracking_socket_contract.dart';

class _IoLiveTrackingSocketConnector implements LiveTrackingSocketConnector {
  @override
  WebSocketChannel connect(
    Uri uri, {
    required Map<String, String> headers,
    required Duration pingInterval,
  }) => IOWebSocketChannel.connect(
    uri,
    headers: headers,
    pingInterval: pingInterval,
  );
}

LiveTrackingSocketConnector createLiveTrackingSocketConnector() =>
    _IoLiveTrackingSocketConnector();
