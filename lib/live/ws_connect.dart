/// Platform pick for the WebSocket transport.
///
/// `POST /flight` hands out a `wss://` endpoint and the handshake needs
/// `Authorization: Bearer <token>` (live/c1.smali:7412-7446). Only the native
/// implementation can set that header - the browser WebSocket API has no way
/// to send headers at all - so on the web the header argument is ignored.
library;

export 'ws_connect_html.dart' if (dart.library.io) 'ws_connect_io.dart';
