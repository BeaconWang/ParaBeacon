import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/live_tracking_proxy_auth_service.dart';
import '../data/live_tracking_service.dart';
import 'ws_connect.dart';

enum RoomSocketState { disconnected, connecting, active, reconnecting }

@immutable
class LivePeerPosition {
  const LivePeerPosition({
    required this.participantId,
    required this.pilotName,
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.speedMetersPerSecond,
    required this.timestamp,
    this.headingDegrees,
  });

  final String participantId;
  final String pilotName;
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double speedMetersPerSecond;
  final DateTime timestamp;
  final double? headingDegrees;

  static LivePeerPosition? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final participantId = value['participant_id'];
    final pilotName = value['pilot_name'];
    final latitude = value['lat'];
    final longitude = value['lon'];
    final altitude = value['altitude'];
    final speed = value['speed'];
    final timestampValue = value['timestamp'];
    final heading = value['heading'];
    if (participantId is! String ||
        pilotName is! String ||
        latitude is! num ||
        longitude is! num ||
        altitude is! num ||
        speed is! num ||
        timestampValue is! String ||
        (heading != null && heading is! num)) {
      return null;
    }
    final lat = latitude.toDouble();
    final lon = longitude.toDouble();
    final alt = altitude.toDouble();
    final speedMps = speed.toDouble();
    final observedAt = DateTime.tryParse(timestampValue);
    final bearing = (heading as num?)?.toDouble();
    if (participantId.isEmpty ||
        pilotName.trim().isEmpty ||
        !lat.isFinite ||
        !lon.isFinite ||
        !alt.isFinite ||
        !speedMps.isFinite ||
        observedAt == null ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180 ||
        speedMps < 0 ||
        speedMps > 200 ||
        (bearing != null &&
            (!bearing.isFinite || bearing < 0 || bearing >= 360))) {
      return null;
    }
    return LivePeerPosition(
      participantId: participantId,
      pilotName: pilotName.trim(),
      latitude: lat,
      longitude: lon,
      altitudeMeters: alt,
      speedMetersPerSecond: speedMps,
      timestamp: observedAt.toUtc(),
      headingDegrees: bearing,
    );
  }
}

class RoomTrackingWebSocketClient extends ChangeNotifier {
  RoomTrackingWebSocketClient({required this.authProvider});

  final LiveTrackingProxyAuthProvider authProvider;
  final StreamController<List<LivePeerPosition>> _snapshots =
      StreamController<List<LivePeerPosition>>.broadcast();

  Stream<List<LivePeerPosition>> get snapshots => _snapshots.stream;
  RoomSocketState _state = RoomSocketState.disconnected;
  RoomSocketState get state => _state;
  String? _lastError;
  String? get lastError => _lastError;

  Uri? _endpoint;
  String? _roomId;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _stableTimer;
  int _attempt = 0;
  int _connectionEpoch = 0;
  bool _connecting = false;
  bool _desiredConnection = false;
  bool _closed = false;

  Future<void> joinRoom({required Uri endpoint, required String roomId}) async {
    if (_closed) throw StateError('Room WebSocket client is closed.');
    if (kIsWeb) {
      throw UnsupportedError(
        'Authenticated room WebSockets require a native client; browser WebSocket APIs cannot set Bearer headers.',
      );
    }
    final normalizedRoomId = roomId.trim();
    if (!_isUuid(normalizedRoomId) ||
        (endpoint.scheme != 'ws' && endpoint.scheme != 'wss') ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      throw ArgumentError('Invalid room WebSocket endpoint or room id.');
    }
    await leaveRoom();
    _endpoint = endpoint;
    _roomId = normalizedRoomId;
    _desiredConnection = true;
    await _connect();
  }

  bool sendLocation(LiveTrackpoint point) {
    final channel = _channel;
    if (!_desiredConnection ||
        channel == null ||
        _state != RoomSocketState.active) {
      return false;
    }
    try {
      channel.sink.add(
        jsonEncode({
          'type': 'location',
          'location': {
            'lat': point.latitude,
            'lon': point.longitude,
            'altitude': point.altitudeMeters,
            'speed': point.groundSpeedMetersPerSecond,
            'timestamp': point.timestamp.toUtc().toIso8601String(),
            if (point.headingDegrees != null) 'heading': point.headingDegrees,
            if (point.gpsAltitudeMeters != null)
              'gps_altitude': point.gpsAltitudeMeters,
            if (point.barometricAltitudeMeters != null)
              'pressure_altitude': point.barometricAltitudeMeters,
          },
        }),
      );
      return true;
    } on Object catch (error) {
      _lastError = error.runtimeType.toString();
      _scheduleReconnect();
      return false;
    }
  }

  Future<void> _connect() async {
    if (_connecting || !_desiredConnection || _closed) return;
    final endpoint = _endpoint;
    final roomId = _roomId;
    final connectionEpoch = _connectionEpoch;
    if (endpoint == null || roomId == null) return;
    _connecting = true;
    _setState(
      _attempt == 0 ? RoomSocketState.connecting : RoomSocketState.reconnecting,
    );
    WebSocketChannel? channel;
    try {
      final headers = await authProvider.authorizationHeaders();
      if (connectionEpoch != _connectionEpoch ||
          !_desiredConnection ||
          _closed) {
        return;
      }
      final uri = endpoint.replace(queryParameters: {'room_id': roomId});
      channel = connectWebSocket(
        uri,
        headers: headers,
        pingInterval: const Duration(seconds: 10),
      );
      await channel.ready.timeout(const Duration(seconds: 12));
      if (connectionEpoch != _connectionEpoch ||
          !_desiredConnection ||
          _closed) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _lastError = null;
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (Object error) => _onDisconnected(error),
        onDone: () => _onDisconnected(null),
        cancelOnError: false,
      );
      channel.sink.add(
        jsonEncode({
          'type': 'flight_reset',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      _setState(RoomSocketState.active);
      _stableTimer?.cancel();
      _stableTimer = Timer(const Duration(seconds: 30), () => _attempt = 0);
    } on Object catch (error) {
      if (connectionEpoch == _connectionEpoch) {
        _lastError = error.runtimeType.toString();
        if (channel != null) await channel.sink.close();
        _scheduleReconnect();
      }
    } finally {
      _connecting = false;
      if (connectionEpoch != _connectionEpoch &&
          _desiredConnection &&
          !_closed) {
        unawaited(_connect());
      }
    }
  }

  void _onMessage(dynamic message) {
    try {
      final text = message is String
          ? message
          : message is List<int>
          ? utf8.decode(message)
          : null;
      if (text == null) return;
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic> || decoded['type'] != 'snapshot') {
        return;
      }
      final rawUsers = decoded['users'];
      if (rawUsers is! List) return;
      final peers = rawUsers
          .map(LivePeerPosition.fromJson)
          .whereType<LivePeerPosition>()
          .toList(growable: false);
      _snapshots.add(List.unmodifiable(peers));
    } on Object catch (error) {
      _lastError = error.runtimeType.toString();
      notifyListeners();
    }
  }

  void _onDisconnected(Object? error) {
    _channel = null;
    _stableTimer?.cancel();
    _stableTimer = null;
    if (error != null) _lastError = error.runtimeType.toString();
    if (_desiredConnection) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_desiredConnection || _closed || _reconnectTimer != null) return;
    _stableTimer?.cancel();
    _stableTimer = null;
    _subscription?.cancel();
    _subscription = null;
    final oldChannel = _channel;
    _channel = null;
    if (oldChannel != null) unawaited(oldChannel.sink.close());
    final delaySeconds = (1 << _attempt.clamp(0, 6)).clamp(1, 60);
    _attempt++;
    _setState(RoomSocketState.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  Future<void> leaveRoom() async {
    _connectionEpoch++;
    _desiredConnection = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stableTimer?.cancel();
    _stableTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
    _attempt = 0;
    _setState(RoomSocketState.disconnected);
  }

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  void _setState(RoomSocketState value) {
    if (_state == value) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _desiredConnection = false;
    _reconnectTimer?.cancel();
    _stableTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    unawaited(_snapshots.close());
    super.dispose();
  }
}
