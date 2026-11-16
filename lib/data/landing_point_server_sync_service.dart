import 'dart:convert';

import 'package:http/http.dart' as http;

import 'landing_point_store.dart';
import 'parabeacon_account_service.dart';
import 'user_agent_settings.dart';

class LandingPointServerBundle {
  LandingPointServerBundle({required List<LandingPoint> points, this.defaultId})
    : points = List.unmodifiable(points);

  final List<LandingPoint> points;
  final String? defaultId;
}

class LandingPointServerSyncService {
  LandingPointServerSyncService({
    ParaBeaconAccountService? accountService,
    Future<Map<String, String>> Function()? authorizationHeaders,
    http.Client? client,
    Uri? endpoint,
  }) : _accountService = accountService ?? ParaBeaconAccountService.instance,
       _authorizationHeaders = authorizationHeaders,
       _client = UserAgentHttpClient(innerClient: client),
       _endpoint =
           endpoint ??
           Uri.https('www.parabeacon.icu', '/api/v1/landing-points');

  static final LandingPointServerSyncService instance =
      LandingPointServerSyncService();
  static const _requestTimeout = Duration(seconds: 30);

  final ParaBeaconAccountService _accountService;
  final Future<Map<String, String>> Function()? _authorizationHeaders;
  final http.Client _client;
  final Uri _endpoint;

  Future<int> exportPoints(
    List<LandingPoint> points, {
    String? defaultId,
  }) async {
    if (points.length > LandingPointStore.maxEntries) {
      throw const FormatException('Too many landing points.');
    }
    final ids = points.map((point) => point.id).toSet();
    if (ids.length != points.length ||
        (defaultId != null && !ids.contains(defaultId))) {
      throw const FormatException('Invalid landing point library.');
    }
    final response = await _client
        .post(
          _endpoint,
          headers: await _headers(),
          body: jsonEncode({
            'points': points.map((point) => point.toJson()).toList(),
            'default_id': defaultId,
          }),
        )
        .timeout(_requestTimeout);
    final payload = _decodeResponse(response);
    final synced = payload['synced'];
    if (synced is! int || synced < 0 || synced > points.length) {
      throw const FormatException('Invalid ParaBeacon Server response.');
    }
    return synced;
  }

  Future<LandingPointServerBundle> importPoints() async {
    final response = await _client
        .get(_endpoint, headers: await _headers())
        .timeout(_requestTimeout);
    final payload = _decodeResponse(response);
    final entries = payload['points'];
    if (entries is! List || entries.length > LandingPointStore.maxEntries) {
      throw const FormatException('Invalid landing point response.');
    }
    final points = <LandingPoint>[];
    final ids = <String>{};
    for (final entry in entries) {
      final point = LandingPoint.tryParse(entry);
      if (point == null || !ids.add(point.id)) {
        throw const FormatException('Invalid landing point response.');
      }
      points.add(point);
    }
    final rawDefaultId = payload['default_id'];
    if (rawDefaultId != null &&
        (rawDefaultId is! String || !ids.contains(rawDefaultId))) {
      throw const FormatException('Invalid landing point response.');
    }
    return LandingPointServerBundle(
      points: points,
      defaultId: rawDefaultId as String?,
    );
  }

  Future<Map<String, String>> _headers() async {
    final authorization = _authorizationHeaders;
    final authHeaders = authorization == null
        ? await _accountService.authorizationHeaders()
        : await authorization();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...authHeaders,
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'ParaBeacon Server returned HTTP ${response.statusCode}.',
        _endpoint,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid ParaBeacon Server response.');
    }
    return decoded;
  }
}
