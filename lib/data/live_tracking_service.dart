import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'flight_data.dart';
import 'flight_state.dart';
import 'live_tracking_config.dart';
import 'live_tracking_proxy_auth_service.dart';
import 'user_agent_settings.dart';

@immutable
class LiveTrackpoint {
  const LiveTrackpoint({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.groundSpeedMetersPerSecond,
    required this.timestamp,
    this.bearingDegrees,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double groundSpeedMetersPerSecond;
  final DateTime timestamp;
  final double? bearingDegrees;

  double get speedMetersPerSecond => groundSpeedMetersPerSecond;

  Map<String, Object?> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'altitude': altitudeMeters,
    'speed': groundSpeedMetersPerSecond,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (bearingDegrees != null) 'bearing': bearingDegrees,
  };

  static LiveTrackpoint? fromFlightData(FlightData data) {
    if (!data.hasFix || data.isMockLocation) return null;
    if (!data.latitude.isFinite ||
        !data.longitude.isFinite ||
        data.latitude < -90 ||
        data.latitude > 90 ||
        data.longitude < -180 ||
        data.longitude > 180) {
      return null;
    }
    final timestamp = data.gpsTimestamp ?? data.timestamp;
    if (timestamp == null) return null;
    final altitude = data.gpsAltitude ?? data.altitude;
    if (!altitude.isFinite || !data.groundSpeed.isFinite) return null;
    final heading = data.heading;
    final bearing = !data.hasHeading || !heading.isFinite
        ? null
        : heading >= 0 && heading < 360
        ? heading
        : ((heading % 360) + 360) % 360;
    return LiveTrackpoint(
      latitude: data.latitude,
      longitude: data.longitude,
      altitudeMeters: altitude,
      groundSpeedMetersPerSecond: (data.groundSpeed / 3.6)
          .clamp(0, 200)
          .toDouble(),
      timestamp: timestamp.toUtc(),
      bearingDegrees: bearing,
    );
  }

  static LiveTrackpoint? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    double? number(Object? item) => item is num ? item.toDouble() : null;
    final lat = number(value['lat']);
    final lon = number(value['lon']);
    final altitude = number(value['altitude']);
    final speed = number(value['speed'] ?? value['ground_speed']);
    final rawBearing = value['bearing'];
    final bearing = number(rawBearing);
    final timestampValue = value['timestamp'];
    final timestamp = timestampValue is String
        ? DateTime.tryParse(timestampValue)
        : null;
    if (lat == null ||
        lon == null ||
        altitude == null ||
        speed == null ||
        timestamp == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        !altitude.isFinite ||
        !speed.isFinite ||
        (rawBearing != null &&
            (bearing == null ||
                !bearing.isFinite ||
                bearing < 0 ||
                bearing >= 360)) ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return null;
    }
    return LiveTrackpoint(
      latitude: lat,
      longitude: lon,
      altitudeMeters: altitude,
      groundSpeedMetersPerSecond: speed,
      timestamp: timestamp.toUtc(),
      bearingDegrees: bearing,
    );
  }
}

abstract interface class LiveTrackingProxyPointStore {
  Future<List<QueuedProxyPoint>> load();

  Future<void> save(List<QueuedProxyPoint> points);
}

class SharedPreferencesLiveTrackingProxyPointStore
    implements LiveTrackingProxyPointStore {
  SharedPreferencesLiveTrackingProxyPointStore({
    this.storageKey = 'pb.liveTracking.proxyQueue.v1',
  });

  final String storageKey;

  @override
  Future<List<QueuedProxyPoint>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(QueuedProxyPoint.fromJson)
          .whereType<QueuedProxyPoint>()
          .toList(growable: true);
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> save(List<QueuedProxyPoint> points) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(points.map((point) => point.toJson()).toList()),
    );
  }
}

@immutable
class QueuedProxyPoint {
  const QueuedProxyPoint({required this.sessionId, required this.point});

  final String sessionId;
  final LiveTrackpoint point;

  Map<String, Object> toJson() => {
    'session_id': sessionId,
    'point': point.toJson(),
  };

  static QueuedProxyPoint? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final sessionId = value['session_id'];
    final point = LiveTrackpoint.fromJson(value['point']);
    if (sessionId is! String || sessionId.isEmpty || point == null) return null;
    return QueuedProxyPoint(sessionId: sessionId, point: point);
  }
}

enum LiveTrackingConnectionState {
  idle,
  connecting,
  active,
  reconnecting,
  disconnected,
}

/// Client for ParaBeacon's own proxy API. It uses authenticated REST for both
/// session creation and point batches; the returned socket_url is reserved for
/// a future WebSocket transport and is not needed by this HTTP-batch mode.
class LiveTrackingService extends ChangeNotifier {
  LiveTrackingService({
    required LiveTrackingConfig config,
    required LiveTrackingProxyAuthProvider authProvider,
    LiveTrackingProxyPointStore? pointStore,
    http.Client? httpClient,
  }) : _config = config,
       _configured = true,
       _authProvider = authProvider,
       _pointStore =
           pointStore ?? SharedPreferencesLiveTrackingProxyPointStore(),
       _httpClient = httpClient == null
           ? UserAgentHttpClient()
           : UserAgentHttpClient(innerClient: httpClient),
       _ownsHttpClient = httpClient == null;

  LiveTrackingService._singleton()
    : _authProvider = LiveTrackingProxyAuthService.instance,
      _pointStore = SharedPreferencesLiveTrackingProxyPointStore(),
      _httpClient = UserAgentHttpClient(),
      _ownsHttpClient = true;

  static final LiveTrackingService instance = LiveTrackingService._singleton();

  late LiveTrackingConfig _config;
  bool _configured = false;
  final LiveTrackingProxyAuthProvider _authProvider;
  final LiveTrackingProxyPointStore _pointStore;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final List<QueuedProxyPoint> _pending = [];

  LiveTrackingConnectionState _state = LiveTrackingConnectionState.idle;
  LiveTrackingConnectionState get state => _state;
  int get pendingPointCount => _pending.length;
  String? _lastErrorCode;
  String? get lastErrorCode => _lastErrorCode;
  String? _sessionId;
  String? get sessionId => _sessionId;
  bool get isConfigured => _configured;

  void configure(LiveTrackingConfig? config) {
    if (_sessionId != null || _starting || _endingSessions.isNotEmpty) {
      throw StateError(
        'Cannot replace live-tracking config while a session runs.',
      );
    }
    if (config == null) {
      _configured = false;
      _flushWhileIdle = false;
      _uploadTimer?.cancel();
      _uploadTimer = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      _lastErrorCode = 'config_load_failed';
      _setState(LiveTrackingConnectionState.disconnected);
      return;
    }
    _config = config;
    _configured = true;
    _lastErrorCode = null;
    _setState(LiveTrackingConnectionState.idle);
    _queueLifecycleSync();
  }

  FlightDataView? _data;
  FlightState? _flightState;
  Listenable? _eligibilitySource;
  bool Function()? _isEnabled;
  String? Function()? _pilotId;
  bool _loadedQueue = false;
  Future<void>? _queueLoadFuture;
  bool _starting = false;
  bool _uploading = false;
  bool _flushWhileIdle = false;
  Future<void>? _uploadFuture;
  final Set<String> _endingSessions = <String>{};
  Future<void> _sessionEndTail = Future<void>.value();
  bool _disposed = false;
  int _retryAttempt = 0;
  int _bindingEpoch = 0;
  DateTime? _lastPointTimestamp;
  Timer? _uploadTimer;
  Timer? _retryTimer;
  Future<void> _syncTail = Future<void>.value();
  Future<void> _saveTail = Future<void>.value();

  void bind({
    required FlightDataView data,
    required FlightState flightState,
    required bool Function() isEnabled,
    required String? Function() pilotId,
    Listenable? eligibilitySource,
  }) {
    unbind();
    _data = data;
    _flightState = flightState;
    _isEnabled = isEnabled;
    _pilotId = pilotId;
    _eligibilitySource = eligibilitySource;
    data.addListener(_onDataChanged);
    flightState.addListener(_queueLifecycleSync);
    eligibilitySource?.addListener(_queueLifecycleSync);
    unawaited(_loadQueue());
    _queueLifecycleSync();
  }

  void unbind() {
    _bindingEpoch++;
    final sessionId = _sessionId;
    if (sessionId != null) _queueSessionEnd(sessionId);
    _sessionId = null;
    _flushWhileIdle = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _data?.removeListener(_onDataChanged);
    _flightState?.removeListener(_queueLifecycleSync);
    _eligibilitySource?.removeListener(_queueLifecycleSync);
    _data = null;
    _flightState = null;
    _eligibilitySource = null;
    _isEnabled = null;
    _pilotId = null;
    if (!_disposed) _setState(LiveTrackingConnectionState.idle);
  }

  Future<void> _loadQueue() {
    if (!_configured || _loadedQueue) return Future<void>.value();
    return _queueLoadFuture ??= _loadQueueOnce();
  }

  Future<void> _loadQueueOnce() async {
    try {
      final stored = await _pointStore.load();
      final retained = stored.length <= _config.maximumBufferedPoints
          ? stored
          : stored.sublist(stored.length - _config.maximumBufferedPoints);
      _pending
        ..clear()
        ..addAll(retained);
    } on Object {
      _lastErrorCode = 'queue_load_failed';
    } finally {
      _loadedQueue = true;
      _queueLoadFuture = null;
      _notify();
      _queueLifecycleSync();
    }
  }

  void _queueLifecycleSync() {
    if (_disposed) return;
    _syncTail = _syncTail
        .catchError((Object _) {})
        .then((_) => _syncLifecycle())
        .catchError((Object error) {
          _lastErrorCode = _errorCode(error);
          _setState(LiveTrackingConnectionState.reconnecting);
          _scheduleRetry();
        });
  }

  bool get _shouldTrack =>
      _configured &&
      _flightState?.isFlying == true &&
      (_isEnabled?.call() ?? false);

  Future<void> _syncLifecycle() async {
    if (!_configured) return;
    if (!_loadedQueue) {
      await _loadQueue();
      return;
    }
    if (_shouldTrack) {
      if (_sessionId == null && !_starting) await _startSession();
      return;
    }
    if (_sessionId != null || _starting) {
      _flushWhileIdle = _sessionId != null && (_isEnabled?.call() ?? false);
      final sessionId = _sessionId;
      if (sessionId != null) _queueSessionEnd(sessionId);
      _sessionId = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      _uploadTimer?.cancel();
      _uploadTimer = null;
      _setState(LiveTrackingConnectionState.disconnected);
    } else {
      _retryTimer?.cancel();
      _retryTimer = null;
      if (_state == LiveTrackingConnectionState.connecting ||
          _state == LiveTrackingConnectionState.reconnecting) {
        _setState(LiveTrackingConnectionState.disconnected);
      }
    }
  }

  Future<void> _startSession() async {
    if (_starting || !_shouldTrack) return;
    final bindingEpoch = _bindingEpoch;
    final pilotId = _pilotId?.call()?.trim();
    final startTime = _flightState?.startedAt;
    if (pilotId == null || pilotId.isEmpty || startTime == null) {
      throw const LiveTrackingProxyException('pilot_or_start_time_missing');
    }
    _starting = true;
    _setState(LiveTrackingConnectionState.connecting);
    try {
      final config = _config;
      final response = await _sendJson(
        method: 'POST',
        uri: config.sessionStartUri,
        body: {
          'pilot_id': pilotId,
          'start_time': startTime.toUtc().toIso8601String(),
          if (config.channelIds.isNotEmpty) 'channel_ids': config.channelIds,
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LiveTrackingProxyException('session_http_${response.statusCode}');
      }
      final decoded = _decodeResponse(response.body);
      final sessionId = decoded?['session_id'];
      final socketUrl = decoded?['socket_url'];
      if (sessionId is! String ||
          sessionId.trim().isEmpty ||
          socketUrl is! String ||
          socketUrl.trim().isEmpty) {
        throw const LiveTrackingProxyException('invalid_session_response');
      }
      if (bindingEpoch != _bindingEpoch || !_shouldTrack) {
        _queueSessionEnd(sessionId.trim());
        _setState(LiveTrackingConnectionState.disconnected);
        return;
      }
      _sessionId = sessionId.trim();
      _flushWhileIdle = false;
      _lastPointTimestamp = null;
      _lastErrorCode = null;
      _retryAttempt = 0;
      _setState(LiveTrackingConnectionState.active);
      _uploadTimer?.cancel();
      _uploadTimer = Timer.periodic(_config.uploadInterval, (_) {
        unawaited(_flushPending());
      });
      _onDataChanged();
      unawaited(_flushPending());
    } finally {
      _starting = false;
    }
  }

  void _onDataChanged() {
    if (!_shouldTrack || _sessionId == null) return;
    final snapshot = _data?.data;
    if (snapshot == null) return;
    final point = LiveTrackpoint.fromFlightData(snapshot);
    if (point == null) return;
    final previous = _lastPointTimestamp;
    if (previous != null && !point.timestamp.isAfter(previous)) return;
    _lastPointTimestamp = point.timestamp;
    _pending.add(QueuedProxyPoint(sessionId: _sessionId!, point: point));
    if (_pending.length > _config.maximumBufferedPoints) {
      _pending.removeRange(0, _pending.length - _config.maximumBufferedPoints);
      _lastErrorCode = 'queue_limit_reached';
    }
    _notify();
    unawaited(_persistQueue());
    if (_pending.length >= _config.maximumBatchPoints) {
      unawaited(_flushPending());
    }
  }

  Future<void> _flushPending() {
    final active = _uploadFuture;
    if (active != null) return active;
    final task = _flushPendingOnce();
    _uploadFuture = task;
    return task.whenComplete(() {
      if (identical(_uploadFuture, task)) _uploadFuture = null;
    });
  }

  Future<void> _flushPendingOnce() async {
    if (_disposed ||
        _uploading ||
        _pending.isEmpty ||
        (!_shouldTrack && !_flushWhileIdle)) {
      return;
    }
    _uploading = true;
    try {
      while (_pending.isNotEmpty) {
        final sessionId = _pending.first.sessionId;
        final count = _pending
            .takeWhile((queued) => queued.sessionId == sessionId)
            .length
            .clamp(0, _config.maximumBatchPoints)
            .toInt();
        if (count == 0) return;
        final batch = List<QueuedProxyPoint>.unmodifiable(_pending.take(count));
        final response = await _sendJson(
          method: 'POST',
          uri: _config.pointsUri(sessionId),
          body: {
            'session_id': sessionId,
            'trackpoints': batch
                .map((queued) => queued.point.toJson())
                .toList(),
          },
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw LiveTrackingProxyException(
            'points_http_${response.statusCode}',
          );
        }
        final prefixMatches =
            batch.length <= _pending.length &&
            List<bool>.generate(
              batch.length,
              (index) => identical(_pending[index], batch[index]),
            ).every((matches) => matches);
        if (!prefixMatches) return;
        _pending.removeRange(0, batch.length);
        _lastErrorCode = null;
        _retryAttempt = 0;
        _notify();
        await _persistQueue();
      }
      if (_pending.isEmpty) _flushWhileIdle = false;
      if (_state == LiveTrackingConnectionState.reconnecting) {
        _setState(
          _sessionId == null
              ? LiveTrackingConnectionState.disconnected
              : LiveTrackingConnectionState.active,
        );
      }
    } on Object catch (error) {
      _lastErrorCode = _errorCode(error);
      _setState(LiveTrackingConnectionState.reconnecting);
      _scheduleRetry();
    } finally {
      _uploading = false;
    }
  }

  void _queueSessionEnd(String sessionId) {
    if (sessionId.isEmpty || !_endingSessions.add(sessionId)) return;
    final stopUri = _config.sessionStopUri(sessionId);
    _sessionEndTail = _sessionEndTail.then((_) async {
      try {
        _flushWhileIdle = true;
        await _flushPending();
        final pendingCount = _pending.length;
        _pending.removeWhere((queued) => queued.sessionId == sessionId);
        if (_pending.length != pendingCount) {
          _lastErrorCode ??= 'final_points_dropped';
          await _persistQueue();
        }
        final response = await _sendJson(
          method: 'POST',
          uri: stopUri,
          body: {
            'session_id': sessionId,
            'end_time': DateTime.now().toUtc().toIso8601String(),
          },
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw LiveTrackingProxyException(
            'session_stop_http_${response.statusCode}',
          );
        }
      } on Object catch (error) {
        _lastErrorCode = _errorCode(error);
      } finally {
        _endingSessions.remove(sessionId);
        if (_pending.isEmpty) _flushWhileIdle = false;
        if (_sessionId == null) {
          _setState(LiveTrackingConnectionState.disconnected);
        }
        _notify();
      }
    });
  }

  Future<http.Response> _sendJson({
    required String method,
    required Uri uri,
    required Map<String, Object?> body,
  }) async {
    if (uri.scheme != 'https' || uri.host != _config.apiBaseUri.host) {
      throw const LiveTrackingProxyException('untrusted_proxy_uri');
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...await _authProvider.authorizationHeaders(),
    };
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..body = jsonEncode(body);
    final streamed = await _httpClient
        .send(request)
        .timeout(_config.requestTimeout);
    return http.Response.fromStream(streamed).timeout(_config.requestTimeout);
  }

  Map<String, dynamic>? _decodeResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _persistQueue() {
    final snapshot = List<QueuedProxyPoint>.unmodifiable(_pending);
    _saveTail = _saveTail
        .catchError((Object _) {})
        .then((_) => _pointStore.save(snapshot))
        .catchError((Object error) {
          _lastErrorCode = 'queue_save_failed';
          _notify();
        });
    return _saveTail;
  }

  void _scheduleRetry() {
    if (_disposed || _retryTimer != null) return;
    final exponent = _retryAttempt.clamp(0, 5).toInt();
    final seconds = (2 * (1 << exponent)).clamp(2, 60).toInt();
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _retryTimer = null;
      if (_shouldTrack && _sessionId == null) {
        _queueLifecycleSync();
      } else {
        unawaited(_flushPending());
      }
    });
  }

  String _errorCode(Object error) => error is LiveTrackingProxyException
      ? error.code
      : error is LiveTrackingProxyAuthException
      ? error.code
      : 'proxy_network_error';

  void _setState(LiveTrackingConnectionState next) {
    if (_state == next) return;
    _state = next;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> shutdown() async {
    unbind();
    _retryTimer?.cancel();
    _uploadTimer?.cancel();
    await _sessionEndTail.catchError((Object _) {});
    await _saveTail.catchError((Object _) {});
    if (_ownsHttpClient) _httpClient.close();
    _disposed = true;
    dispose();
  }

  @override
  void dispose() {
    if (!_disposed) {
      unbind();
      _disposed = true;
      _retryTimer?.cancel();
      _uploadTimer?.cancel();
      if (_ownsHttpClient) _httpClient.close();
    }
    super.dispose();
  }
}

class LiveTrackingProxyException implements Exception {
  const LiveTrackingProxyException(this.code);

  final String code;

  @override
  String toString() => 'LiveTrackingProxyException($code)';
}
