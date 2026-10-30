/// Minimal HTTP abstraction so the auth / livetrack logic can run offline
/// (fake transport) or against the real servers (`package:http`).
library;

import 'dart:async';

class HttpRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;

  /// Raw body (JSON). Mutually exclusive with [form].
  final String? body;

  /// application/x-www-form-urlencoded fields. Mutually exclusive with [body].
  final Map<String, String>? form;

  const HttpRequest({
    required this.method,
    required this.uri,
    this.headers = const <String, String>{},
    this.body,
    this.form,
  });
}

class HttpResponse {
  final int statusCode;
  final String body;
  const HttpResponse(this.statusCode, this.body);

  bool get isOk => statusCode >= 200 && statusCode < 300;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
}

abstract class HttpTransport {
  Future<HttpResponse> send(HttpRequest request);
}

/// Thrown for 401 so callers can trigger the re-login + retry flow.
class UnauthorizedException implements Exception {
  final String path;
  final int statusCode;
  const UnauthorizedException(this.path, [this.statusCode = 401]);

  @override
  String toString() => 'UnauthorizedException($statusCode on $path)';
}

/// Thrown for any other non-2xx that is not handled explicitly.
class UnexpectedResponseException implements Exception {
  final String path;
  final HttpResponse response;
  const UnexpectedResponseException(this.path, this.response);

  @override
  String toString() => 'UnexpectedResponseException($path -> ${response.statusCode}'
      '${response.body.trim().isEmpty ? '' : ' ${_trim(response.body)}'})';

  static String _trim(String body) {
    final one = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length <= 300 ? one : '${one.substring(0, 300)}…';
  }
}
