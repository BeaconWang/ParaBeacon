/// live/c1 (protocol engine) + live/r0 (sender wrapper).
///
/// Lifecycle mirrors the APK:
///   TrackService: Livetrack.Enabled on -> new r0()        (r0 = LiveClient)
///   info/t.b(fix)      -> r0.e(fix) -> c1.h(fix)
///   info/t.j(takeoff)  -> r0.j(launch) + r0.g()           (flush + start timer)
///   info/t.j(landing)  -> r0.k() -> c1.q()                (landed -> XCLanding)
///   info/t.m() (exit)  -> r0.k() -> H0.c()
library;

import 'dart:collection';
import 'dart:convert';

import 'config.dart';
import 'live_manager.dart';
import 'proto.dart';
import 'sha256.dart';
import 'system_info.dart';
import 'timeutil.dart';
import 'trackpoint.dart';
import 'wire.dart';

/// live/o0 - rendered by widget/w/WStatusLine.
enum LiveStatus {
  liveInit,
  liveWaiting,
  liveConnecting,
  liveDisconnected,
  liveSendingData,
  liveSendingLanding,
  liveLandingAcknowledged,
  livePrepare,
}

/// rest/apis/LivetrackApi$FlightOptions - body of POST /api/flight.
class FlightOptions {
  final LiveTrackpoint? position;
  final IgcSystemInfo device;
  final String glider;
  final String gliderCat;
  final bool tandem;
  final bool simulation;
  final bool flpublic; // @SerializedName("public")
  final bool faiCompliant;
  final String? flarmRadioId;
  final int protoVersion;

  FlightOptions({
    this.position,
    this.device = const IgcSystemInfo(),
    this.glider = '',
    this.gliderCat = '',
    this.tandem = false,
    this.simulation = false,
    this.flpublic = false,
    this.faiCompliant = false,
    this.flarmRadioId,
    this.protoVersion = kProtoVersion,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (position != null) 'position': position!.toJson(),
        'device': device,
        'glider': glider,
        'gliderCat': gliderCat,
        'tandem': tandem,
        'simulation': simulation,
        'public': flpublic,
        'faiCompliant': faiCompliant,
        // Gson skips null fields, so the server never sees an explicit null.
        if (flarmRadioId != null) 'flarmRadioId': flarmRadioId,
        'protoVersion': protoVersion,
      };
}

class FlightDeclared {
  final String uri;
  final String flightId;
  const FlightDeclared({required this.uri, required this.flightId});
}

class LiveClient {
  final LiveManager mgr;

  /// prefs (config/t0)
  final bool shareWhenNotFlying; // share position while not flying

  /// Livetrack.ClaimContest
  bool claimContest;

  /// Livetrack.FlightPublic -> FlightOptions."public": this is what publishes
  /// the flight (rest/apis/LivetrackApi$FlightOptions.smali:80-84).
  bool flightPublic;

  final String token;

  /// wall-clock epoch ms of virtual t=0 (demo clock helper)
  final int epoch0Ms;

  LiveClient(
    this.mgr, {
    this.shareWhenNotFlying = true,
    this.claimContest = false,
    this.flightPublic = false,
    this.token = 'demo-token',
    this.epoch0Ms = 0,
  });

  /// c1.w
  final Queue<LiveTrackpointHP> queue = ListQueue<LiveTrackpointHP>();

  /// c1.X
  LiveTrackpointHP? lastPoint;

  /// c1.Y
  List<LiveTrackpointHP> inflight = <LiveTrackpointHP>[];

  /// c1.Z
  bool landed = false;

  /// Internal.LiveTempDontShare - "Position sharing disabled" switch.
  bool tempDontShare = false;

  /// c1.c0
  bool running = true;

  /// c1.d0
  bool flying = false;

  /// c1.f0
  String? launchName;

  /// c1.c
  int sendIntervalMs = kDefaultFlushMs;

  /// c1.g0
  int backoffMs = kBackoffStartMs;

  int? lastConnectMs;
  int? lastActivityMs;
  int? lastNearbyMs;
  int _lastFlushMs = 0;

  LiveStatus status = LiveStatus.liveInit;
  FlightDeclared? flight;
  SvrLandingAck? landingAck;
  int? oldestUnsentS; // shown on the status line
  String? lastError;

  /// Per-chunk side-band attached to every `xcSendChunkHP` (wind estimate and
  /// detected XC activity). XCTrack rebuilds this each flush from the current
  /// wind/activity (LiveProto$AdditionalInfo); callers keep it up to date.
  AdditionalInfo addInfo = const AdditionalInfo();

  /// Uplink for JSON text frames: [Wire] offline, [WebSocketWire] for real.
  LiveWire? wire;

  /// Optional sink for human-readable events about notable *inbound* server
  /// frames (serverInfo interval, error, flightTerminated, acks). Lets the
  /// host surface why a session stalled without parsing the wire itself.
  void Function(String message)? onLog;

  /// Set when the server sends `flightTerminated` for this flight - the
  /// session is over and reconnecting to the same socket is pointless.
  bool terminatedByServer = false;

  final Map<String, int> stats = <String, int>{
    'chunks': 0,
    'points': 0,
    'bytes': 0,
    'framesRecv': 0,
  };

  Map<String, dynamic> lastRest = <String, dynamic>{};

  // =======================================================================
  // REST: declare the flight, get the WS uri
  // =======================================================================
  /// Builds the `POST /api/flight` body. Pure - no network.
  FlightOptions buildFlightOptions(
    Fix fix, {
    IgcSystemInfo? device,
    String glider = 'Demo Glider',
    String gliderCat = 'FAI-3',
    bool tandem = false,
    bool faiCompliant = true,
    bool? simulation,
  }) {
    return FlightOptions(
      position: LiveTrackpoint.fromFix(fix),
      device: device ?? const IgcSystemInfo(),
      glider: glider,
      gliderCat: gliderCat,
      tandem: tandem,
      // Explicit override (e.g. a mock/simulated feed) wins; otherwise a fix
      // with no valid GPS time is treated as a replay.
      simulation: simulation ?? !fix.timeValid,
      flpublic: flightPublic,
      faiCompliant: faiCompliant,
    );
  }

  /// Offline stand-in for `POST /api/flight` (used by the demo and tests).
  ///
  /// Real apps go through [LivetrackApi.createFlight], which performs the
  /// signed request and returns the WebSocket uri the server hands out.
  FlightDeclared declareFlight(
    Fix fix, {
    IgcSystemInfo? device,
    String glider = 'Demo Glider',
    String gliderCat = 'FAI-3',
    bool tandem = false,
    bool faiCompliant = true,
  }) {
    final opts = buildFlightOptions(
      fix,
      device: device,
      glider: glider,
      gliderCat: gliderCat,
      tandem: tandem,
      faiCompliant: faiCompliant,
    );

    final body = jsonEncode(opts.toJson());
    final signature = hex(hmacSha256(
      utf8.encode(kClientHmacKey),
      utf8.encode(body),
    ));

    lastRest = <String, dynamic>{
      'url': '${kBaseUrl}flight',
      'headers': <String, String>{
        'Authorization': 'Bearer $token',
        'client-id': kClientId,
        'client-hmac': signature,
        'Content-Type': 'application/json',
      },
      'body': body,
    };

    flight = FlightDeclared(
      uri: 'wss://live2.xcontest.org/ws/${_id()}',
      flightId: _id(),
    );
    status = LiveStatus.liveWaiting;
    return flight!;
  }

  int _counter = 0;
  String _id() {
    _counter++;
    return '${_counter.toString().padLeft(8, '0')}-0000-4000-8000-${(_counter * 7).toString().padLeft(12, '0')}';
  }

  // =======================================================================
  // WebSocket lifecycle
  // =======================================================================
  void connect(int nowMs) {
    status = LiveStatus.liveConnecting;
    lastConnectMs = nowMs;
    lastActivityMs = nowMs;
    onConnected();
  }

  /// c1.b(ws, headers)
  void onConnected() {
    status = LiveStatus.liveWaiting;
    send(XCSetOptions(
      options: ConnOptions(
        knownFlights: mgr.follows.keys.toList(),
        receiveAllPositions: false,
      ),
    ));
    sendFollows();
    final pending =
        mgr.messages.where((m) => m.status == 'SENT').map((m) => m.uuid).toList();
    if (pending.isNotEmpty) send(XCGetMessageStatus(uuids: pending));
  }

  /// c1.c()
  void onDisconnected(int nowMs) {
    status = LiveStatus.liveDisconnected;
    if (running) scheduleReconnect(nowMs);
  }

  /// c1.g() - returns the delay in ms, or -1 when giving up.
  int scheduleReconnect(int nowMs) {
    if (landed) {
      // c1.smali:1047-1094 - check the give-up threshold against the current
      // backoff BEFORE doubling, then double and use that as the delay.
      if (backoffMs > kBackoffGiveUpMs) {
        running = false; // "Giving up reconnecting."
        return -1;
      }
      backoffMs *= 2;
      return backoffMs;
    }
    final gap = lastConnectMs == null ? 1 << 60 : nowMs - lastConnectMs!;
    return gap < kConnectionShortMs ? kReconnectSlowMs : kReconnectFastMs;
  }

  bool reconnect(int nowMs) {
    final delay = scheduleReconnect(nowMs);
    if (delay < 0) return false;
    connect(nowMs);
    return true;
  }

  /// c1.r()
  void stop() {
    running = false;
    status = LiveStatus.liveInit;
  }

  // =======================================================================
  // uplink
  // =======================================================================
  /// c1.q()
  void setLanded() => landed = true;

  /// r0.j() + r0.g()
  void onTakeoff(String launch, int nowMs) {
    launchName = launch;
    flying = true;
    landed = false;
    flush(nowMs);
  }

  /// c1.h(loc) - the hot path, called for every GPS fix.
  bool onLocation(Fix fix, int nowMs) {
    // c1.m(loc): only flying + valid fixes are eligible.
    if (!_accept(fix)) return false;
    // A valid fix means the data feed is alive, so keep the connection
    // considered active even while sharing is paused (prevents the idle
    // watchdog from dropping the socket during a temporary pause).
    lastActivityMs = nowMs;
    // Internal.LiveTempDontShare (c1.smali:2470-2498): when sharing is paused
    // the point is simply NOT queued - the socket and flight stay alive, so
    // the pilot can resume without starting a new flight.
    if (tempDontShare) return false;
    final point = LiveTrackpointHP.fromFix(fix);
    // drop duplicates / out-of-order fixes (c1.smali:2496-2591)
    if (lastPoint != null &&
        epochSeconds(point.timestamp) <= epochSeconds(lastPoint!.timestamp)) {
      return false;
    }
    queue.addLast(point);
    lastPoint = point;
    return true;
  }

  /// c1.m(loc) - eligibility gate: flying (or share-when-not-flying) + valid
  /// GPS time. `Internal.LiveTempDontShare` is intentionally NOT checked here
  /// (it is a separate pause handled in [onLocation]), matching the reference
  /// where `m()` and the `W3` gate are distinct.
  bool _accept(Fix fix) {
    if (!fix.timeValid) return false;
    if (!flying && !shareWhenNotFlying) return false;
    return true;
  }

  /// j8/n - the batching worker on the LiveWorkerThread handler.
  ///
  /// Mirrors the reference `c1` single-deque model: points stay in [queue]
  /// until the server confirms them with an `ackChunk`. Every flush re-sends
  /// the front of the queue (up to [kMaxChunkPoints]), so *newly appended*
  /// fixes are always included even while an earlier batch is still unacked.
  /// `ackChunk` then removes the confirmed prefix from the front of the queue
  /// (see [_onAckChunk]). This is what keeps the live track advancing instead
  /// of freezing on a stuck in-flight batch.
  Map<String, dynamic>? flush(int nowMs) {
    if (wire == null) return null;

    if (queue.isEmpty) {
      inflight = <LiveTrackpointHP>[];
      oldestUnsentS = null;
      if (landed) return _sendLanding();
      if (running) status = LiveStatus.liveWaiting;
      return null;
    }

    final n = queue.length < kMaxChunkPoints ? queue.length : kMaxChunkPoints;
    // The batch we are sending now; the points REMAIN in the queue until an
    // ackChunk trims them. `inflight` is kept only for status/landing checks.
    inflight = <LiveTrackpointHP>[for (final p in queue.take(n)) p];
    oldestUnsentS = epochSeconds(inflight.first.timestamp);

    status = LiveStatus.liveSendingData;
    return send(XCSendChunkHP(pointsHP: inflight, addInfo: addInfo));
  }

  Map<String, dynamic> _sendLanding() {
    status = LiveStatus.liveSendingLanding;
    return send(XCLanding(claimContest: claimContest, faiCompliant: true));
  }

  /// True once the queue is empty - every point has been acknowledged. The
  /// landing frame is only sent after this becomes true (see [flush]).
  bool get isDrained => queue.isEmpty;

  Map<String, dynamic> sendFollows() => send(mgr.buildFollowFrame());

  /// c1.o() - every 3 minutes.
  Map<String, dynamic> sendNearbyFlarms(int nowMs) {
    final positions = <String, FlarmFlightPosition>{};
    for (final t in mgr.nearby.values) {
      final pos = t.position;
      if (pos == null) continue;
      positions[t.flarmId] = FlarmFlightPosition(
        lat: pos.point.lat,
        lon: pos.point.lon,
        timestamp: pos.point.timestamp,
        alt: pos.point.gpsAlt,
        speed: pos.speed,
        vspeed: pos.vspeed,
        elevation: pos.point.elevation,
      );
    }
    lastNearbyMs = nowMs;
    return send(XcNearbyFlarms(positions: positions));
  }

  /// gson.toJson -> UTF-8 bytes -> WebSocket text frame (c1.smali:7084-7110)
  Map<String, dynamic> send(OutFrame frame) {
    final json = frame.toJson();
    final text = jsonEncode(json);
    final bytes = utf8.encode(text).length;
    stats['bytes'] = (stats['bytes'] ?? 0) + bytes;
    if (frame is XCSendChunkHP) {
      stats['chunks'] = (stats['chunks'] ?? 0) + 1;
      stats['points'] = (stats['points'] ?? 0) + frame.pointsHP.length;
    }
    wire?.clientSend(text);
    return <String, dynamic>{
      'tag': json['tag'],
      'bytes': bytes,
      'text': text,
    };
  }

  // =======================================================================
  // downlink
  // =======================================================================
  /// c1.d(ws, text) -> LiveDeserializer -> c1.l(frame)
  ///
  /// The server batches frames as a JSON **array** of objects
  /// (e.g. `[{"tag":"ackChunk",...},{"tag":"serverInfo",...}]`); a lone object
  /// is also accepted. Each element is dispatched in order. Robust against
  /// malformed input: a decode/parse failure is logged, never thrown, so one
  /// bad frame cannot kill the receive path (an exception here would escape
  /// the socket stream listener and be swallowed by the zone, hiding every
  /// later frame).
  void onText(String text) {
    stats['framesRecv'] = (stats['framesRecv'] ?? 0) + 1;
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        for (final element in decoded) {
          _dispatchOne(element);
        }
      } else {
        _dispatchOne(decoded);
      }
    } on Object catch (error) {
      onLog?.call('<- parse error: $error on ${_preview(text)}');
    }
  }

  void _dispatchOne(Object? node) {
    if (node is Map<String, dynamic>) {
      dispatch(LiveDeserializer.parseMap(node));
    } else {
      onLog?.call('<- non-object frame element: ${_preview('$node')}');
    }
  }

  /// Raw non-text (binary) frame from the socket. The livetrack protocol is
  /// JSON text, so this should never happen - log it rather than drop silently.
  void onBinary(int byteCount) {
    stats['framesRecv'] = (stats['framesRecv'] ?? 0) + 1;
    onLog?.call('<- binary frame ($byteCount B) - ignored');
  }

  String _preview(String text) =>
      text.length > 160 ? '${text.substring(0, 160)}…' : text;

  /// c1.l(p0) - the big switch over server frame types.
  void dispatch(SvrFrame frame) {
    switch (frame) {
      case SvrAckChunk():
        _onAckChunk(frame);
      case SvrLandingAck():
        landingAck = frame;
        status = LiveStatus.liveLandingAcknowledged;
        onLog?.call('<- landingAck xcFlightId=${frame.xcFlightId}');
      case SvrFlightInfos():
        mgr.applyInfos(frame.infos);
        onLog?.call('<- flightInfos (${frame.infos.length})');
      case SvrFlightPositions():
        mgr.applyPositions(frame.positions);
        onLog?.call('<- flightPositions (${frame.positions.length})');
      case SvrFlightChunk():
        if (frame.flightId != null) mgr.applyChunk(frame.flightId!, frame.trackChunk);
        onLog?.call('<- flightChunk');
      case SvrMessage():
        final ack = mgr.handleMessage(frame);
        if (ack != null) send(ack); // ack immediately (i1.m)
        onLog?.call('<- message');
      case SvrAckMsg():
        mgr.onMsgAck(frame.uuid, 'DELIVERED');
        onLog?.call('<- ackMsg');
      case SvrAckMsgSvr():
        mgr.onMsgAck(frame.uuid, 'SERVER_ACK');
        onLog?.call('<- ackMsgSvr');
      case SvrServerInfo():
        mgr.followingCount = frame.following;
        applyInterval(frame.interval);
        onLog?.call('<- serverInfo: interval=${frame.interval}s '
            '-> send every ${sendIntervalMs ~/ 1000}s (following ${frame.following})');
      case SvrError():
        lastError = frame.error;
        onLog?.call('<- server error: ${frame.error}');
      case SvrFlightTerminated():
        terminatedByServer = true;
        onLog?.call('<- flightTerminated by server');
      case SvrUnknownFrame():
        onLog?.call('<- UNKNOWN frame "${frame.tag}": ${_previewRaw(frame.raw)}');
      default:
        onLog?.call('<- ${frame.tag}');
    }
  }

  /// Short, safe preview of an unrecognised server frame for the debug log.
  String _previewRaw(Map<String, dynamic> raw) {
    final text = raw.keys.take(8).join(',');
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }

  /// `ackChunk` confirms every point up to and including `lastTstamp`. Mirror
  /// the reference (c1.smali:5187-5296): remove the confirmed prefix from the
  /// FRONT of the queue with `removeFirst()`. Points stay queued (and keep
  /// being re-sent) until this trims them, so a dropped/slow ack never freezes
  /// the track - the next flush simply re-sends what is still pending.
  void _onAckChunk(SvrAckChunk ack) {
    if (ack.lastTstamp == null) {
      onLog?.call('<- ackChunk (empty)');
      return;
    }
    final cutoff = epochSeconds(ack.lastTstamp!);
    var confirmed = 0;
    while (queue.isNotEmpty &&
        epochSeconds(queue.first.timestamp) <= cutoff) {
      queue.removeFirst();
      confirmed++;
    }
    inflight = inflight
        .where((p) => epochSeconds(p.timestamp) > cutoff)
        .toList();
    oldestUnsentS = queue.isEmpty ? null : epochSeconds(queue.first.timestamp);
    onLog?.call('<- ackChunk: $confirmed confirmed, ${queue.length} pending');
  }

  /// c1.smali:6080-6156 - server may retune the send period, 1..119 s.
  void applyInterval(int intervalS) {
    if (intervalS >= kMinServerIntervalS && intervalS <= kMaxServerIntervalS) {
      sendIntervalMs = intervalS * 1000;
    }
  }

  // =======================================================================
  // periodic tick (replaces the Handler + coroutines)
  // =======================================================================
  List<String> tick(int nowMs) {
    final events = <String>[];

    // While landed, drain as fast as acks allow (once the previous chunk is
    // acknowledged) so the terminating `xcLanding` goes out promptly instead
    // of waiting up to a full `sendIntervalMs` - c1.q() / j8/n flush loop.
    final dueFlush =
        nowMs - _lastFlushMs >= sendIntervalMs || (landed && inflight.isEmpty);
    if (dueFlush) {
      final sent = flush(nowMs);
      _lastFlushMs = nowMs;
      if (sent != null) {
        final tag = sent['tag'];
        // After a chunk flush `inflight` holds exactly the points just sent.
        events.add(tag == 'xcSendChunkHP'
            ? 'flush -> xcSendChunkHP (${inflight.length} pt, ${sent['bytes']} B)'
            : 'flush -> $tag (${sent['bytes']} B)');
      }
    }

    if (lastNearbyMs == null || nowMs - lastNearbyMs! >= kNearbyFlarmPeriodMs) {
      sendNearbyFlarms(nowMs);
      events.add('xcNearbyFlarms');
    }

    final stale = mgr.ageOutNearby(epoch0Ms + nowMs);
    if (stale.isNotEmpty) events.add('aged out ${stale.length} nearby target(s)');

    if (lastActivityMs != null &&
        !landed &&
        nowMs - lastActivityMs! >= kIdleDisconnectMs) {
      events.add('idle timeout -> disconnect');
      onDisconnected(nowMs);
      lastActivityMs = nowMs;
    }
    return events;
  }
}
