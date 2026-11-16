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
  static const _maxSyncBatchRecords = 50;
  static const _maxFlightBytes = 18 * 1024 * 1024;
  static const _maxSnapshotBytes = 512 * 1024 * 1024;
  static const _targetSyncBatchBytes = 8 * 1024 * 1024;
  static const _maxSyncBatchBodyBytes = 19 * 1024 * 1024;
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

    final batchPrefix = '{"flights":[';
    const batchSuffix = ']}';
    final envelopeBytes = utf8.encode('$batchPrefix$batchSuffix').length;
    var batch = <String>[];
    var batchBytes = envelopeBytes;
    var batchIndex = 0;
    var snapshotBytes = 0;

    Future<void> uploadBatch() async {
      if (batch.isEmpty) return;
      final endpoint = _syncSessionsEndpoint.replace(
        path:
            '${_syncSessionsEndpoint.path}/${Uri.encodeComponent(syncId)}/batches/$batchIndex',
      );
      final response = await _client
          .put(
            endpoint,
            headers: await _headers(),
            body: '$batchPrefix${batch.join(',')}$batchSuffix',
          )
          .timeout(_requestTimeout);
      final payload = _decodeResponse(response, endpoint: endpoint);
      if (_readCount(payload['accepted']) != batch.length ||
          _readCount(payload['batch_index']) != batchIndex) {
        throw const FormatException(
          'Invalid ParaBeacon Server batch response.',
        );
      }
      batchIndex++;
      batch = <String>[];
      batchBytes = envelopeBytes;
    }

    for (final track in snapshot) {
      final record = jsonEncode(track.toJson());
      final recordBytes = utf8.encode(record).length;
      if (recordBytes > _maxFlightBytes) {
        throw const FormatException('A flight record is too large to sync.');
      }
      snapshotBytes += recordBytes;
      if (snapshotBytes > _maxSnapshotBytes) {
        throw const FormatException('The flight library is too large to sync.');
      }
      final candidateBytes = batchBytes + (batch.isEmpty ? 0 : 1) + recordBytes;
      if (batch.isNotEmpty &&
          (batch.length >= _maxSyncBatchRecords ||
              candidateBytes > _targetSyncBatchBytes ||
              candidateBytes > _maxSyncBatchBodyBytes)) {
        await uploadBatch();
      }
      final nextBatchBytes = batchBytes + (batch.isEmpty ? 0 : 1) + recordBytes;
      if (nextBatchBytes > _maxSyncBatchBodyBytes) {
        throw const FormatException(
          'A flight record exceeds the sync batch limit.',
        );
      }
      batch.add(record);
      batchBytes = nextBatchBytes;
    }
    await uploadBatch();

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
