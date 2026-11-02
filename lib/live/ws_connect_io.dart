/// Native (dart:io) WebSocket - can send the `Authorization` header.
library;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens [uri]. [headers] must carry `Authorization: Bearer …` for livetrack.
///
/// [pingInterval] enables WebSocket-level keepalive: the client sends a ping
/// every interval and expects a pong, which keeps NATs / load balancers from
/// silently dropping the (otherwise low-traffic, one chunk / 60 s) connection
/// and lets a dead peer be detected promptly.
WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, String> headers = const <String, String>{},
  Duration? pingInterval,
}) =>
    IOWebSocketChannel.connect(
      uri,
      headers: <String, Object>{...headers},
      pingInterval: pingInterval,
    );
