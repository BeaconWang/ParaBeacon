/// REST side of livetrack - `rest/apis/LivetrackApi.smali`.
///
/// All calls carry `Authorization: Bearer <token>`; the flight call additionally
/// carries `client-id: xctrack` and `client-hmac: HMAC_SHA256(body, secret)`.
library;

import 'dart:convert';

import '../auth/auth_client.dart';
import '../net/http_transport.dart';
import 'config.dart';
import 'live_client.dart' show FlightDeclared, FlightOptions;
import 'proto.dart';
import 'sha256.dart';

/// `LivetrackApi$FlightInfo` - only `uri` matters to the client.
class FlightInfo {
  final String uri;
  const FlightInfo({required this.uri});

  factory FlightInfo.fromJson(Map<String, dynamic> m) =>
      FlightInfo(uri: m['uri'] as String? ?? '');
}

/// `LivetrackApi$ActiveFlight`.
class ActiveFlight {
  final String flightId;
  final String userName;
  final String? fullName;
  final String? glider;
  final String? launch;
  final LiveFlightPosition? position;

  const ActiveFlight({
    required this.flightId,
    required this.userName,
    this.fullName,
    this.glider,
    this.launch,
    this.position,
  });

  factory ActiveFlight.fromJson(Map<String, dynamic> m) => ActiveFlight(
        flightId: m['flightId'] as String? ?? '',
        userName: m['userName'] as String? ?? '',
        fullName: m['fullName'] as String?,
        glider: m['glider'] as String?,
        launch: m['launch'] as String?,
        position: m['position'] == null
            ? null
            : LiveFlightPosition.fromJson(m['position'] as Map<String, dynamic>),
      );
}

class LivetrackApi {
  final HttpTransport transport;
  final AuthClient auth;

  /// `https://live2.xcontest.org/api/` - note: *not* the auth host.
  final String baseUrl;

  LivetrackApi({
    required this.transport,
    required this.auth,
    this.baseUrl = kBaseUrl,
  });

  Map<String, dynamic> lastExchange = <String, dynamic>{};

  // ---------------------------------------------------------------------
  // POST flight
  // ---------------------------------------------------------------------
  /// Publishes the flight and returns the WebSocket endpoint to connect to.
  ///
  /// `options.flpublic` (wire name `"public"`) is what actually makes the
  /// flight visible to others - LivetrackApi$FlightOptions.smali:80-84.
  Future<FlightDeclared> createFlight(FlightOptions options) {
    return auth.withReauth((session) async {
      final body = jsonEncode(options.toJson());
      final signature = hex(hmacSha256(
        utf8.encode(kClientHmacKey),
        utf8.encode(body),
      ));

      final request = HttpRequest(
        method: 'POST',
        uri: Uri.parse('${baseUrl}flight'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': session.authHeader,
          'client-id': kClientId,
          'client-hmac': signature,
        },
        body: body,
      );

      final res = await transport.send(request);
      lastExchange = <String, dynamic>{'request': request, 'response': res};

      if (res.isForbidden) {
        // live/c1.smali:4339 "Auth failed, user must re-login."
        await auth.logout();
        throw StateError('Forbidden: user must re-login');
      }
      if (res.isUnauthorized) {
        throw UnauthorizedException('/flight', res.statusCode);
      }
      if (!res.isOk) {
        throw UnexpectedResponseException('/flight', res);
      }

      final info = FlightInfo.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      if (info.uri.isEmpty) {
        throw UnexpectedResponseException('/flight', res);
      }
      // The server only returns `uri`; the xc flight id arrives later in
      // SvrLandingAck.xcFlightId (live/c1.smali:5687-5763).
      return FlightDeclared(uri: info.uri, flightId: '');
    });
  }

  // ---------------------------------------------------------------------
  // GET flight/active
  // ---------------------------------------------------------------------
  /// `showAll` is a @QueryName flag added only when pref
  /// `Livetrack.ShowPublic` is set (live/p1.smali:175-218).
  Future<List<ActiveFlight>> activeFlights({bool showAll = false}) {
    return auth.withReauth((session) async {
      final path = showAll ? '${baseUrl}flight/active?showAll'
                           : '${baseUrl}flight/active';
      final request = HttpRequest(
        method: 'GET',
        uri: Uri.parse(path),
        headers: <String, String>{'Authorization': session.authHeader},
      );
      final res = await transport.send(request);
      lastExchange = <String, dynamic>{'request': request, 'response': res};

      if (res.isUnauthorized) throw UnauthorizedException('/flight/active', res.statusCode);
      if (!res.isOk) throw UnexpectedResponseException('/flight/active', res);

      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => ActiveFlight.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  // ---------------------------------------------------------------------
  // groups (following other pilots - separate from flight sharing)
  // ---------------------------------------------------------------------
  Future<void> setGroupEnabled(String groupUuid, {required bool enabled}) {
    return auth.withReauth((session) async {
      final request = HttpRequest(
        method: 'POST',
        uri: Uri.parse('${baseUrl}group/$groupUuid/${enabled ? 'enable' : 'disable'}'),
        headers: <String, String>{'Authorization': session.authHeader},
      );
      final res = await transport.send(request);
      lastExchange = <String, dynamic>{'request': request, 'response': res};
      if (res.isUnauthorized) {
        throw UnauthorizedException('/group/enable', res.statusCode);
      }
      if (!res.isOk) {
        throw UnexpectedResponseException('/group/enable', res);
      }
    });
  }
}
