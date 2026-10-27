import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'flight_data.dart';
import 'flight_state.dart';
import 'live_tracking_proxy_auth_service.dart';

class LiveTrackingProxyConfig {
  LiveTrackingProxyConfig({
    required this.apiBaseUri,
    this.sessionStartPath = '/v1/flight/start',
    this.pointsPath = '/v1/flight/{session_id}/points',
    this.requestTimeout = const Duration(seconds: 15),
    this.uploadInterval = const Duration(seconds: 5),
    this.maximumBatchPoints = 50,
    this.maximumBufferedPoints = 5000,
  }) {
    if (apiBaseUri.scheme != 'https' ||
        apiBaseUri.host.isEmpty ||
        apiBaseUri.userInfo.isNotEmpty ||
        apiBaseUri.hasQuery ||
        apiBaseUri.hasFragment ||
        _isDisallowedHost(apiBaseUri.host)) {
      throw ArgumentError.value(
        apiBaseUri,
        'apiBaseUri',
        'A public HTTPS proxy origin is required.',
      );
    }
    if (!sessionStartPath.startsWith('/') ||
        !pointsPath.startsWith('/') ||
        !pointsPath.contains('{session_id}')) {
      throw ArgumentError('Proxy endpoint paths are invalid.');
    }
    if (maximumBatchPoints < 1 || maximumBufferedPoints < maximumBatchPoints) {
      throw ArgumentError('Proxy point limits are invalid.');
    }
    if (requestTimeout <= Duration.zero || uploadInterval <= Duration.zero) {
      throw ArgumentError('Proxy request durations must be positive.');
    }
  }

  factory LiveTrackingProxyConfig.fromEnvironment() {
    const rawBaseUri = String.fromEnvironment(
      'PARABEACON_LIVE_TRACKING_PROXY',
      defaultValue: 'https://api.myparabeacon-proxy.com',
    );
    return LiveTrackingProxyConfig(apiBaseUri: Uri.parse(rawBaseUri));
  }

  final Uri apiBaseUri;
  final String sessionStartPath;
  final String pointsPath;
  final Duration requestTimeout;
  final Duration uploadInterval;
  final int maximumBatchPoints;
  final int maximumBufferedPoints;

  Uri get sessionStartUri => apiBaseUri.resolve(sessionStartPath);

  Uri pointsUri(String sessionId) => apiBaseUri.resolve(
    pointsPath.replaceAll('{session_id}', Uri.encodeComponent(sessionId)),
  );
}

bool _isDisallowedHost(String host) {
  final normalized = host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
  if (normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.local') ||
      normalized.endsWith('.internal')) {
    return true;
  }
  final parts = normalized.split('.');
  if (parts.length == 4 && parts.every((part) => int.tryParse(part) != null)) {
    final octets = parts.map(int.parse).toList(growable: false);
    if (octets.any((octet) => octet < 0 || octet > 255)) return true;
    final first = octets[0];
    final second = octets[1];
    return first == 0 ||
        first == 9 ||
        first == 10 ||
        first == 11 ||
        first == 21 ||
        first == 30 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }
  if (normalized.contains(':')) {
    return normalized == '::' ||
        normalized == '::1' ||
        normalized.startsWith('fc') ||
        normalized.startsWith('fd') ||
        normalized.startsWith('fe80:');
  }
  return false;
}

@immutable
class ProxyLiveTrackpoint {
  const ProxyLiveTrackpoint({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.speedMetersPerSecond,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double speedMetersPerSecond;
  final DateTime timestamp;

  Map<String, Object> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'altitude': altitudeMeters,
    'speed': speedMetersPerSecond,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };

  static ProxyLiveTrackpoint? fromFlightData(FlightData data) {
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
    return ProxyLiveTrackpoint(
      latitude: data.latitude,
      longitude: data.longitude,
      altitudeMeters: altitude,
      speedMetersPerSecond: (data.groundSpeed / 3.6).clamp(0, 200).toDouble(),
      timestamp: timestamp.toUtc(),
    );
  }

  static ProxyLiveTrackpoint? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final lat = (value['lat'] as num?)?.toDouble();
    final lon = (value['lon'] as num?)?.toDouble();
    final altitude = (value['altitude'] as num?)?.toDouble();
    final speed = (value['speed'] as num?)?.toDouble();
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
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return null;
    }
    return ProxyLiveTrackpoint(
      latitude: lat,
      longitude: lon,
      altitudeMeters: altitude,
      speedMetersPerSecond: speed,
      timestamp: timestamp.toUtc(),
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
  final ProxyLiveTrackpoint point;

  Map<String, Object> toJson() => {
    'session_id': sessionId,
    'point': point.toJson(),
  };

  static QueuedProxyPoint? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final sessionId = value['session_id'];
    final point = ProxyLiveTrackpoint.fromJson(value['point']);
    if (sessionId is! String || sessionId.isEmpty || point == null) return null;
    return QueuedProxyPoint(sessionId: sessionId, point: point);
  }
}

enum LiveTrackingProxyState { idle, starting, active, retrying, failed }

/// Client for ParaBeacon's own proxy API. It uses authenticated REST for both
/// session creation and point batches; the returned socket_url is reserved for
/// a future WebSocket transport and is not needed by this HTTP-batch mode.
class LiveTrackingService extends ChangeNotifier {
  LiveTrackingService({
    required LiveTrackingProxyConfig config,
    required LiveTrackingProxyAuthProvider authProvider,
    LiveTrackingProxyPointStore? pointStore,
    http.Client? httpClient,
  }) : _config = config,
       _authProvider = authProvider,
       _pointStore =
           pointStore ?? SharedPreferencesLiveTrackingProxyPointStore(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  static final LiveTrackingService instance = LiveTrackingService(
    config: LiveTrackingProxyConfig.fromEnvironment(),
    authProvider: LiveTrackingProxyAuthService.instance,
  );

  final LiveTrackingProxyConfig _config;
  final LiveTrackingProxyAuthProvider _authProvider;
  final LiveTrackingProxyPointStore _pointStore;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final List<QueuedProxyPoint> _pending = [];

  LiveTrackingProxyState _state = LiveTrackingProxyState.idle;
  LiveTrackingProxyState get state => _state;
  int get pendingPointCount => _pending.length;
  String? _lastErrorCode;
  String? get lastErrorCode => _lastErrorCode;
  String? _sessionId;
  String? get sessionId => _sessionId;

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
    if (!_disposed) _setState(LiveTrackingProxyState.idle);
  }

  Future<void> _loadQueue() {
    if (_loadedQueue) return Future<void>.value();
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
          _setState(LiveTrackingProxyState.failed);
          _scheduleRetry();
        });
  }

  bool get _shouldTrack =>
      _flightState?.isFlying == true && (_isEnabled?.call() ?? false);

  Future<void> _syncLifecycle() async {
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
      _sessionId = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      _uploadTimer?.cancel();
      _uploadTimer = null;
      _setState(LiveTrackingProxyState.idle);
      unawaited(_flushPending());
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
    _setState(LiveTrackingProxyState.starting);
    try {
      final response = await _sendJson(
        method: 'POST',
        uri: _config.sessionStartUri,
        body: {
          'pilot_id': pilotId,
          'start_time': startTime.toUtc().toIso8601String(),
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
        _setState(LiveTrackingProxyState.idle);
        return;
      }
      _sessionId = sessionId.trim();
      _flushWhileIdle = false;
      _lastPointTimestamp = null;
      _lastErrorCode = null;
      _retryAttempt = 0;
      _setState(LiveTrackingProxyState.active);
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
    final point = ProxyLiveTrackpoint.fromFlightData(snapshot);
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

  Future<void> _flushPending() async {
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
      if (_state == LiveTrackingProxyState.retrying) {
        _setState(
          _sessionId == null
              ? LiveTrackingProxyState.idle
              : LiveTrackingProxyState.active,
        );
      }
    } on Object catch (error) {
      _lastErrorCode = _errorCode(error);
      if (_sessionId != null) _setState(LiveTrackingProxyState.retrying);
      _scheduleRetry();
    } finally {
      _uploading = false;
    }
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
    final exponent = _retryAttempt.clamp(0, 6).toInt();
    final seconds = (1 << exponent).clamp(2, 60).toInt();
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

  void _setState(LiveTrackingProxyState next) {
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
