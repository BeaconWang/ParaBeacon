import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flight_recorder.dart';
import 'parabeacon_account_service.dart';
import 'user_agent_settings.dart';

class FlightLogSyncResult {
  const FlightLogSyncResult({required this.synced});

  final int synced;
}

class FlightLogServerImportResult {
  const FlightLogServerImportResult({
    required this.added,
    required this.skipped,
    required this.failed,
  });

  final int added;
  final int skipped;
  final int failed;
}

class FlightLogSyncService {
  FlightLogSyncService({
    ParaBeaconAccountService? accountService,
    this._authorizationHeaders,
    http.Client? client,
    Uri? endpoint,
  }) : _accountService = accountService ?? ParaBeaconAccountService.instance,
       _client = UserAgentHttpClient(innerClient: client),
       _endpoint =
           endpoint ?? Uri.https('www.parabeacon.icu', '/api/v1/flight-logs');

  static final FlightLogSyncService instance = FlightLogSyncService();
  static const _maxSnapshotTracks = 500;
  static const _pageSize = 10;
  static const _requestTimeout = Duration(seconds: 120);

  final ParaBeaconAccountService _accountService;
  final Future<Map<String, String>> Function()? _authorizationHeaders;
  final http.Client _client;
  final Uri _endpoint;

  Uri get _syncEndpoint => _endpoint.replace(path: '${_endpoint.path}/sync');

  Future<FlightLogSyncResult> syncTracks(List<FlightTrack> tracks) async {
    if (tracks.length > _maxSnapshotTracks) {
      throw ArgumentError.value(
        tracks.length,
        'tracks',
        'Too many flight records to synchronize.',
      );
    }
    final response = await _client
        .put(
          _syncEndpoint,
          headers: await _headers(),
          body: jsonEncode({
            'flights': tracks.map((track) => track.toJson()).toList(),
          }),
        )
        .timeout(_requestTimeout);
    final payload = _decodeResponse(response, endpoint: _syncEndpoint);
    final synced = _readCount(payload['synced']);
    if (synced != tracks.length) {
      throw const FormatException('ParaBeacon Server sync count mismatch.');
    }
    return FlightLogSyncResult(synced: synced);
  }

  Future<FlightLogServerImportResult> importTracks() async {
    final recorder = FlightRecorder.instance;
    final existing = recorder.tracks;
    final imported = <FlightTrack>[];
    var skipped = 0;
    var failed = 0;
    String? cursor;
    final seenCursors = <String>{};

    while (true) {
      final uri = _endpoint.replace(
        queryParameters: {
          'limit': '$_pageSize',
          if (cursor != null) 'cursor': cursor,
        },
      );
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(_requestTimeout);
      final payload = _decodeResponse(response);
      final entries = payload['flights'];
      if (entries is! List) {
        throw const FormatException('Invalid flight log response.');
      }
      for (final entry in entries) {
        if (entry is! Map<String, dynamic> ||
            entry['flight'] is! Map<String, dynamic>) {
          failed++;
          continue;
        }
        final track = FlightTrack.fromJson(
          Map<String, dynamic>.from(entry['flight'] as Map),
        );
        if (track == null) {
          failed++;
          continue;
        }
        if (_isDuplicate(track, existing) || _isDuplicate(track, imported)) {
          skipped++;
          continue;
        }
        imported.add(track);
      }

      final nextCursor = payload['next_cursor'];
      if (nextCursor is! String || nextCursor.isEmpty) break;
      if (!seenCursors.add(nextCursor)) {
        throw const FormatException('Invalid flight log pagination cursor.');
      }
      cursor = nextCursor;
    }

    if (imported.isNotEmpty) recorder.importTracks(imported);
    return FlightLogServerImportResult(
      added: imported.length,
      skipped: skipped,
      failed: failed,
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

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    Uri? endpoint,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'ParaBeacon Server returned HTTP ${response.statusCode}.',
        endpoint ?? _endpoint,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid ParaBeacon Server response.');
    }
    return decoded;
  }

  int _readCount(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid ParaBeacon Server response.');
    }
    return value;
  }

  bool _isDuplicate(FlightTrack track, List<FlightTrack> records) {
    for (final record in records) {
      final difference = track.startTime
          .difference(record.startTime)
          .inMilliseconds
          .abs();
      if (difference <= 5000 && track.pointCount == record.pointCount)
        return true;
    }
    return false;
  }
}
