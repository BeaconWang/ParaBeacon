/// In-memory stand-in for the okhttp WebSocket.
///
/// The real transport is a TLS WebSocket carrying UTF-8 JSON text frames
/// (live/c1.smali:7084-7110). Here the same JSON goes through two queues so the
/// demo is offline and deterministic.
library;

import 'dart:collection';

import 'live_client.dart';
import 'mock_server.dart';

/// What [LiveClient] needs from a transport: one uplink for JSON text frames.
///
/// Implemented by [Wire] (in-memory, offline) and by [WebSocketWire]
/// (live/c1.smali:7084-7110 - TLS WebSocket, UTF-8 JSON text frames).
abstract class LiveWire {
  /// One JSON text frame up to the server.
  void clientSend(String text);

  /// Tear the transport down.
  Future<void> close();
}

class Wire implements LiveWire {
  final LiveClient client;
  final MockLiveServer server;

  final Queue<String> up = ListQueue<String>();
  final Queue<String> down = ListQueue<String>();

  static const int _maxHops = 64;

  Wire(this.client, this.server) {
    client.wire = this;
    server.wire = this;
  }

  @override
  Future<void> close() async {
    up.clear();
    down.clear();
  }

  @override
  void clientSend(String text) {
    up.addLast(text);
    drain();
  }

  void serverSend(String text) {
    down.addLast(text);
    drain();
  }

  void drain() {
    var hops = 0;
    while ((up.isNotEmpty || down.isNotEmpty) && hops < _maxHops) {
      if (up.isNotEmpty) {
        for (final reply in server.onText(up.removeFirst())) {
          down.addLast(reply);
        }
      } else {
        client.onText(down.removeFirst());
      }
      hops++;
    }
  }
}
