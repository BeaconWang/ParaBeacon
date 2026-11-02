/// Browser WebSocket - the platform API cannot set request headers, so
/// [headers] is accepted but ignored (the livetrack server would answer 401).
/// [pingInterval] is also ignored: the browser manages keepalive itself.
library;

import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, String> headers = const <String, String>{},
  Duration? pingInterval,
}) =>
    WebSocketChannel.connect(uri);
