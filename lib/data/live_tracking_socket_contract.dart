import 'package:web_socket_channel/web_socket_channel.dart';

abstract interface class LiveTrackingSocketConnector {
  WebSocketChannel connect(
    Uri uri, {
    required Map<String, String> headers,
    required Duration pingInterval,
  });
}
