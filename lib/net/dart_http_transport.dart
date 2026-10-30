/// `package:http` implementation of [HttpTransport].
library;

import 'package:http/http.dart' as http;

import 'http_transport.dart';

/// rest/f.smali:11-35 builds this from the app version,
/// `Build.VERSION.RELEASE` and the build timestamp; rest/e.smali is an OkHttp
/// interceptor that adds it as `User-Agent` to **every** request - including the
/// auth calls, which are built from the same OkHttp client
/// (rest/s.smali:232-253, rest/f.smali:434-447).
///
/// The server rejects requests without it, so it is not optional.
const String kXCTrackUserAgent = 'XCTrack 0.9.12.6; Android: 13; bt: 1770217163';

class DartHttpTransport implements HttpTransport {
  final http.Client _client;

  /// OkHttp read/write/call timeout - rest/s.smali:37-41 uses 20 s (0x14) for
  /// the auth client.
  final Duration timeout;

  /// rest/e.smali:26-34 - sent with every request.
  final String userAgent;

  DartHttpTransport({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.userAgent = kXCTrackUserAgent,
  }) : _client = client ?? http.Client();

  @override
  Future<HttpResponse> send(HttpRequest request) async {
    final uri = request.uri;
    late Future<http.Response> future;

    if (request.method == 'GET') {
      future = _client.get(uri, headers: <String, String>{
        'User-Agent': userAgent,
        ...request.headers,
      });
    } else {
      final hasForm = request.form != null;
      future = _client.post(
        uri,
        headers: <String, String>{
          'User-Agent': userAgent,
          if (hasForm)
            'Content-Type': 'application/x-www-form-urlencoded'
          else if (request.body != null)
            'Content-Type': 'application/json',
          ...request.headers,
        },
        body: hasForm ? request.form : request.body,
      );
    }

    final res = await future.timeout(timeout);
    return HttpResponse(res.statusCode, res.body);
  }
}
