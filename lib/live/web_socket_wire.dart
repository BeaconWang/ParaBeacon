/// Real WebSocket transport - `live/c1.smali:7329-7500` (`c1.s()`).
///
/// The server hands out the endpoint in `POST /flight` (`{ "uri": "wss://…" }`);
/// frames are UTF-8 JSON text, exactly what [LiveClient.send] produces and
/// [LiveClient.onText] consumes.
///
/// The handshake carries `Authorization: Bearer <token>` - the APK adds it with
/// `td/u.b("Bearer " + t0.r0)` (c1.smali:7412-7446), which is
/// `addHeader("Authorization", …)` under the hood. Without it the server
/// answers `401 Unauthorized` instead of `101`, so the upgrade "fails".
library;

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_client.dart';
import 'wire.dart';
import 'ws_connect.dart';

class WebSocketWire implements LiveWire {
  final LiveClient client;

  /// Called when the socket closes or errors, so the caller can drive the
  /// reconnect backoff (live/c1.smali:920-1215).
  final void Function(Object? error)? onClosed;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  WebSocketWire(this.client, {this.onClosed}) {
    client.wire = this;
  }

  bool get isOpen => _channel != null;

  /// Opens the socket to [uri] - normally `FlightDeclared.uri` from the
  /// `POST /flight` response.
  ///
  /// [headers] must include `Authorization: Bearer <token>`; resolves once the
  /// 101 upgrade came back, so a rejected handshake throws here instead of
  /// surfacing later as a closed stream.
  Future<void> connect(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Duration? pingInterval = const Duration(seconds: 30),
  }) async {
    await close();
    final channel = connectWebSocket(
      uri,
      headers: headers,
      pingInterval: pingInterval,
    );
    _channel = channel;
    await channel.ready;
    _sub = channel.stream.listen(
      (dynamic message) {
        if (message is String) client.onText(message);
      },
      onError: (Object? error) {
        _channel = null;
        onClosed?.call(error);
      },
      onDone: () {
        // Surface the WebSocket close code/reason so the caller can tell a
        // server-initiated close (e.g. flight terminated, auth) apart from a
        // transient network drop.
        final code = channel.closeCode;
        final reason = channel.closeReason;
        _channel = null;
        onClosed?.call(
          code == null && (reason == null || reason.isEmpty)
              ? null
              : 'close ${code ?? '?'}'
                  '${reason != null && reason.isNotEmpty ? ' $reason' : ''}',
        );
      },
      cancelOnError: false,
    );
  }

  @override
  void clientSend(String text) => _channel?.sink.add(text);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }
}
