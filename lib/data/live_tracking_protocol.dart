import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'flight_data.dart';
import 'flight_state.dart';
import 'flight_timestamp.dart';
import 'live_tracking_socket_connector.dart';

/// Builds request headers without embedding any account keys or credentials.
/// Implementations should obtain credentials from secure storage or a trusted
/// authentication service and must not log returned header values.
abstract interface class LiveTrackingAuthProvider {
  Future<Map<String, String>> restHeaders();

  Future<Map<String, String>> webSocketHeaders(Uri uri);
}

/// Functional adapter for app-specific auth schemes (OAuth, HMAC signing, etc.).
class CallbackLiveTrackingAuthProvider implements LiveTrackingAuthProvider {
  const CallbackLiveTrackingAuthProvider({
    required this.restHeaderBuilder,
    required this.webSocketHeaderBuilder,
  });

  final Future<Map<String, String>> Function() restHeaderBuilder;
  final Future<Map<String, String>> Function(Uri uri) webSocketHeaderBuilder;

  @override
  Future<Map<String, String>> restHeaders() => restHeaderBuilder();

  @override
  Future<Map<String, String>> webSocketHeaders(Uri uri) =>
      webSocketHeaderBuilder(uri);
}

/// Network policy and operational limits for a live-tracking connection.
class LiveTrackingConfig {
  LiveTrackingConfig({
    required this.apiBaseUri,
    this.flightEndpoint = 'flight',
    this.requestTimeout = const Duration(seconds: 15),
    this.socketReadyTimeout = const Duration(seconds: 15),
    this.transportPingInterval = const Duration(seconds: 20),
    this.uploadInterval = const Duration(seconds: 5),
    this.acknowledgementTimeout = const Duration(seconds: 30),
    this.initialReconnectDelay = const Duration(seconds: 2),
    this.maximumReconnectDelay = const Duration(minutes: 5),
    this.maximumBufferedPoints = 5000,
    this.maximumChunkPoints = 100,
    Set<String>? allowedWebSocketHosts,
  }) : allowedWebSocketHosts = Set.unmodifiable(
         (allowedWebSocketHosts ?? {apiBaseUri.host}).map(
           (host) => host.toLowerCase(),
         ),
       ) {
    if (apiBaseUri.scheme != 'https' ||
        apiBaseUri.host.isEmpty ||
        apiBaseUri.userInfo.isNotEmpty ||
        _isDisallowedHost(apiBaseUri.host)) {
      throw ArgumentError.value(
        apiBaseUri,
        'apiBaseUri',
        'A public HTTPS origin is required.',
      );
    }
    if (flightEndpoint.isEmpty ||
        flightEndpoint.startsWith('/') ||
        Uri.tryParse(flightEndpoint)?.hasAuthority == true) {
      throw ArgumentError.value(flightEndpoint, 'flightEndpoint');
    }
    if (maximumBufferedPoints < 1 || maximumChunkPoints < 1) {
      throw ArgumentError('Point limits must be positive.');
    }
    if (uploadInterval <= Duration.zero ||
        acknowledgementTimeout <= Duration.zero ||
        transportPingInterval <= Duration.zero ||
        initialReconnectDelay <= Duration.zero ||
        maximumReconnectDelay < initialReconnectDelay) {
      throw ArgumentError('Connection durations are invalid.');
    }
    for (final host in this.allowedWebSocketHosts) {
      if (host.isEmpty || _isDisallowedHost(host)) {
        throw ArgumentError.value(host, 'allowedWebSocketHosts');
      }
    }
  }

  final Uri apiBaseUri;
  final String flightEndpoint;
  final Duration requestTimeout;
  final Duration socketReadyTimeout;
  final Duration transportPingInterval;
  final Duration uploadInterval;
  final Duration acknowledgementTimeout;
  final Duration initialReconnectDelay;
  final Duration maximumReconnectDelay;
  final int maximumBufferedPoints;
  final int maximumChunkPoints;
  final Set<String> allowedWebSocketHosts;

  Uri get flightUri {
    final base = apiBaseUri.path.endsWith('/')
        ? apiBaseUri
        : apiBaseUri.replace(path: '${apiBaseUri.path}/');
    return base.resolve(flightEndpoint);
  }

  void validateWebSocketUri(Uri uri) {
    if (uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !allowedWebSocketHosts.contains(uri.host.toLowerCase()) ||
        _isDisallowedHost(uri.host)) {
      throw const FormatException('Untrusted WebSocket endpoint.');
    }
  }
}

bool _isDisallowedHost(String host) {
  final normalized = host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
  if (normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.local') ||
      normalized.endsWith('.internal')) {
    return true;
  }
  final octets = normalized.split('.');
  if (octets.length == 4 &&
      octets.every((part) => int.tryParse(part) != null)) {
    final values = octets.map(int.parse).toList(growable: false);
    if (values.any((value) => value < 0 || value > 255)) return true;
    final first = values[0];
    final second = values[1];
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

/// Device metadata nested in the session-create request.
@immutable
class LiveTrackingDeviceInfo {
  const LiveTrackingDeviceInfo({
    required this.device,
    required this.os,
    required this.app,
    required this.deviceId,
  });

  final String device;
  final String os;
  final String app;
  final String deviceId;

  Map<String, Object?> toJson() => {
    'device': device,
    'os': os,
    'app': app,
    'deviceId': deviceId,
  };
}

/// REST flight/session initialization payload. `position` intentionally remains
/// a JSON map because the reference contract does not define its nested schema.
@immutable
class LiveTrackingSessionRequest {
  LiveTrackingSessionRequest({
    required Map<String, Object?> position,
    required this.device,
    required this.glider,
    required this.gliderCat,
    required this.tandem,
    required this.simulation,
    required this.isPublic,
    required this.faiCompliant,
    this.flarmRadioId,
    this.protoVersion = 4,
  }) : position = Map.unmodifiable(position) {
    if (protoVersion < 1) throw ArgumentError.value(protoVersion);
  }

  final Map<String, Object?> position;
  final LiveTrackingDeviceInfo device;
  final String glider;
  final String gliderCat;
  final bool tandem;
  final bool simulation;
  final bool isPublic;
  final bool faiCompliant;
  final String? flarmRadioId;
  final int protoVersion;

  Map<String, Object?> toJson() => {
    'position': position,
    'device': device.toJson(),
    'glider': glider,
    'gliderCat': gliderCat,
    'tandem': tandem,
    'simulation': simulation,
    'public': isPublic,
    'faiCompliant': faiCompliant,
    if (flarmRadioId != null) 'flarmRadioId': flarmRadioId,
    'protoVersion': protoVersion,
  };
}

@immutable
class LiveTrackingSession {
  const LiveTrackingSession({required this.webSocketUri});

  final Uri webSocketUri;
}

/// Six integer values used by the high-precision telemetry wire format:
/// latitude E6, longitude E6, epoch seconds, GPS altitude, baro altitude,
/// terrain elevation.
@immutable
class LiveTrackpoint {
  const LiveTrackpoint({
    required this.latitudeE6,
    required this.longitudeE6,
    required this.timestampSeconds,
    required this.gpsAltitudeM,
    required this.baroAltitudeM,
    required this.elevationM,
  });

  final int latitudeE6;
  final int longitudeE6;
  final int timestampSeconds;
  final int gpsAltitudeM;
  final int baroAltitudeM;
  final int elevationM;

  factory LiveTrackpoint.fromFlightData(FlightData data, {DateTime? at}) {
    if (!data.hasFix || data.isMockLocation) {
      throw const FormatException('A real GPS fix is required.');
    }
    final timestamp = data.gpsTimestamp ?? data.timestamp ?? at;
    if (timestamp == null) throw const FormatException('Missing GPS time.');
    return LiveTrackpoint(
      latitudeE6: _coordinateE6(data.latitude, minimum: -90, maximum: 90),
      longitudeE6: _coordinateE6(data.longitude, minimum: -180, maximum: 180),
      timestampSeconds: timestamp.toUtc().millisecondsSinceEpoch ~/ 1000,
      gpsAltitudeM: _roundedAltitude(data.gpsAltitude),
      baroAltitudeM: _roundedAltitude(data.baroAltitude),
      elevationM: _roundedAltitude(data.terrainElevationM),
    );
  }

  List<int> toVector() => [
    latitudeE6,
    longitudeE6,
    timestampSeconds,
    gpsAltitudeM,
    baroAltitudeM,
    elevationM,
  ];

  Map<String, Object> toJson() => {
    'latE6': latitudeE6,
    'lonE6': longitudeE6,
    'ts': timestampSeconds,
    'gpsAlt': gpsAltitudeM,
    'baroAlt': baroAltitudeM,
    'elevation': elevationM,
  };

  static LiveTrackpoint? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    int? read(String key) => (value[key] as num?)?.toInt();
    final lat = read('latE6');
    final lon = read('lonE6');
    final timestamp = read('ts');
    final gps = read('gpsAlt');
    final baro = read('baroAlt');
    final elevation = read('elevation');
    if (lat == null ||
        lon == null ||
        timestamp == null ||
        gps == null ||
        baro == null ||
        elevation == null ||
        lat.abs() > 90000000 ||
        lon.abs() > 180000000) {
      return null;
    }
    return LiveTrackpoint(
      latitudeE6: lat,
      longitudeE6: lon,
      timestampSeconds: timestamp,
      gpsAltitudeM: gps,
      baroAltitudeM: baro,
      elevationM: elevation,
    );
  }
}

int _coordinateE6(double value, {required int minimum, required int maximum}) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw const FormatException('Invalid GPS coordinate.');
  }
  final absolute = value.abs();
  final degrees = absolute.truncateToDouble();
  final minutesRounded = ((absolute - degrees) * 600000).round() / 600000;
  final quantized = (degrees + minutesRounded) * (value < 0 ? -1 : 1);
  return (quantized * 1000000).round();
}

int _roundedAltitude(double? value) {
  if (value == null || !value.isFinite) return 0;
  return value.round().clamp(-2147483648, 2147483647);
}

/// Custom six-bit delta codec used by the `pointsHP` JSON string.
/// It is not Base64: characters span ASCII `?` through `~`.
abstract final class LiveTrackpointCodec {
  static String encode(List<LiveTrackpoint> points) {
    if (points.isEmpty) return '';
    final scalars = <int>[];
    List<int>? previous;
    for (final point in points) {
      final vector = point.toVector();
      if (point.latitudeE6.abs() > 90000000 ||
          point.longitudeE6.abs() > 180000000 ||
          point.timestampSeconds < 0) {
        throw const FormatException('Invalid high-precision trackpoint.');
      }
      if (previous != null && vector[2] < previous[2]) {
        throw const FormatException('Trackpoints must be time ordered.');
      }
      for (var index = 0; index < vector.length; index++) {
        final delta = previous == null
            ? vector[index]
            : vector[index] - previous[index];
        final zigzag = delta >= 0 ? delta << 1 : ((-delta) << 1) - 1;
        var remaining = zigzag;
        while (remaining >= 32) {
          scalars.add((remaining & 31) | 32);
          remaining >>= 5;
        }
        scalars.add(remaining);
      }
      previous = vector;
    }
    return String.fromCharCodes(scalars.map((value) => value + 63));
  }

  static List<List<int>> decode(String encoded) {
    final values = <int>[];
    var accumulator = 0;
    var shift = 0;
    for (final codeUnit in encoded.codeUnits) {
      if (codeUnit < 63 || codeUnit > 126) {
        throw const FormatException('Invalid compressed trackpoint character.');
      }
      final value = codeUnit - 63;
      accumulator |= (value & 31) << shift;
      if ((value & 32) == 0) {
        final delta = (accumulator & 1) == 0
            ? accumulator >> 1
            : -((accumulator >> 1) + 1);
        values.add(delta);
        accumulator = 0;
        shift = 0;
      } else {
        shift += 5;
        if (shift > 60) {
          throw const FormatException(
            'Compressed trackpoint value is too large.',
          );
        }
      }
    }
    if (shift != 0 || values.length % 6 != 0) {
      throw const FormatException('Incomplete compressed trackpoint sequence.');
    }
    final vectors = <List<int>>[];
    List<int>? previous;
    for (var offset = 0; offset < values.length; offset += 6) {
      final vector = values.sublist(offset, offset + 6);
      if (previous != null) {
        for (var index = 0; index < vector.length; index++) {
          vector[index] += previous[index];
        }
      }
      vectors.add(vector);
      previous = vector;
    }
    return vectors;
  }
}

@immutable
class LiveChunkAdditionalInfo {
  const LiveChunkAdditionalInfo({
    this.windFromMs,
    this.xcActivity,
    this.xcActivityConfidence,
  });

  final List<double>? windFromMs;
  final Object? xcActivity;
  final int? xcActivityConfidence;

  Map<String, Object?> toJson() => {
    if (windFromMs != null) 'windFromMs': windFromMs,
    if (xcActivity != null) 'xcActivity': xcActivity,
    if (xcActivityConfidence != null)
      'xcActivityConfidence': xcActivityConfidence,
  };
}

Map<String, Object?> liveChunkFrame(
  List<LiveTrackpoint> points, {
  LiveChunkAdditionalInfo? additionalInfo,
}) {
  if (points.isEmpty) throw ArgumentError('A chunk must contain points.');
  return {
    'tag': 'xcSendChunkHP',
    'pointsHP': LiveTrackpointCodec.encode(points),
    if (additionalInfo != null && additionalInfo.toJson().isNotEmpty)
      'addInfo': additionalInfo.toJson(),
  };
}

/// Durable bounded store for points not yet acknowledged by the server.
abstract interface class OfflineTrackpointStore {
  Future<List<LiveTrackpoint>> load();

  Future<void> save(List<LiveTrackpoint> points);
}

class SharedPreferencesTrackpointStore implements OfflineTrackpointStore {
  SharedPreferencesTrackpointStore({
    this.storageKey = 'pb.liveTrack.pending.v1',
  });

  final String storageKey;

  @override
  Future<List<LiveTrackpoint>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(LiveTrackpoint.fromJson)
          .whereType<LiveTrackpoint>()
          .toList(growable: true);
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> save(List<LiveTrackpoint> points) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      storageKey,
      jsonEncode(points.map((point) => point.toJson()).toList()),
    );
  }
}

/// Observable connection lifecycle for consumers and UI.
enum LiveTrackingState {
  idle,
  creatingSession,
  connecting,
  online,
  reconnecting,
  stopping,
  failed,
}

/// REST + WebSocket live tracker. It consumes the app's existing GPS/data feed;
/// it does not open another location stream or embed account credentials.
class LiveTrackingService extends ChangeNotifier {
  LiveTrackingService({
    required LiveTrackingConfig config,
    required LiveTrackingAuthProvider authProvider,
    OfflineTrackpointStore? pointStore,
    http.Client? httpClient,
    LiveTrackingSocketConnector? socketConnector,
    LiveChunkAdditionalInfo Function()? additionalInfoBuilder,
  }) : _config = config,
       _authProvider = authProvider,
       _pointStore = pointStore ?? SharedPreferencesTrackpointStore(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _socketConnector =
           socketConnector ?? createDefaultLiveTrackingSocketConnector(),
       _additionalInfoBuilder = additionalInfoBuilder;

  final LiveTrackingConfig _config;
  final LiveTrackingAuthProvider _authProvider;
  final OfflineTrackpointStore _pointStore;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final LiveTrackingSocketConnector _socketConnector;
  final LiveChunkAdditionalInfo Function()? _additionalInfoBuilder;
  final List<LiveTrackpoint> _pendingPoints = [];

  LiveTrackingState _state = LiveTrackingState.idle;
  LiveTrackingState get state => _state;
  int get pendingPointCount => _pendingPoints.length;
  String? _lastErrorCode;
  String? get lastErrorCode => _lastErrorCode;
  int? _serverIntervalSeconds;
  int? get serverIntervalSeconds => _serverIntervalSeconds;

  bool _running = false;
  bool _starting = false;
  bool _storeLoaded = false;
  bool _disposed = false;
  bool _isFlushing = false;
  int? _sentThroughTimestamp;
  int? _lastAcknowledgedTimestamp;
  DateTime? _lastChunkSentAt;
  int _reconnectAttempt = 0;
  Uri? _sessionUri;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Timer? _uploadTimer;
  Timer? _stableConnectionTimer;
  Future<void> _storeWriteTail = Future<void>.value();

  FlightDataView? _boundData;
  FlightState? _boundFlightState;
  Listenable? _eligibilitySource;
  bool Function()? _isEnabled;
  Future<LiveTrackingSessionRequest> Function()? _requestBuilder;
  Future<void> _flightSyncTail = Future<void>.value();

  /// Binds to ParaBeacon's existing transformed feed and flight state. Supply a
  /// request builder that snapshots current GPS/device/aircraft metadata.
  void bind({
    required FlightDataView data,
    required FlightState flightState,
    required Future<LiveTrackingSessionRequest> Function() requestBuilder,
    bool Function()? isEnabled,
    Listenable? eligibilitySource,
  }) {
    unbind();
    _boundData = data;
    _boundFlightState = flightState;
    _requestBuilder = requestBuilder;
    _isEnabled = isEnabled;
    _eligibilitySource = eligibilitySource;
    data.addListener(_onBoundDataChanged);
    flightState.addListener(_queueFlightSync);
    eligibilitySource?.addListener(_queueFlightSync);
    _onBoundDataChanged();
    _queueFlightSync();
  }

  void unbind() {
    _boundData?.removeListener(_onBoundDataChanged);
    _boundFlightState?.removeListener(_queueFlightSync);
    _eligibilitySource?.removeListener(_queueFlightSync);
    _boundData = null;
    _boundFlightState = null;
    _eligibilitySource = null;
    _requestBuilder = null;
    _isEnabled = null;
  }

  void _onBoundDataChanged() {
    if (!_running || _boundData == null) return;
    final data = _boundData!.data;
    if (!data.hasFix || data.isMockLocation) return;
    try {
      final point = LiveTrackpoint.fromFlightData(data);
      unawaited(addTrackpoint(point));
    } on FormatException {
      // Invalid or incomplete GPS snapshots are ignored.
    }
  }

  void _queueFlightSync() {
    if (_disposed || _boundFlightState == null || _requestBuilder == null) {
      return;
    }
    _flightSyncTail = _flightSyncTail
        .then((_) => _syncBoundFlight())
        .catchError((Object error, StackTrace stackTrace) {
          _setState(
            LiveTrackingState.failed,
            errorCode: 'session_start_failed',
          );
        });
  }

  Future<void> _syncBoundFlight() async {
    final flightState = _boundFlightState;
    final requestBuilder = _requestBuilder;
    if (flightState == null || requestBuilder == null) return;
    final shouldTrack = flightState.isFlying && (_isEnabled?.call() ?? true);
    if (shouldTrack && !_running) {
      final request = await requestBuilder();
      if (_boundFlightState?.isFlying == true && (_isEnabled?.call() ?? true)) {
        await start(request);
      }
    } else if (!shouldTrack && _running) {
      await stop();
    }
  }

  Future<void> start(LiveTrackingSessionRequest request) async {
    if (_disposed) throw StateError('LiveTrackingService is disposed.');
    if (_running || _starting) return;
    _starting = true;
    _lastErrorCode = null;
    _setState(LiveTrackingState.creatingSession);
    try {
      await _loadStoreOnce();
      _running = true;
      _onBoundDataChanged();
      final session = await _createSession(request);
      _config.validateWebSocketUri(session.webSocketUri);
      _sessionUri = session.webSocketUri;
      await _connect();
    } on Object catch (error) {
      _running = false;
      _sessionUri = null;
      final errorCode = error is LiveTrackingException
          ? error.code
          : 'session_start_failed';
      _setState(LiveTrackingState.failed, errorCode: errorCode);
      rethrow;
    } finally {
      _starting = false;
    }
  }

  Future<void> _loadStoreOnce() async {
    if (_storeLoaded) return;
    final stored = await _pointStore.load();
    final retained = stored.length <= _config.maximumBufferedPoints
        ? stored
        : stored.sublist(stored.length - _config.maximumBufferedPoints);
    _pendingPoints
      ..clear()
      ..addAll(retained);
    _storeLoaded = true;
    _notify();
  }

  Future<LiveTrackingSession> _createSession(
    LiveTrackingSessionRequest request,
  ) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...await _authProvider.restHeaders(),
    };
    final httpRequest = http.Request('POST', _config.flightUri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..body = jsonEncode(request.toJson());
    final streamedResponse = await _httpClient
        .send(httpRequest)
        .timeout(_config.requestTimeout);
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(_config.requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LiveTrackingException('session_http_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['uri'] is! String) {
      throw const LiveTrackingException('invalid_session_response');
    }
    final uri = Uri.tryParse(decoded['uri'] as String);
    if (uri == null) throw const LiveTrackingException('invalid_session_uri');
    return LiveTrackingSession(webSocketUri: uri);
  }

  Future<void> _connect() async {
    final uri = _sessionUri;
    if (!_running || uri == null) return;
    _setState(
      _reconnectAttempt == 0
          ? LiveTrackingState.connecting
          : LiveTrackingState.reconnecting,
    );
    WebSocketChannel? channel;
    try {
      final headers = await _authProvider.webSocketHeaders(uri);
      channel = _socketConnector.connect(
        uri,
        headers: headers,
        pingInterval: _config.transportPingInterval,
      );
      _channel = channel;
      await channel.ready.timeout(_config.socketReadyTimeout);
      if (!_running || !identical(_channel, channel)) {
        await channel.sink.close();
        return;
      }
      _socketSubscription = channel.stream.listen(
        _onSocketMessage,
        onError: (Object _) => _onSocketEnded(channel!),
        onDone: () => _onSocketEnded(channel!),
        cancelOnError: true,
      );
      _stableConnectionTimer?.cancel();
      _stableConnectionTimer = Timer(const Duration(seconds: 30), () {
        if (_state == LiveTrackingState.online) _reconnectAttempt = 0;
      });
      _setState(LiveTrackingState.online);
      _uploadTimer?.cancel();
      _uploadTimer = Timer.periodic(_config.uploadInterval, (_) {
        unawaited(_flushPending());
      });
      await _flushPending();
    } on Object catch (error) {
      if (channel != null) {
        try {
          await channel.sink.close();
        } on Object {
          // Best-effort close after a failed handshake.
        }
      }
      if (channel != null && identical(_channel, channel)) {
        _channel = null;
      }
      _stableConnectionTimer?.cancel();
      _uploadTimer?.cancel();
      if (error is UnsupportedError) {
        _running = false;
        _sessionUri = null;
        _setState(
          LiveTrackingState.failed,
          errorCode: 'websocket_transport_unsupported',
        );
      } else if (_running) {
        _scheduleReconnect();
      }
    }
  }

  void _onSocketMessage(dynamic message) {
    if (message is! String) return;
    Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    switch (decoded['tag']) {
      case 'ackChunk':
        final acknowledged = parseFlightTimestamp(decoded['lastTstamp']);
        if (acknowledged != null) {
          final timestamp = acknowledged.millisecondsSinceEpoch ~/ 1000;
          if (_lastAcknowledgedTimestamp == null ||
              timestamp > _lastAcknowledgedTimestamp!) {
            _lastAcknowledgedTimestamp = timestamp;
          }
          _lastChunkSentAt = DateTime.now();
          _acknowledgeThrough(timestamp);
        }
        break;
      case 'serverInfo':
        final interval = (decoded['interval'] as num?)?.toInt();
        if (interval != null && interval >= 1 && interval < 120) {
          _serverIntervalSeconds = interval;
          _notify();
        }
        break;
      case 'error':
        _lastErrorCode = 'server_error';
        _notify();
        break;
    }
  }

  Future<void> addTrackpoint(LiveTrackpoint point) async {
    if (_disposed || !_running) return;
    if ((_pendingPoints.isNotEmpty &&
            point.timestampSeconds <= _pendingPoints.last.timestampSeconds) ||
        (_lastAcknowledgedTimestamp != null &&
            point.timestampSeconds <= _lastAcknowledgedTimestamp!)) {
      return;
    }
    _pendingPoints.add(point);
    if (_pendingPoints.length > _config.maximumBufferedPoints) {
      _pendingPoints.removeRange(
        0,
        _pendingPoints.length - _config.maximumBufferedPoints,
      );
      _lastErrorCode = 'offline_queue_limit_reached';
    }
    _notify();
    await _persistPoints();
    if (_state == LiveTrackingState.online) unawaited(_flushPending());
  }

  void _acknowledgeThrough(int timestampSeconds) {
    final before = _pendingPoints.length;
    _pendingPoints.removeWhere(
      (point) => point.timestampSeconds <= timestampSeconds,
    );
    if (_pendingPoints.length == before) return;
    _notify();
    unawaited(_persistPoints());
  }

  Future<void> _persistPoints() {
    final snapshot = List<LiveTrackpoint>.unmodifiable(_pendingPoints);
    _storeWriteTail = _storeWriteTail
        .catchError((Object _) {})
        .then((_) => _pointStore.save(snapshot))
        .catchError((Object _) {
          _lastErrorCode = 'offline_store_write_failed';
          _notify();
        });
    return _storeWriteTail;
  }

  Future<void> _flushPending() async {
    final channel = _channel;
    if (!_running ||
        channel == null ||
        _state != LiveTrackingState.online ||
        _isFlushing) {
      return;
    }
    _isFlushing = true;
    try {
      final lastChunkSentAt = _lastChunkSentAt;
      if (lastChunkSentAt != null &&
          DateTime.now().difference(lastChunkSentAt) >=
              _config.acknowledgementTimeout) {
        _sentThroughTimestamp = _lastAcknowledgedTimestamp;
        _lastChunkSentAt = null;
      }
      final unsent = _pendingPoints
          .where(
            (point) =>
                _sentThroughTimestamp == null ||
                point.timestampSeconds > _sentThroughTimestamp!,
          )
          .toList(growable: false);
      for (
        var offset = 0;
        offset < unsent.length;
        offset += _config.maximumChunkPoints
      ) {
        if (!identical(_channel, channel) || !_running) return;
        final end = (offset + _config.maximumChunkPoints).clamp(
          0,
          unsent.length,
        );
        final chunk = unsent.sublist(offset, end);
        channel.sink.add(
          jsonEncode(
            liveChunkFrame(
              chunk,
              additionalInfo: _additionalInfoBuilder?.call(),
            ),
          ),
        );
        _sentThroughTimestamp = chunk.last.timestampSeconds;
        _lastChunkSentAt = DateTime.now();
      }
    } on Object {
      _onSocketEnded(channel);
    } finally {
      _isFlushing = false;
    }
  }

  void _onSocketEnded(WebSocketChannel channel) {
    if (!identical(_channel, channel)) return;
    _channel = null;
    _sentThroughTimestamp = null;
    _lastChunkSentAt = null;
    _stableConnectionTimer?.cancel();
    _uploadTimer?.cancel();
    _uploadTimer = null;
    final subscription = _socketSubscription;
    _socketSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    if (_running) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_running || _reconnectTimer != null) return;
    _setState(LiveTrackingState.reconnecting);
    final exponent = _reconnectAttempt.clamp(0, 20);
    final multiplier = 1 << exponent;
    final proposed = _config.initialReconnectDelay * multiplier;
    final delay = proposed > _config.maximumReconnectDelay
        ? _config.maximumReconnectDelay
        : proposed;
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  Future<void> stop() async {
    if (!_running && _channel == null) return;
    _setState(LiveTrackingState.stopping);
    _running = false;
    _sessionUri = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _stableConnectionTimer?.cancel();
    _stableConnectionTimer = null;
    final subscription = _socketSubscription;
    _socketSubscription = null;
    if (subscription != null) await subscription.cancel();
    final channel = _channel;
    _channel = null;
    _sentThroughTimestamp = null;
    _lastChunkSentAt = null;
    if (channel != null) {
      try {
        await channel.sink.close(1000, 'tracking stopped');
      } on Object {
        // Best-effort close; pending points remain durable for the next session.
      }
    }
    _setState(LiveTrackingState.idle);
  }

  Future<void> shutdown() async {
    unbind();
    await stop();
    await _storeWriteTail.catchError((Object _) {});
    if (_ownsHttpClient) _httpClient.close();
    _disposed = true;
    dispose();
  }

  void _setState(LiveTrackingState value, {String? errorCode}) {
    if (_state == value && _lastErrorCode == errorCode) return;
    _state = value;
    _lastErrorCode = errorCode;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (!_disposed) {
      unbind();
      _disposed = true;
      _reconnectTimer?.cancel();
      _uploadTimer?.cancel();
      _stableConnectionTimer?.cancel();
      final subscription = _socketSubscription;
      _socketSubscription = null;
      if (subscription != null) unawaited(subscription.cancel());
      final channel = _channel;
      _channel = null;
      if (channel != null) unawaited(channel.sink.close());
      if (_ownsHttpClient) _httpClient.close();
    }
    super.dispose();
  }
}

class LiveTrackingException implements Exception {
  const LiveTrackingException(this.code);

  final String code;

  @override
  String toString() => 'LiveTrackingException($code)';
}
