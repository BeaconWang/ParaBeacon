import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../live/config.dart';
import '../live/live_client.dart';
import '../live/live_manager.dart';
import '../live/proto.dart';
import '../live/system_info.dart';
import '../live/trackpoint.dart';
import '../live/web_socket_wire.dart';
import '../live/sha256.dart';
import 'aircraft_settings.dart';
import 'debug_settings.dart';
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

/// One other public/followed pilot currently known to the live session,
/// flattened from [LiveManager]'s `positions` + `infos` for rendering on the
/// map. Only populated while "Show public tracking" is on (the server streams
/// these via `flightPositions`/`flightInfos` in response to
/// `receiveAllPositions`).
class LiveOtherPilot {
  final String flightId;
  final double lat;
  final double lon;
  final String name;
  final String glider;
  final int altitude;
  final bool landed;

  /// Stable per-flight marker colour (ARGB) assigned by [LiveManager.colour].
  final int colorArgb;
  final DateTime? time;

  const LiveOtherPilot({
    required this.flightId,
    required this.lat,
    required this.lon,
    required this.name,
    required this.glider,
    required this.altitude,
    required this.landed,
    required this.colorArgb,
    this.time,
  });
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
  LiveManager? _mgr;
  WebSocketWire? _wire;

  List<LiveOtherPilot> _otherPilots = const <LiveOtherPilot>[];

  /// Other public pilots currently known (empty unless "Show public tracking"
  /// is on and the server is streaming positions). Rebuilt whenever the live
  /// manager receives `flightPositions`/`flightInfos`; listeners (the map) are
  /// notified via [notifyListeners].
  List<LiveOtherPilot> get otherPilots => _otherPilots;
  Timer? _tickTimer;
  Timer? _reconnectTimer;
  Timer? _landingTimer;
  Timer? _gpsWaitTimer;

  /// How often to re-check for a usable GPS fix before a flight can start. A
  /// fresh valid fix triggers [_onDataChanged] immediately; this timer is only
  /// a fallback for when the data stream goes quiet.
  static const Duration _gpsWaitInterval = Duration(seconds: 3);
  Future<void>? _lifecycleFuture;
  bool _starting = false;
  bool _ending = false;

  /// After the server ends a flight (close reason `terminated`, a
  /// `flightTerminated` frame, or a 404/401/403 on the flight socket) we wait
  /// this long before declaring a fresh flight, so a persistent rejection
  /// cannot spam `POST /flight`. XCTrack force-lands and starts a new flight on
  /// termination; this is the same intent with a rate limit. Cleared the moment
  /// sharing is disabled or the pilot lands (so a deliberate re-arm is instant).
  static const Duration _terminatedCooldown = Duration(seconds: 60);
  int _terminatedCooldownUntilMs = 0;
  Timer? _terminatedRetryTimer;
  int _retryAttempt = 0;
  int _bindingEpoch = 0;
  Uri? _socketUri;
  http.Client? _httpClient;

  LiveTrackingConnectionState get state => _state;
  String? get lastErrorCode => _lastErrorCode;
  String? get sessionId => _sessionId;
  bool get isConfigured => _configured;
  // `inflight` is a view into the front of `queue` (points stay queued until
  // acked), so the queue length alone is the true pending count.
  int get pendingPointCount => _client?.queue.length ?? 0;

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
    // Hot-apply "Show public tracking" to a running session without
    // reconnecting (resends xcSetOptions).
    _client?.setReceiveAllPositions(
      DateTime.now().millisecondsSinceEpoch,
      LiveTrackingSettings.instance.showPublic,
    );
    if (_shouldTrack) {
      if (_client != null || _starting || _ending) return;
      // After a server termination, hold off re-declaring until the cooldown
      // elapses (then auto-recover), instead of blocking forever.
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < _terminatedCooldownUntilMs) {
        _armTerminatedRetry(_terminatedCooldownUntilMs - now);
        return;
      }
      await _startFlight();
      return;
    }
    // No longer tracking (landed or sharing disabled): clear the cooldown so
    // the next genuine flight - or a deliberate re-enable - starts at once.
    _terminatedCooldownUntilMs = 0;
    _terminatedRetryTimer?.cancel();
    _terminatedRetryTimer = null;
    if ((_client != null || _starting) && !_ending) {
      await _stopFlight();
    }
  }

  /// Re-run the lifecycle once the termination cooldown expires so a flight
  /// auto-restarts without needing a new GPS fix or a settings toggle.
  void _armTerminatedRetry(int delayMs) {
    _terminatedRetryTimer?.cancel();
    _terminatedRetryTimer = Timer(
      Duration(milliseconds: delayMs.clamp(0, 60000)),
      () {
        _terminatedRetryTimer = null;
        if (_shouldTrack && _client == null && !_starting && !_ending) {
          _queueLifecycleSync();
        }
      },
    );
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
      _waitForGps();
      return;
    }
    if (token == null || token.isEmpty || pilotId == null || pilotId.isEmpty) {
      throw const FormatException('xcontest_auth_missing');
    }

    // A mock feed is normally declared as a simulation; the debug-only
    // "report simulated as real" toggle suppresses that flag.
    final isMock = data!.isMockLocation;
    final simulated =
        isMock && !LiveTrackingSettings.instance.reportSimulatedAsReal;
    _gpsWaitTimer?.cancel();
    _gpsWaitTimer = null;
    _terminatedRetryTimer?.cancel();
    _terminatedRetryTimer = null;
    _starting = true;
    final bindingEpoch = _bindingEpoch;
    _log('start: declaring flight (pilot $pilotId'
        '${isMock ? (simulated ? ', simulated' : ', mock-as-real') : ''})');
    _setState(LiveTrackingConnectionState.connecting);
    try {
      final settings = LiveTrackingSettings.instance;
      final aircraft = AircraftSettings.instance;
      final mgr = LiveManager()
        ..addListener((_) => _rebuildOtherPilots());
      final client = LiveClient(
        mgr,
        shareWhenNotFlying: false,
        claimContest: settings.claimContest,
        flightPublic: settings.flightPublic,
        // "Show public tracking" -> xcSetOptions.receiveAllPositions.
        receiveAllPositions: settings.showPublic,
        token: token,
        epoch0Ms: DateTime.now().millisecondsSinceEpoch,
      )
        ..onLog = _log
        // Respect a pause that is already active when the flight starts.
        ..tempDontShare = settings.temporaryDontShare;
      final options = client.buildFlightOptions(
        fix,
        device: const IgcSystemInfo(),
        glider: aircraft.name.isNotEmpty ? aircraft.name : aircraft.displayName,
        gliderCat: _gliderCategory(aircraft),
        tandem: aircraft.tandem,
        faiCompliant: true,
        // Tell XContest this is a replay/simulation so a mock feed is never
        // treated as a real contest flight.
        simulation: simulated,
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
      _mgr = mgr;
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

  /// No usable GPS fix yet: keep showing "connecting" and re-check on a short
  /// fixed cadence. This deliberately avoids the exponential socket backoff
  /// ([_scheduleReconnect]) so sharing starts promptly once GPS appears -
  /// a fresh fix also re-triggers via [_onDataChanged] without waiting.
  void _waitForGps() {
    if (_lastErrorCode != 'gps_unavailable') {
      _log('waiting for GPS fix');
    }
    _lastErrorCode = 'gps_unavailable';
    _setState(LiveTrackingConnectionState.connecting);
    if (_gpsWaitTimer != null || _disposed || _ending) return;
    _gpsWaitTimer = Timer(_gpsWaitInterval, () {
      _gpsWaitTimer = null;
      if (_shouldTrack && _client == null && !_starting && !_ending) {
        _queueLifecycleSync();
      }
    });
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
    // "Temporarily stop sharing" pauses point uploads without ending the
    // flight: feed the flag to the client, which keeps the socket alive but
    // skips queueing fixes (LiveClient.onLocation / Internal.LiveTempDontShare).
    final paused = LiveTrackingSettings.instance.temporaryDontShare;
    if (paused != client.tempDontShare) {
      client.tempDontShare = paused;
      _log(paused ? 'sharing paused (temporary)' : 'sharing resumed');
    }
    final snapshot = _data?.data;
    final fix = _toFix(snapshot);
    if (fix == null) return;
    // Attach the current wind to every chunk, like XCTrack's per-flush
    // AdditionalInfo (LiveProto$AdditionalInfo).
    if (snapshot != null) client.addInfo = _additionalInfo(snapshot);
    if (client.onLocation(fix, DateTime.now().millisecondsSinceEpoch)) {
      _notify();
    }
  }

  /// Builds the `addInfo` side-band for `xcSendChunkHP` from the latest fix.
  ///
  /// `windFromMs = [fromDirectionDeg, speedMs]` mirrors XCTrack's wind vector
  /// (`info/k1` -> `WindInfo(fromDir, speed)`, copied verbatim into
  /// `LiveProto$AdditionalInfo.windFromMs`). `xcActivity` has no ParaBeacon
  /// equivalent, so it is left null.
  AdditionalInfo _additionalInfo(FlightData data) {
    final dir = data.windDirection;
    final speedKph = data.windSpeed;
    final hasWind =
        dir.isFinite && speedKph.isFinite && speedKph > 0 && dir >= 0 && dir < 360;
    if (!hasWind) return const AdditionalInfo();
    return AdditionalInfo(windFromMs: <double>[dir, speedKph / 3.6]);
  }

  /// Whether a mock/simulated location feed may be shared. Real users must
  /// never share OS-mocked positions, so this is only allowed while the
  /// developer simulator is on - which is itself hard-disabled in release
  /// builds ([DebugSettings.simulatorEnabled]).
  bool get _allowMockLocations => DebugSettings.instance.simulatorEnabled;

  Fix? _toFix(FlightData? data) {
    if (data == null || !data.hasFix) return null;
    if (data.isMockLocation && !_allowMockLocations) return null;
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

  /// Flatten the live manager's `positions` (+ `infos` for names) into the
  /// immutable [otherPilots] feed and notify listeners (the map). Called from
  /// the manager's change callback whenever `flightPositions`/`flightInfos`
  /// arrive. Our own flight is excluded by id.
  void _rebuildOtherPilots() {
    final mgr = _mgr;
    if (mgr == null) {
      if (_otherPilots.isNotEmpty) {
        _otherPilots = const <LiveOtherPilot>[];
        _notify();
      }
      return;
    }
    final own = _sessionId;
    final pilots = <LiveOtherPilot>[];
    mgr.positions.forEach((flightId, pos) {
      if (flightId == own) return;
      final lat = pos.point.lat;
      final lon = pos.point.lon;
      if (!lat.isFinite || !lon.isFinite) return;
      final info = mgr.infos[flightId];
      final name = info == null
          ? flightId
          : (info.user.fullname.isNotEmpty
              ? info.user.fullname
              : (info.user.username.isNotEmpty
                  ? info.user.username
                  : flightId));
      pilots.add(LiveOtherPilot(
        flightId: flightId,
        lat: lat,
        lon: lon,
        name: name,
        glider: info?.glider ?? '',
        altitude: pos.point.gpsAlt,
        landed: pos.landed,
        colorArgb: mgr.colour(flightId),
        time: pos.point.timestamp,
      ));
    });
    _otherPilots = List<LiveOtherPilot>.unmodifiable(pilots);
    _notify();
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
      // Server ended the flight while the socket was still up: stop cleanly
      // (no restart) rather than keep streaming into a dead session.
      if (!_ending && client.terminatedByServer) {
        _stopTerminated('xcontest_flight_terminated');
        return;
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
    _gpsWaitTimer?.cancel();
    _gpsWaitTimer = null;
    final client = _client;
    if (client == null) {
      _starting = false;
      if (!_disposed) _setState(LiveTrackingConnectionState.disconnected);
      return;
    }
    if (_ending) return;
    _ending = true;
    _log('landing: draining ${client.queue.length} '
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

  Future<void> _finishFlight({bool allowRestart = true}) async {
    if (!_ending && _client == null) return;
    _landingTimer?.cancel();
    _landingTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _gpsWaitTimer?.cancel();
    _gpsWaitTimer = null;
    final ack = _client?.landingAck;
    _log(ack != null
        ? 'landed: ack xcFlightId=${ack.xcFlightId}'
        : 'flight finished (socket closed)');
    final wire = _wire;
    _wire = null;
    await wire?.close();
    _client?.stop();
    _client = null;
    _mgr = null;
    if (_otherPilots.isNotEmpty) {
      _otherPilots = const <LiveOtherPilot>[];
    }
    _socketUri = null;
    _sessionId = null;
    _ending = false;
    if (!_disposed) _setState(LiveTrackingConnectionState.disconnected);
    // A new flight may have become eligible while we were landing. A
    // server-terminated flight must NOT auto-restart, or we would immediately
    // declare a duplicate flight / hammer the API; the pilot re-arms manually.
    if (allowRestart) _queueLifecycleSync();
  }

  // =======================================================================
  // reconnect (socket dropped mid-flight)
  // =======================================================================
  void _onSocketClosed(Object? error) {
    if (_disposed || _ending || _client == null || !_shouldTrack) return;
    _log('socket closed${error != null ? ': $error' : ''}');
    // The server ends a flight either with a `flightTerminated` frame or by
    // closing the socket with a `terminated` reason (observed: close 1000
    // [{"tag":"terminated"}]). In both cases the flight's WebSocket URI is
    // now defunct (reconnecting 404s), so tear down instead of looping.
    if (_client!.terminatedByServer || _isTerminatedClose(error)) {
      _stopTerminated('xcontest_flight_terminated');
      return;
    }
    _lastErrorCode = 'xcontest_socket_closed';
    _client!.onDisconnected(DateTime.now().millisecondsSinceEpoch);
    _setState(LiveTrackingConnectionState.reconnecting);
    _scheduleReconnect();
  }

  /// A clean server close that signals the flight is over (not a transient
  /// network drop). Transient drops report code 1006 / no reason.
  bool _isTerminatedClose(Object? error) {
    final text = error?.toString().toLowerCase();
    return text != null && text.contains('terminated');
  }

  /// A reconnect handshake failure that means the flight socket no longer
  /// exists (HTTP 404) or is refused (401/403) - retrying cannot recover it.
  bool _isDefunctSocket(Object error) {
    final text = error.toString();
    return text.contains('404') ||
        text.contains('401') ||
        text.contains('403');
  }

  void _stopTerminated(String code) {
    _terminatedCooldownUntilMs =
        DateTime.now().millisecondsSinceEpoch + _terminatedCooldown.inMilliseconds;
    _lastErrorCode = code;
    _log('flight terminated by server - retry in ${_terminatedCooldown.inSeconds}s');
    unawaited(_finishFlight(allowRestart: true));
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
      _log('reconnected to ${uri.host}');
      _setState(LiveTrackingConnectionState.active);
    } on Object catch (error) {
      _log('reconnect failed: $error');
      // The flight socket URI is single-use: a 404 (or auth rejection) means
      // the flight is gone server-side, so stop rather than loop forever.
      if (_isDefunctSocket(error)) {
        _stopTerminated('xcontest_flight_terminated');
        return;
      }
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
    _terminatedRetryTimer?.cancel();
    _terminatedRetryTimer = null;
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
      _gpsWaitTimer?.cancel();
      _terminatedRetryTimer?.cancel();
      _wire?.close();
      _httpClient?.close();
    }
    super.dispose();
  }
}
