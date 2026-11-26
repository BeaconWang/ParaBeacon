import 'dart:convert';

import 'package:http/http.dart' as http;

import '../parabeacon_account_service.dart';
import '../parabeacon_server_config.dart';
import '../user_agent_settings.dart';
import 'competition_task.dart';

class CompetitionTaskServerEntry {
  const CompetitionTaskServerEntry({
    required this.task,
    required this.updatedAt,
    required this.username,
    required this.displayName,
  });

  final CompetitionTask task;
  final DateTime updatedAt;
  final String username;
  final String displayName;
}

class CompetitionTaskServerService {
  CompetitionTaskServerService({
    ParaBeaconAccountService? accountService,
    this.authorizationHeaders,
    http.Client? client,
    Uri? listEndpoint,
    Uri? uploadEndpoint,
  }) : _accountService = accountService ?? ParaBeaconAccountService.instance,
       _client = UserAgentHttpClient(innerClient: client),
       _listEndpointOverride = listEndpoint,
       _uploadEndpointOverride = uploadEndpoint;

  static final CompetitionTaskServerService instance =
      CompetitionTaskServerService();
  static const _requestTimeout = Duration(seconds: 30);

  final ParaBeaconAccountService _accountService;
  final Future<Map<String, String>> Function()? authorizationHeaders;
  final http.Client _client;
  final Uri? _listEndpointOverride;
  final Uri? _uploadEndpointOverride;

  Uri get _listEndpoint =>
      _listEndpointOverride ??
      ParaBeaconServerConfig.apiBaseUri.resolve('/api/v1/competition-tasks');
  Uri get _uploadEndpoint =>
      _uploadEndpointOverride ??
      ParaBeaconServerConfig.apiBaseUri.resolve(
        '/api/v1/user/competition-task',
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
  }

  Future<List<CompetitionTaskServerEntry>> listTasks() async {
    final response = await _client
        .get(_listEndpoint, headers: await _headers())
        .timeout(_requestTimeout);
    final payload = _decodeResponse(response, _listEndpoint);
    final tasks = payload['tasks'];
    if (tasks is! List) {
      throw const FormatException('Invalid competition task list response.');
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
      final username = rawEntry['username'];
      final displayName = rawEntry['display_name'];
      if (task == null ||
          updatedAt == null ||
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
          username: username.trim(),
          displayName: displayName.trim(),
        ),
      );
    }
    return List.unmodifiable(entries);
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
