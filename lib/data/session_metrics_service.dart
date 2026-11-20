import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parabeacon_account_service.dart';
import 'parabeacon_server_settings.dart';
import 'user_agent_settings.dart';

class SessionMetricsService {
  SessionMetricsService({
    http.Client? client,
    this.heartbeatInterval = const Duration(seconds: 60),
    Future<String> Function()? appVersionLoader,
    DateTime Function()? clock,
    String? Function()? accessTokenProvider,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _appVersionLoader = appVersionLoader ?? _loadAppVersion,
       _clock = clock ?? DateTime.now,
       _accessTokenProvider = accessTokenProvider;

  static final SessionMetricsService instance = SessionMetricsService();

  static const installationIdPreferenceKey = 'pb.metrics.installationId';
  static const totalRuntimePreferenceKey = 'pb.metrics.totalRuntimeSec';
  static const pendingQueuePreferenceKey = 'pb.metrics.pendingQueue';
  static const int maxPendingEvents = 100;
  static const Duration pendingEventTtl = Duration(days: 7);
  static const Duration requestTimeout = Duration(seconds: 5);

  final http.Client _client;
  final bool _ownsClient;
  final Duration heartbeatInterval;
  final Future<String> Function() _appVersionLoader;
  final DateTime Function() _clock;
  String? Function()? _accessTokenProvider;
  final Stopwatch _stopwatch = Stopwatch();
  final List<Map<String, dynamic>> _pendingEvents = [];

  Future<void> _ready = Future<void>.value();
  Future<void> _reportQueue = Future<void>.value();
  Future<String> _appVersion = Future<String>.value('unknown+unknown');
  String? Function()? _userIdProvider;
  String? _sessionId;
  String? _hardwareId;
  SharedPreferences? _preferences;
  Timer? _heartbeatTimer;
  int _cachedTotalRuntimeSeconds = 0;
  int _lastAccountedRuntimeSeconds = 0;
  bool _started = false;
  bool _closed = false;

  Future<void> start({
    String? Function()? userIdProvider,
    String? Function()? accessTokenProvider,
  }) async {
    if (_started || _closed) return;
    _started = true;
    _userIdProvider = userIdProvider;
    if (accessTokenProvider != null) {
      _accessTokenProvider = accessTokenProvider;
    }
    _sessionId = _createUuid();
    _stopwatch.start();
    _appVersion = _loadVersionSafely();
    _ready = _initialize();
    _startHeartbeat();
    await reportNow(reason: 'startup');
  }

  Future<void> reportNow({String reason = 'manual'}) {
    final operation = _reportQueue.then((_) async {
      if (!_started || _closed) return;
      await _ready;
      await _report(reason);
    });
    _reportQueue = operation.catchError((Object error) {
      debugPrint('Session metrics update failed (${error.runtimeType}).');
    });
    return _reportQueue;
  }

  void onLifecycleStateChanged(AppLifecycleState state) {
    if (!_started || _closed) return;
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
      unawaited(reportNow(reason: 'resume'));
      return;
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      unawaited(
        reportNow(
          reason: state == AppLifecycleState.detached ? 'exit' : 'background',
        ),
      );
    }
  }

  Future<void> stop() async {
    if (!_started || _closed) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await reportNow(reason: 'exit');
    _started = false;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_ownsClient) _client.close();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      unawaited(reportNow(reason: 'heartbeat'));
    });
  }

  Future<void> _initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final preferences = _preferences!;
      final savedId = preferences.getString(installationIdPreferenceKey);
      _hardwareId = savedId != null && _isUuid(savedId)
          ? savedId
          : _createUuid();
      if (_hardwareId != savedId) {
        await preferences.setString(installationIdPreferenceKey, _hardwareId!);
      }
      _cachedTotalRuntimeSeconds = math.max(
        0,
        preferences.getInt(totalRuntimePreferenceKey) ?? 0,
      );
      _pendingEvents
        ..clear()
        ..addAll(
          _decodePendingEvents(
            preferences.getString(pendingQueuePreferenceKey),
          ),
        );
      await _persistPendingEvents();
    } on Object catch (error) {
      debugPrint(
        'Session metrics local storage unavailable (${error.runtimeType}).',
      );
      _hardwareId ??= _createUuid();
    }
  }

  Future<String> _loadVersionSafely() async {
    try {
      return await _appVersionLoader();
    } on Object catch (error) {
      debugPrint(
        'Session metrics app version unavailable (${error.runtimeType}).',
      );
      return 'unknown+unknown';
    }
  }

  Future<void> _report(String reason) async {
    final runTimeSeconds = reason == 'startup'
        ? 0
        : _stopwatch.elapsed.inSeconds;
    final additionalRuntime = math.max(
      0,
      runTimeSeconds - _lastAccountedRuntimeSeconds,
    );
    _lastAccountedRuntimeSeconds = math.max(
      _lastAccountedRuntimeSeconds,
      runTimeSeconds,
    );
    _cachedTotalRuntimeSeconds += additionalRuntime;
    final preferences = _preferences;
    if (preferences != null) {
      try {
        await preferences.setInt(
          totalRuntimePreferenceKey,
          _cachedTotalRuntimeSeconds,
        );
      } on Object catch (error) {
        debugPrint(
          'Session metrics runtime cache unavailable (${error.runtimeType}).',
        );
      }
    }

    final accessToken = _safeAccessToken();
    final userId = accessToken == null ? null : _safeUserId();
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final localNow = _clock();
    final now = localNow.toUtc();
    final payload = <String, dynamic>{
      'event_id': _createUuid(),
      'session_id': _sessionId,
      'hardware_id': _hardwareId,
      'app_version': await _appVersion,
      'user_id': userId,
      'run_time_sec': runTimeSeconds,
      'total_runtime_sec': _cachedTotalRuntimeSeconds,
      'client_timestamp': now.toIso8601String(),
      'diagnostics': <String, dynamic>{
        'os': defaultTargetPlatform.name,
        'locale': locale.toString(),
        'timezone': localNow.timeZoneName,
        'event_type': reason,
      },
    };

    await _enqueue(payload);
    for (final pending in List<Map<String, dynamic>>.of(_pendingEvents)) {
      final pendingPayload = pending['payload'];
      if (pendingPayload is! Map<String, dynamic>) {
        _pendingEvents.remove(pending);
        await _persistPendingEvents();
        continue;
      }
      if (!await _post(pendingPayload)) return;
      _pendingEvents.remove(pending);
      await _persistPendingEvents();
    }
  }

  String? _safeUserId() {
    try {
      final value = _userIdProvider?.call()?.trim();
      return value == null || value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  String? _safeAccessToken() {
    try {
      final value = _accessTokenProvider?.call()?.trim();
      return value == null || value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  Future<bool> _post(Map<String, dynamic> payload) async {
    final uri = ParaBeaconServerSettings.instance.selectedBaseUri.replace(
      path: '/api/v1/metrics/session',
      query: null,
      fragment: null,
    );
    try {
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['User-Agent'] = UserAgentSettings.instance.forRequest(uri)
        ..body = jsonEncode(payload);
      final accessToken = _safeAccessToken();
      if (accessToken != null) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
      return await (() async {
        final response = await _client.send(request);
        await response.stream.drain<void>();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
        debugPrint(
          'Session metrics endpoint returned HTTP ${response.statusCode}.',
        );
        return false;
      })().timeout(requestTimeout);
    } on Object catch (error) {
      debugPrint('Session metrics delivery failed (${error.runtimeType}).');
    }
    return false;
  }

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    _pendingEvents.add({
      'queued_at': _clock().toUtc().toIso8601String(),
      'payload': payload,
    });
    if (_pendingEvents.length > maxPendingEvents) {
      _pendingEvents.removeRange(0, _pendingEvents.length - maxPendingEvents);
    }
    await _persistPendingEvents();
  }

  List<Map<String, dynamic>> _decodePendingEvents(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];
      final cutoff = _clock().toUtc().subtract(pendingEventTtl);
      final events = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final queuedAt = DateTime.tryParse(item['queued_at']?.toString() ?? '');
        final payload = item['payload'];
        if (queuedAt == null ||
            queuedAt.toUtc().isBefore(cutoff) ||
            payload is! Map) {
          continue;
        }
        events.add({
          'queued_at': queuedAt.toUtc().toIso8601String(),
          'payload': Map<String, dynamic>.from(payload),
        });
      }
      if (events.length > maxPendingEvents) {
        return events.sublist(events.length - maxPendingEvents);
      }
      return events;
    } on Object {
      return [];
    }
  }

  Future<void> _persistPendingEvents() async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setString(
        pendingQueuePreferenceKey,
        jsonEncode(_pendingEvents),
      );
    } on Object catch (error) {
      debugPrint(
        'Session metrics retry queue unavailable (${error.runtimeType}).',
      );
    }
  }

  static Future<String> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version}+$build';
  }

  static String _createUuid() {
    final bytes = List<int>.generate(
      16,
      (_) => math.Random.secure().nextInt(256),
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
