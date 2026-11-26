import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../parabeacon_account_service.dart';
import '../parabeacon_server_config.dart';
import '../user_agent_settings.dart';
import 'competition_task.dart';

class CompetitionTaskServerEntry {
  const CompetitionTaskServerEntry({
    required this.task,
    required this.updatedAt,
    required this.ownerId,
    required this.username,
    required this.displayName,
  });

  final CompetitionTask task;
  final DateTime updatedAt;
  final String ownerId;
  final String username;
  final String displayName;
}

class CompetitionTaskServerList {
  const CompetitionTaskServerList({
    required this.tasks,
    required this.currentTaskOwnerId,
  });

  final List<CompetitionTaskServerEntry> tasks;
  final String? currentTaskOwnerId;
}

class CompetitionTaskServerService {
  CompetitionTaskServerService({
    ParaBeaconAccountService? accountService,
    this.authorizationHeaders,
    http.Client? client,
    Uri? listEndpoint,
    Uri? uploadEndpoint,
    Uri? selectionEndpoint,
  }) : _accountService = accountService ?? ParaBeaconAccountService.instance,
       _client = UserAgentHttpClient(innerClient: client),
       _listEndpointOverride = listEndpoint,
       _uploadEndpointOverride = uploadEndpoint,
       _selectionEndpointOverride = selectionEndpoint;

  static final CompetitionTaskServerService instance =
      CompetitionTaskServerService();
  static const _requestTimeout = Duration(seconds: 30);
  static const _suppressedAutoSyncKeyPrefix =
      'pb.competition.serverTaskAutoSyncSuppressed.';
  static final Map<String, String> _suppressedAutoSyncFingerprints = {};
  static final ValueNotifier<String?> currentTaskOwnerId = ValueNotifier(null);
  static int _currentTaskOwnerRevision = 0;

  static void resetCurrentTaskOwner() {
    _currentTaskOwnerRevision++;
    currentTaskOwnerId.value = null;
  }

  final ParaBeaconAccountService _accountService;
  final Future<Map<String, String>> Function()? authorizationHeaders;
  final http.Client _client;
  final Uri? _listEndpointOverride;
  final Uri? _uploadEndpointOverride;
  final Uri? _selectionEndpointOverride;

  Uri get _listEndpoint =>
      _listEndpointOverride ??
      ParaBeaconServerConfig.apiBaseUri.resolve('/api/v1/competition-tasks');
  Uri get _uploadEndpoint =>
      _uploadEndpointOverride ??
      ParaBeaconServerConfig.apiBaseUri.resolve(
        '/api/v1/user/competition-task',
      );
  Uri get _selectionEndpoint =>
      _selectionEndpointOverride ??
      ParaBeaconServerConfig.apiBaseUri.resolve(
        '/api/v1/user/current-competition-task',
      );

  Future<void> uploadTask(CompetitionTask task) async {
    if (task.isEmpty) {
      throw const FormatException('Cannot upload an empty task.');
    }
    final response = await _client
        .put(
          _uploadEndpoint,
          headers: await _headers(),
          body: jsonEncode({'task': task.toXctsk()}),
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'ParaBeacon Server returned HTTP ${response.statusCode}.',
        _uploadEndpoint,
      );
    }
    final accountId = _accountService.user?.id;
    if (accountId != null) {
      await clearAutoSyncSuppression(accountId);
      _currentTaskOwnerRevision++;
      currentTaskOwnerId.value = accountId;
    }
  }

  Future<void> suppressAutoSyncForTask(
    String accountId,
    CompetitionTask task,
  ) async {
    final fingerprint = _taskFingerprint(task);
    _suppressedAutoSyncFingerprints[accountId] = fingerprint;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        '$_suppressedAutoSyncKeyPrefix$accountId',
        fingerprint,
      );
    } catch (_) {
      // Keep the suppression in memory for the current process.
    }
  }

  Future<bool> isAutoSyncSuppressed(
    String accountId,
    CompetitionTask task,
  ) async {
    final fingerprint = _taskFingerprint(task);
    final inMemory = _suppressedAutoSyncFingerprints[accountId];
    if (inMemory != null) {
      if (inMemory == fingerprint) return true;
      await clearAutoSyncSuppression(accountId);
      return false;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = '$_suppressedAutoSyncKeyPrefix$accountId';
      final savedFingerprint = preferences.getString(key);
      if (savedFingerprint == null) return false;
      if (savedFingerprint == fingerprint) {
        _suppressedAutoSyncFingerprints[accountId] = savedFingerprint;
        return true;
      }
      await preferences.remove(key);
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<void> clearAutoSyncSuppression(String accountId) async {
    _suppressedAutoSyncFingerprints.remove(accountId);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('$_suppressedAutoSyncKeyPrefix$accountId');
    } catch (_) {
      // Keep suppression cleared in memory for the current process.
    }
  }

  String _taskFingerprint(CompetitionTask task) =>
      sha256.convert(utf8.encode(task.toXctskString())).toString();

  Future<void> deleteOwnTask() async {
    final response = await _client
        .delete(_uploadEndpoint, headers: await _headers())
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'ParaBeacon Server returned HTTP ${response.statusCode}.',
        _uploadEndpoint,
      );
    }
    final accountId = _accountService.user?.id;
    _currentTaskOwnerRevision++;
    if (accountId != null && currentTaskOwnerId.value == accountId) {
      currentTaskOwnerId.value = null;
    }
  }

  Future<void> setCurrentTask(String? taskOwnerId) async {
    final normalizedOwnerId = taskOwnerId?.trim().toLowerCase();
    if (normalizedOwnerId != null &&
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(normalizedOwnerId)) {
      throw const FormatException('Invalid competition task owner ID.');
    }
    final response = await _client
        .put(
          _selectionEndpoint,
          headers: await _headers(),
          body: jsonEncode({'task_owner_id': normalizedOwnerId}),
        )
        .timeout(_requestTimeout);
    final payload = _decodeResponse(response, _selectionEndpoint);
    if (payload['current_task_owner_id'] != normalizedOwnerId) {
      throw const FormatException('Invalid current competition task response.');
    }
    _currentTaskOwnerRevision++;
    currentTaskOwnerId.value = normalizedOwnerId;
  }

  Future<String?> refreshCurrentTaskOwner() async {
    final revision = _currentTaskOwnerRevision;
    final response = await _client
        .get(_selectionEndpoint, headers: await _headers())
        .timeout(_requestTimeout);
    final payload = _decodeResponse(response, _selectionEndpoint);
    final ownerId = payload['current_task_owner_id'];
    if (ownerId != null &&
        (ownerId is! String ||
            !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(ownerId))) {
      throw const FormatException('Invalid current competition task response.');
    }
    final normalizedOwnerId = ownerId?.toLowerCase();
    if (revision == _currentTaskOwnerRevision) {
      currentTaskOwnerId.value = normalizedOwnerId;
    }
    return normalizedOwnerId;
  }

  Future<List<CompetitionTaskServerEntry>> listTasks() async =>
      (await listTasksWithSelection()).tasks;

  Future<CompetitionTaskServerList> listTasksWithSelection() async {
    final revision = _currentTaskOwnerRevision;
    final response = await _client
        .get(_listEndpoint, headers: await _headers())
        .timeout(_requestTimeout);
    final payload = _decodeResponse(response, _listEndpoint);
    final tasks = payload['tasks'];
    if (tasks is! List) {
      throw const FormatException('Invalid competition task list response.');
    }
    final rawCurrentOwnerId = payload['current_task_owner_id'];
    if (rawCurrentOwnerId != null &&
        (rawCurrentOwnerId is! String ||
            !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(rawCurrentOwnerId))) {
      throw const FormatException('Invalid current competition task response.');
    }
    final entries = <CompetitionTaskServerEntry>[];
    for (final rawEntry in tasks) {
      if (rawEntry is! Map<String, dynamic>) {
        throw const FormatException('Invalid competition task list response.');
      }
      final task = CompetitionTask.tryParse(rawEntry['task']);
      final updatedAt = DateTime.tryParse(
        rawEntry['updated_at']?.toString() ?? '',
      );
      final ownerId = rawEntry['owner_id'];
      final username = rawEntry['username'];
      final displayName = rawEntry['display_name'];
      if (task == null ||
          updatedAt == null ||
          ownerId is! String ||
          !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(ownerId) ||
          username is! String ||
          username.trim().isEmpty ||
          username.runes.length > 32 ||
          displayName is! String ||
          displayName.runes.length > 48) {
        throw const FormatException('Invalid competition task list response.');
      }
      entries.add(
        CompetitionTaskServerEntry(
          task: task,
          updatedAt: updatedAt,
          ownerId: ownerId.toLowerCase(),
          username: username.trim(),
          displayName: displayName.trim(),
        ),
      );
    }
    final currentOwnerId = rawCurrentOwnerId?.toLowerCase();
    if (revision == _currentTaskOwnerRevision) {
      currentTaskOwnerId.value = currentOwnerId;
    }
    return CompetitionTaskServerList(
      tasks: List.unmodifiable(entries),
      currentTaskOwnerId: currentOwnerId,
    );
  }

  Future<Map<String, String>> _headers() async {
    final authorization = authorizationHeaders;
    final authHeaders = authorization == null
        ? await _accountService.authorizationHeaders()
        : await authorization();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...authHeaders,
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response, Uri endpoint) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'ParaBeacon Server returned HTTP ${response.statusCode}.',
        endpoint,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid ParaBeacon Server response.');
    }
    return decoded;
  }
}
