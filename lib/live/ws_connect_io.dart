/// Native (dart:io) WebSocket - can send the `Authorization` header.
library;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens [uri]. [headers] must carry `Authorization: Bearer …` for livetrack.
WebSocketChannel connectWebSocket(
  Uri uri, {
  Map<String, String> headers = const <String, String>{},
}) =>
    IOWebSocketChannel.connect(
      uri,
      headers: <String, Object>{...headers},
    );
