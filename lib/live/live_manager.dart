/// live/i1 - the live-tracking state holder (singleton info/t.H0).
library;

import 'config.dart';
import 'proto.dart';
import 'timeutil.dart';
import 'trackpoint.dart';

/// One followed flight: the track accumulated from `flightChunk` frames.
class FollowedFlight {
  final List<LiveTrackpoint> points = <LiveTrackpoint>[];
  DateTime? start;
  double distance = 0;
}

/// live/d0 - a FLARM/device seen nearby (aged out after 5 minutes).
class NearbyTarget {
  final String flarmId;
  final String name;
  final String? flightId;
  final LiveFlightPosition? position;
  final DateTime? tstamp;
  final String aircraft;

  NearbyTarget({
    required this.flarmId,
    this.name = '',
    this.flightId,
    this.position,
    this.tstamp,
    this.aircraft = 'PG',
  });
}

/// live/z2 - one row of the Messages tab.
class LiveMessage {
  final String uuid;
  final String text;
  final DateTime tstamp;
  final bool incoming;
  String status; // SENT | SERVER_ACK | DELIVERED

  LiveMessage({
    required this.uuid,
    required this.text,
    required this.tstamp,
    required this.incoming,
    this.status = 'SENT',
  });
}

/// live/e1 / live/f1 - empty marker event ("something changed, redraw").
class LiveChanged {
  final bool notifyUser;
  LiveChanged({this.notifyUser = true});
}

class LiveManager {
  final Map<String, LiveFlightInfo> infos = <String, LiveFlightInfo>{};
  final Map<String, LiveFlightPosition> positions = <String, LiveFlightPosition>{};
  final Map<String, FollowedFlight> follows = <String, FollowedFlight>{};
  final Map<String, Map<String, dynamic>> groups = <String, Map<String, dynamic>>{};
  final Map<String, NearbyTarget> nearby = <String, NearbyTarget>{};
  final List<LiveMessage> messages = <LiveMessage>[];

  int followingCount = 0;

  final List<void Function(LiveChanged)> _listeners = <void Function(LiveChanged)>[];
  final Set<String> _seenMessages = <String>{};
  final Map<String, int> _colours = <String, int>{};
  final List<int> _colourPool = List<int>.of(kColourPool);

  void addListener(void Function(LiveChanged) fn) => _listeners.add(fn);

  void _notify() {
    for (final l in _listeners) {
      l(LiveChanged());
    }
  }

  // -- colours ------------------------------------------------------------
  int colour(String flight) {
    final existing = _colours[flight];
    if (existing != null) return existing;
    final c = _colourPool.isNotEmpty ? _colourPool.removeAt(0) : kColourFallback;
    _colours[flight] = c;
    return c;
  }

  /// i1.z() - give back colours of flights with no position and no follow.
  void reclaimColours() {
    final dead = _colours.keys
        .where((f) => !positions.containsKey(f) && !follows.containsKey(f))
        .toList();
    for (final f in dead) {
      _colourPool.add(_colours.remove(f)!);
    }
  }

  // -- incoming server data ----------------------------------------------
  /// i1.p(map)
  void applyPositions(Map<String, LiveFlightPosition> incoming) {
    positions
      ..addAll(incoming)
      ..removeWhere((k, _) => !incoming.containsKey(k));
    reclaimColours();
    _notify();
  }

  /// i1.k(uuid, SvrFlightChunk)
  void applyChunk(String flight, List<LiveTrackpoint> chunk) {
    final f = follows.putIfAbsent(flight, () => FollowedFlight());
    if (f.start == null && chunk.isNotEmpty) f.start = utc(chunk.first.timestamp);
    f.points.addAll(chunk);
    reclaimColours();
    _notify();
  }

  /// i1.l(map)
  void applyInfos(Map<String, LiveFlightInfo> incoming) {
    infos.addAll(incoming);
    _notify();
  }

  /// sensors/x1.c() - store a nearby target; publish its position too.
  void updateNearby(NearbyTarget target) {
    nearby[target.flarmId] = target;
    if (target.flightId != null && target.position != null) {
      positions[target.flightId!] = target.position!;
    }
  }

  /// i1.d() - drop targets silent for more than 5 minutes.
  List<String> ageOutNearby(int nowEpochMs) {
    final stale = nearby.entries
        .where((e) =>
            e.value.tstamp == null ||
            nowEpochMs - epochSeconds(e.value.tstamp!) * 1000 > kNearbyFlarmAgeMs)
        .map((e) => e.key)
        .toList();
    for (final k in stale) {
      nearby.remove(k);
    }
    return stale;
  }

  // -- follow management --------------------------------------------------
  void follow(String flight) {
    follows.putIfAbsent(flight, () => FollowedFlight());
    colour(flight);
    _notify();
  }

  void unfollow(String flight) {
    follows.remove(flight);
    reclaimColours();
    _notify();
  }

  void clearFollows() {
    follows.clear();
    reclaimColours();
    _notify();
  }

  bool isFollowing(String flight) => follows.containsKey(flight);

  /// i1.s(false)
  XCFollow buildFollowFrame() => XCFollow(
        flights: follows.entries
            .map((e) => FollowParam(flightUuid: e.key, start: e.value.start))
            .toList(),
      );

  // -- messages -----------------------------------------------------------
  /// i1.m(SvrMessage) - ack immediately, dedupe, then dispatch on content.
  XCMsgAck? handleMessage(SvrMessage msg) {
    final ack = XCMsgAck(uuid: msg.uuid);
    if (!_seenMessages.add(msg.uuid)) return ack;

    switch (msg.content.tag) {
      case 'TextMessage':
        messages.add(LiveMessage(
          uuid: msg.uuid,
          text: msg.content.text,
          tstamp: utc(msg.tstamp ?? DateTime.now()),
          incoming: true,
        ));
      case 'CmDisplayTracklog':
        if (msg.srcGroup != null) follow(msg.srcGroup!);
      case 'CmHideTracklog':
        if (msg.srcGroup != null) unfollow(msg.srcGroup!);
      case 'CmHideAll':
        clearFollows();
      case 'CmNavigateWpt':
        // "Navigating to Livetrack waypoint." - i1.smali:3286-3330
        _notify();
      default:
        break;
    }
    _notify();
    return ack;
  }

  /// i1.n(ackMsg) / i1.o(ackMsgSvr)
  void onMsgAck(String uuid, String status) {
    for (final m in messages) {
      if (m.uuid == uuid) m.status = status;
    }
  }

  /// i1.h(uuid)
  String flightName(String flight) => infos[flight]?.user.username ?? flight;
}
