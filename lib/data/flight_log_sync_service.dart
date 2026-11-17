import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flight_library_io.dart';
import 'flight_recorder.dart';
import 'parabeacon_account_service.dart';
import 'parabeacon_server_config.dart';
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
           endpoint ??
           ParaBeaconServerConfig.apiBaseUri.resolve('/api/v1/flight-logs');

  static final FlightLogSyncService instance = FlightLogSyncService();
  static const _maxSnapshotTracks = 500;
  static const _maxFlightArchiveBytes = 24 * 1024 * 1024;
  static const _maxSnapshotArchiveBytes = 512 * 1024 * 1024;
  static const _pageSize = 10;
  static const _requestTimeout = Duration(seconds: 120);

  final ParaBeaconAccountService _accountService;
  final Future<Map<String, String>> Function()? _authorizationHeaders;
  final http.Client _client;
  final Uri _endpoint;

  Uri get _syncSessionsEndpoint =>
      _endpoint.replace(path: '${_endpoint.path}/syncs');

  Future<FlightLogSyncResult> syncTracks(List<FlightTrack> tracks) async {
    final snapshot = List<FlightTrack>.of(tracks);
    if (snapshot.length > _maxSnapshotTracks) {
      throw ArgumentError.value(
        snapshot.length,
        'tracks',
        'Too many flight records to synchronize.',
      );
    }

    final beginResponse = await _client
        .post(
          _syncSessionsEndpoint,
          headers: await _headers(),
          body: jsonEncode({'expected_count': snapshot.length}),
        )
        .timeout(_requestTimeout);
    final beginPayload = _decodeResponse(
      beginResponse,
      endpoint: _syncSessionsEndpoint,
    );
    final syncId = beginPayload['sync_id'];
    if (syncId is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(syncId)) {
      throw const FormatException('Invalid ParaBeacon Server sync session.');
    }

    var snapshotBytes = 0;
    for (var index = 0; index < snapshot.length; index++) {
      final package = await FlightLibraryIO.instance.buildFlightPackageInWorker(
        snapshot[index],
      );
      if (package.isEmpty || package.length > _maxFlightArchiveBytes) {
        throw const FormatException('A flight package is too large to sync.');
      }
      snapshotBytes += package.length;
      if (snapshotBytes > _maxSnapshotArchiveBytes) {
        throw const FormatException('The flight library is too large to sync.');
      }

      final endpoint = _syncSessionsEndpoint.replace(
        path:
            '${_syncSessionsEndpoint.path}/${Uri.encodeComponent(syncId)}/flights/$index',
      );
      final response = await _client
          .put(
            endpoint,
            headers: {...await _headers(), 'Content-Type': 'application/zip'},
            body: package,
          )
          .timeout(_requestTimeout);
      final payload = _decodeResponse(response, endpoint: endpoint);
      final archiveId = payload['archive_id'];
      if (payload['accepted'] != true ||
          archiveId is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(archiveId)) {
        throw const FormatException(
          'Invalid ParaBeacon Server flight archive response.',
        );
      }
    }

    final commitEndpoint = _syncSessionsEndpoint.replace(
      path:
          '${_syncSessionsEndpoint.path}/${Uri.encodeComponent(syncId)}/commit',
    );
    final commitResponse = await _client
        .post(commitEndpoint, headers: await _headers())
        .timeout(_requestTimeout);
    final commitPayload = _decodeResponse(
      commitResponse,
      endpoint: commitEndpoint,
    );
    final synced = _readCount(commitPayload['synced']);
    if (synced != snapshot.length) {
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
        queryParameters: {'limit': '$_pageSize', 'cursor': ?cursor},
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
      if (difference <= 5000 && track.pointCount == record.pointCount) {
        return true;
      }
    }
    return false;
  }
}
