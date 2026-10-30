import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../live/config.dart';
import '../live/live_client.dart';
import '../live/live_manager.dart';
import '../live/system_info.dart';
import '../live/trackpoint.dart';
import '../live/web_socket_wire.dart';
import '../live/sha256.dart';
import 'aircraft_settings.dart';
import 'flight_data.dart';
import 'flight_state.dart';
import 'live_tracking_settings.dart';
import 'user_agent_settings.dart';
import 'xcontest_auth_service.dart';

/// Connection states exposed by the Live tracking settings UI.
enum LiveTrackingConnectionState {
  idle,
  connecting,
  active,
  reconnecting,
  disconnected,
}

/// Bridges ParaBeacon's flight-data stream to XCTrack's native livetrack
/// protocol (the `lib/live` port of the `xcshare` reference).
///
/// Lifecycle, mirroring the reference (`live/r0` + `live/c1`):
///   * flying + enabled   -> POST /api/flight, open WS, `c1.b()` handshake,
///                           `r0.g()` start the flush timer.
///   * every GPS fix      -> `c1.h(loc)` queue the point.
///   * flush timer        -> `j8/n` batch -> `xcSendChunkHP`; purge on ackChunk.
///   * not flying/disabled -> `c1.q()` land: drain the buffer, send `xcLanding`,
///                            wait for `landingAck`, then close the socket.
///
/// This class only adapts ParaBeacon lifecycle, settings, authentication and
/// sensor data to that protocol; the protocol objects under `lib/live` are the
/// unchanged reference implementation.
class XContestLiveTrackingService extends ChangeNotifier {
  XContestLiveTrackingService._();

  static final XContestLiveTrackingService instance =
      XContestLiveTrackingService._();

  /// Upper bound on how long a landing may take to finalise before the socket
  /// is torn down regardless of a missing `landingAck` (safety net only - the
  /// normal path finishes as soon as the ack or the drain completes).
  static const Duration _landingTimeout = Duration(seconds: 60);

  /// Most recent debug log lines, newest last. Only populated in debug builds
  /// (see [_log]); rendered at the bottom of the Live tracking settings sheet.
  static const int _maxLogLines = 200;
  final List<String> _debugLog = <String>[];

  /// Immutable snapshot of the debug log, oldest first.
  List<String> get debugLog => List<String>.unmodifiable(_debugLog);

  /// Appends a timestamped line to [debugLog]. No-op in release builds so the
  /// buffer never grows in production.
  void _log(String message) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${now.millisecond.toString().padLeft(3, '0')}';
    _debugLog.add('$stamp  $message');
    if (_debugLog.length > _maxLogLines) {
      _debugLog.removeRange(0, _debugLog.length - _maxLogLines);
    }
    _notify();
  }

  bool _configured = false;
  bool _disposed = false;
  LiveTrackingConnectionState _state =
      LiveTrackingConnectionState.disconnected;
  String? _lastErrorCode;
  String? _sessionId;

  FlightDataView? _data;
  FlightState? _flightState;
  Listenable? _eligibilitySource;
  bool Function()? _isEnabled;
  String? Function()? _pilotId;

  LiveClient? _client;
  WebSocketWire? _wire;
  Timer? _tickTimer;
  Timer? _reconnectTimer;
  Timer? _landingTimer;
  Future<void>? _lifecycleFuture;
  bool _starting = false;
  bool _ending = false;
  int _retryAttempt = 0;
  int _bindingEpoch = 0;
  Uri? _socketUri;
  http.Client? _httpClient;

  LiveTrackingConnectionState get state => _state;
  String? get lastErrorCode => _lastErrorCode;
  String? get sessionId => _sessionId;
  bool get isConfigured => _configured;
  int get pendingPointCount =>
      (_client?.queue.length ?? 0) + (_client?.inflight.length ?? 0);

  void configure() {
    if (_client != null || _starting) {
      throw StateError(
        'Cannot replace live-tracking configuration while a session runs.',
      );
    }
    _configured = true;
    _lastErrorCode = null;
    _setState(LiveTrackingConnectionState.idle);
  }

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
    _queueLifecycleSync();
  }

  void unbind() {
    _bindingEpoch++;
    _data?.removeListener(_onDataChanged);
    _flightState?.removeListener(_queueLifecycleSync);
    _eligibilitySource?.removeListener(_queueLifecycleSync);
    _data = null;
    _flightState = null;
    _eligibilitySource = null;
    _isEnabled = null;
    _pilotId = null;
    _queueStop();
    if (!_disposed) _setState(LiveTrackingConnectionState.idle);
  }

  bool get _shouldTrack =>
      _configured &&
      _flightState?.isFlying == true &&
      (_isEnabled?.call() ?? false);

  // =======================================================================
  // lifecycle serialisation
  // =======================================================================
  void _queueLifecycleSync() {
    if (_disposed) return;
    _lifecycleFuture = (_lifecycleFuture ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => _syncLifecycle())
        .catchError((Object error) {
          _lastErrorCode = _errorCode(error);
          _setState(LiveTrackingConnectionState.reconnecting);
          _scheduleReconnect();
        });
  }

  Future<void> _syncLifecycle() async {
    if (!_configured) return;
    if (_shouldTrack) {
      // A new flight must not resurrect a session that is still landing.
      if (_client == null && !_starting && !_ending) await _startFlight();
      return;
    }
    if ((_client != null || _starting) && !_ending) {
      await _stopFlight();
    }
  }

  // =======================================================================
  // start
  // =======================================================================
  Future<void> _startFlight() async {
    final data = _data?.data;
    final fix = data == null ? null : _toFix(data);
    final token = XContestAuthService.instance.accessToken;
    final pilotId = _pilotId?.call()?.trim();
    if (fix == null) {
      _lastErrorCode = 'gps_unavailable';
      _setState(LiveTrackingConnectionState.reconnecting);
      _scheduleReconnect();
      return;
    }
    if (token == null || token.isEmpty || pilotId == null || pilotId.isEmpty) {
      throw const FormatException('xcontest_auth_missing');
    }

    _starting = true;
    final bindingEpoch = _bindingEpoch;
    _log('start: declaring flight (pilot $pilotId)');
    _setState(LiveTrackingConnectionState.connecting);
    try {
      final settings = LiveTrackingSettings.instance;
      final aircraft = AircraftSettings.instance;
      final client = LiveClient(
        LiveManager(),
        shareWhenNotFlying: false,
        claimContest: settings.claimContest,
        flightPublic: settings.flightPublic,
        token: token,
        epoch0Ms: DateTime.now().millisecondsSinceEpoch,
      );
      final options = client.buildFlightOptions(
        fix,
        device: const IgcSystemInfo(),
        glider: aircraft.name.isNotEmpty ? aircraft.name : aircraft.displayName,
        gliderCat: _gliderCategory(aircraft),
        tandem: aircraft.tandem,
        faiCompliant: true,
      );
      final declaration = await _declareFlight(options, token);
      final uri = Uri.tryParse(declaration.uri);
      if (uri == null ||
          uri.scheme != 'wss' ||
          uri.userInfo.isNotEmpty ||
          !_isXContestHost(uri.host)) {
        throw const FormatException('invalid_xcontest_socket');
      }
      if (bindingEpoch != _bindingEpoch || !_shouldTrack) return;

      final wire = WebSocketWire(client, onClosed: _onSocketClosed);
      await wire.connect(uri, headers: {'Authorization': 'Bearer $token'});
      if (bindingEpoch != _bindingEpoch || !_shouldTrack) {
        await wire.close();
        client.stop();
        if (!_disposed) _setState(LiveTrackingConnectionState.disconnected);
        return;
      }

      _client = client;
      _wire = wire;
      _socketUri = uri;
      _sessionId =
          declaration.flightId.isEmpty ? uri.toString() : declaration.flightId;

      _log('socket open: ${uri.host}');
      final now = DateTime.now().millisecondsSinceEpoch;
      client.connect(now); // c1.b(): handshake, resend options/follows
      client.onTakeoff('', now); // r0.j()+r0.g(): flying, start flushing
      _retryAttempt = 0;
      _lastErrorCode = null;
      _startTicker();
      _setState(LiveTrackingConnectionState.active);
      _onDataChanged(); // queue the fix that triggered the start
    } finally {
      _starting = false;
    }
  }

  Future<FlightDeclared> _declareFlight(
    FlightOptions options,
    String token,
  ) async {
    final body = jsonEncode(options.toJson());
    final signature = hex(
      hmacSha256(utf8.encode(kClientHmacKey), utf8.encode(body)),
    );
    final request = http.Request('POST', Uri.parse('${kBaseUrl}flight'))
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'client-id': kClientId,
        'client-hmac': signature,
      })
      ..body = body;
    final client = _httpClient ??= UserAgentHttpClient();
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final result = await http.Response.fromStream(response);
    if (result.statusCode == 401 || result.statusCode == 403) {
      await XContestAuthService.instance.logout();
      throw const FormatException('xcontest_auth_expired');
    }
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw FormatException('xcontest_flight_http_${result.statusCode}');
    }
    final decoded = jsonDecode(result.body);
    if (decoded is! Map<String, dynamic> || decoded['uri'] is! String) {
      throw const FormatException('invalid_xcontest_flight_response');
    }
    return FlightDeclared(uri: (decoded['uri'] as String).trim(), flightId: '');
  }

  // =======================================================================
  // uplink feed
  // =======================================================================
  void _onDataChanged() {
    final client = _client;
    if (client == null) {
      if (_shouldTrack && !_starting && !_ending) _queueLifecycleSync();
      return;
    }
    // Once a landing is in progress we stop feeding new fixes so the buffer
    // can drain and the terminating `xcLanding` is reached.
    if (_ending || !_shouldTrack) return;
    final fix = _toFix(_data?.data);
    if (fix == null) return;
    if (client.onLocation(fix, DateTime.now().millisecondsSinceEpoch)) {
      _notify();
    }
  }

  Fix? _toFix(FlightData? data) {
    if (data == null || !data.hasFix || data.isMockLocation) return null;
    final time = data.gpsTimestamp ?? data.timestamp;
    if (time == null ||
        !data.latitude.isFinite ||
        !data.longitude.isFinite ||
        data.latitude < -90 ||
        data.latitude > 90 ||
        data.longitude < -180 ||
        data.longitude > 180) {
      return null;
    }
    final gpsAlt = data.gpsAltitude ?? data.altitude;
    if (!gpsAlt.isFinite || !data.groundSpeed.isFinite) return null;
    final baro = data.baroAltitude;
    final validBaro = baro != null && baro.isFinite && baro.abs() <= 10000;
    final elevation = data.terrainElevationM;
    return Fix(
      lat: data.latitude,
      lon: data.longitude,
      time: time.toUtc(),
      gpsAlt: gpsAlt,
      baroAlt: validBaro ? baro.round() : 0,
      baroValid: validBaro,
      elevation: elevation != null && elevation.isFinite ? elevation : 0,
      timeValid: true,
      speed: (data.groundSpeed / 3.6).clamp(0, 200).toDouble(),
      vspeed: data.verticalSpeed,
    );
  }

  String _gliderCategory(AircraftSettings aircraft) {
    const rigid = <String, String>{
      '11': 'RPF',
      '12': 'RPL',
      '13': 'RAL',
      '14': 'RWL',
      '15': 'RWF',
      '16': 'RGL',
    };
    final category = rigid[aircraft.faiClass] ?? 'FAI-${aircraft.faiClass}';
    final code = int.tryParse(aircraft.faiClass) ?? 3;
    if (code < 11) return category;
    return '$category${aircraft.tandem ? '2' : '1'}${aircraft.engineType}';
  }

  // =======================================================================
  // periodic tick
  // =======================================================================
  void _startTicker() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final client = _client;
      if (client == null) return;
      final events = client.tick(DateTime.now().millisecondsSinceEpoch);
      for (final event in events) {
        _log(event);
      }
      // The landing is complete once the server acknowledges it, or once the
      // whole buffer has drained after the `xcLanding` went out.
      if (_ending &&
          (client.status == LiveStatus.liveLandingAcknowledged ||
              (client.landed && client.isDrained && client.landingAck != null))) {
        unawaited(_finishFlight());
      }
      _notify();
    });
  }

  // =======================================================================
  // stop / land
  // =======================================================================
  Future<void> _stopFlight() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final client = _client;
    if (client == null) {
      _starting = false;
      if (!_disposed) _setState(LiveTrackingConnectionState.disconnected);
      return;
    }
    if (_ending) return;
    _ending = true;
    _log('landing: draining ${client.queue.length + client.inflight.length} '
        'point(s) then sending xcLanding');
    // c1.q(): the next drained flush emits `xcLanding` instead of a chunk.
    client.setLanded();
    _startTicker(); // keep draining even if the flush timer was idle
    client.flush(DateTime.now().millisecondsSinceEpoch);
    _landingTimer?.cancel();
    _landingTimer = Timer(_landingTimeout, () {
      unawaited(_finishFlight());
    });
  }

  Future<void> _finishFlight() async {
    if (!_ending && _client == null) return;
    _landingTimer?.cancel();
    _landingTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final ack = _client?.landingAck;
    _log(ack != null
        ? 'landed: ack xcFlightId=${ack.xcFlightId}'
        : 'flight finished (socket closed)');
    final wire = _wire;
    _wire = null;
    await wire?.close();
    _client?.stop();
    _client = null;
    _socketUri = null;
    _sessionId = null;
    _ending = false;
    if (!_disposed) _setState(LiveTrackingConnectionState.disconnected);
    // A new flight may have become eligible while we were landing.
    _queueLifecycleSync();
  }

  // =======================================================================
  // reconnect (socket dropped mid-flight)
  // =======================================================================
  void _onSocketClosed(Object? error) {
    if (_disposed || _ending || _client == null || !_shouldTrack) return;
    _lastErrorCode = 'xcontest_socket_closed';
    _log('socket closed${error != null ? ': $error' : ''}');
    _client!.onDisconnected(DateTime.now().millisecondsSinceEpoch);
    _setState(LiveTrackingConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null || _ending) return;
    final exponent = _retryAttempt.clamp(0, 5).toInt();
    final delay = Duration(seconds: (2 * (1 << exponent)).clamp(2, 60));
    _retryAttempt++;
    _log('reconnect in ${delay.inSeconds}s (attempt $_retryAttempt)');
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_client == null) {
        _queueLifecycleSync();
      } else {
        unawaited(_reconnectSocket());
      }
    });
  }

  Future<void> _reconnectSocket() async {
    final client = _client;
    final uri = _socketUri;
    final token = XContestAuthService.instance.accessToken;
    if (client == null ||
        uri == null ||
        _ending ||
        !_shouldTrack ||
        token == null ||
        token.isEmpty) {
      return;
    }
    try {
      final previous = _wire;
      final wire = WebSocketWire(client, onClosed: _onSocketClosed);
      await wire.connect(uri, headers: {'Authorization': 'Bearer $token'});
      await previous?.close();
      _wire = wire;
      final now = DateTime.now().millisecondsSinceEpoch;
      client.connect(now); // resends options/follows (c1.b)
      // Re-send any points that were in flight when the socket dropped; they
      // are still held in `inflight` until an `ackChunk` purges them.
      client.flush(now);
      _retryAttempt = 0;
      _lastErrorCode = null;
      _setState(LiveTrackingConnectionState.active);
    } on Object catch (_) {
      _lastErrorCode = 'xcontest_socket_connect_failed';
      _setState(LiveTrackingConnectionState.reconnecting);
      _scheduleReconnect();
    }
  }

  bool _isXContestHost(String host) =>
      host.toLowerCase() == 'live2.xcontest.org' ||
      host.toLowerCase().endsWith('.xcontest.org');

  String _errorCode(Object error) => error is FormatException
      ? error.message.toString()
      : 'xcontest_network_error';

  void _setState(LiveTrackingConnectionState next) {
    if (_state == next) return;
    _state = next;
    _log('state -> ${next.name}'
        '${_lastErrorCode != null ? ' ($_lastErrorCode)' : ''}');
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _queueStop() {
    if ((_client != null || _starting) && !_ending) unawaited(_stopFlight());
  }

  Future<void> shutdown() async {
    _disposed = true;
    _data?.removeListener(_onDataChanged);
    _flightState?.removeListener(_queueLifecycleSync);
    _eligibilitySource?.removeListener(_queueLifecycleSync);
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _landingTimer?.cancel();
    _landingTimer = null;
    _ending = false; // force an immediate teardown, no landing wait
    await _finishFlight();
    _httpClient?.close();
    super.dispose();
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _data?.removeListener(_onDataChanged);
      _flightState?.removeListener(_queueLifecycleSync);
      _eligibilitySource?.removeListener(_queueLifecycleSync);
      _tickTimer?.cancel();
      _reconnectTimer?.cancel();
      _landingTimer?.cancel();
      _wire?.close();
      _httpClient?.close();
    }
    super.dispose();
  }
}
