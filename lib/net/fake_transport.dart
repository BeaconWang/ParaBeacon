/// Offline stand-in for the XContest auth + livetrack servers.
///
/// Lets the whole login and share flow be exercised (and demoed) without an
/// account or network. Routes mirror the real ones:
///   POST auth/oauth/token_noauth
///   POST auth/oauth/introspect
///   POST live/flight
///   GET  live/flight/active
///   POST live/group/{uuid}/enable|disable
library;

import 'dart:async';
import 'dart:convert';

import 'http_transport.dart';

/// Credentials accepted by the fake auth server.
class FakeAccount {
  final String username;
  final String password;
  final String uid;
  final String fullName;

  const FakeAccount({
    required this.username,
    required this.password,
    this.uid = '42',
    this.fullName = 'Demo Pilot',
  });

  static const demo = FakeAccount(username: 'pilot', password: 'flysafe');
}

class FakeTransport implements HttpTransport {
  List<FakeAccount> accounts;

  /// Simulated network latency.
  final Duration latency;

  /// Set to true to make every introspect fail (token revoked server-side).
  bool tokensRevoked = false;

  /// Set to true to answer 401 on every authenticated call.
  bool forceUnauthorized = false;

  /// Set to true to answer 403 on every authenticated call.
  bool forceForbidden = false;

  final List<HttpRequest> log = <HttpRequest>[];

  int loginCount = 0;
  int flightCount = 0;

  FakeTransport({
    this.accounts = const <FakeAccount>[FakeAccount.demo],
    this.latency = Duration.zero,
  });

  @override
  Future<HttpResponse> send(HttpRequest request) async {
    log.add(request);
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final path = request.uri.path;

    if (path.endsWith('/token_noauth')) return _token(request);
    if (path.endsWith('/introspect')) return _introspect(request);

    if (forceUnauthorized) return HttpResponse(401, '{"error":"unauthorized"}');
    if (forceForbidden) return HttpResponse(403, '{"error":"forbidden"}');

    if (path.endsWith('/flight')) {
      if (request.method == 'GET') return HttpResponse(200, _activeFlights());
      return _createFlight(request);
    }
    if (path.contains('/group/')) {
      return HttpResponse(200, '{"id":"g1","name":"demo","enabled":true}');
    }
    return HttpResponse(404, '{"error":"no route for $path"}');
  }

  HttpResponse _token(HttpRequest request) {
    loginCount++;
    final form = request.form ?? <String, String>{};
    final user = form['username'] ?? '';
    final pass = form['password'] ?? '';
    final match = accounts
        .where((a) => a.username == user && a.password == pass)
        .cast<FakeAccount?>()
        .firstWhere((a) => a != null, orElse: () => null);

    if (match == null) return HttpResponse(403, '{"error":"bad credentials"}');

    // token encodes the username so introspect can echo it back
    return HttpResponse(200, jsonEncode(<String, dynamic>{
      'access_token': 'tok-$user',
      'uid': match.uid,
      'full_name': match.fullName,
    }));
  }

  HttpResponse _introspect(HttpRequest request) {
    if (tokensRevoked) return HttpResponse(401, '{"error":"revoked"}');
    final token = request.form?['token'] ?? '';
    if (!token.startsWith('tok-')) return HttpResponse(401, '{"error":"bad token"}');
    return HttpResponse(200, jsonEncode(<String, dynamic>{
      'scope': 'livetrack',
      'username': token.substring(4),
    }));
  }

  /// `FAI-<n>` or `<Rxx><1|2><engineType>` - config/t0.smali:10405-10730.
  static final RegExp _gliderCat = RegExp(r'^(FAI-\d+|R[A-Z]{2}\d[A-Z]?)$');

  HttpResponse _createFlight(HttpRequest request) {
    flightCount++;
    final body = jsonDecode(request.body ?? '{}') as Map<String, dynamic>;
    if (body['public'] != true) {
      return HttpResponse(400, '{"error":"flight is not public"}');
    }
    // The real server parses gliderCat with attoparsec and 400s on anything
    // that is not one of its category ids (see lib/live/glider.dart).
    final gliderCat = body['gliderCat'] as String? ?? '';
    if (!_gliderCat.hasMatch(gliderCat)) {
      return HttpResponse(400,
          '{"error":"Error parsing XcFlightOptions - Error in \$.gliderCat:'
          ' Failed reading: takeWhile1"}');
    }
    return HttpResponse(200, jsonEncode(<String, dynamic>{
      'uri': 'wss://live2.xcontest.org/ws/demo-$flightCount',
    }));
  }

  String _activeFlights() => jsonEncode(<dynamic>[
        <String, dynamic>{
          'flightId': 'other-1',
          'userName': 'buddy',
          'fullName': 'Buddy',
          'glider': 'Enzo 3',
          'launch': 'Planfait',
          'position': <String, dynamic>{
            'lat': 45.91,
            'lon': 6.87,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'gpsAlt': 1750,
            'baroAlt': 1755,
            'elevation': 480,
            'speed': 11.5,
            'vspeed': -0.4,
            'landed': false,
          },
        },
      ]);
}
