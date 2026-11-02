/// LiveProto$* frames + LiveDeserializer.
///
/// Every frame is JSON with a "tag" discriminator; LiveDeserializer picks the
/// concrete class from that tag (LiveDeserializer.smali:36-175). Unknown tags
/// become SvrUnknownFrame and are only logged.
///
/// Field names are kept verbatim from smali. Where a field carries
/// @SerializedName("contents") (annotation rc/b) it goes on the wire as
/// "contents" - see XCFollow.flights and SvrFlightPositions.positions.
library;

import 'codec.dart';
import 'timeutil.dart';
import 'trackpoint.dart';

// ---------------------------------------------------------------------------
// value objects
// ---------------------------------------------------------------------------

class LiveFlightUser {
  final String username;
  final String fullname;
  final int login;
  final String? flarmRadioId;

  const LiveFlightUser({
    this.username = '',
    this.fullname = '',
    this.login = 0,
    this.flarmRadioId,
  });

  factory LiveFlightUser.fromJson(Map<String, dynamic> m) => LiveFlightUser(
        username: m['username'] as String? ?? '',
        fullname: m['fullname'] as String? ?? '',
        login: (m['login'] as num?)?.toInt() ?? 0,
        flarmRadioId: m['flarmRadioId'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'username': username,
        'fullname': fullname,
        'login': login,
        'flarmRadioId': flarmRadioId,
      };
}

class LiveFlightPosition {
  final LiveTrackpoint point;
  final double speed;
  final double vspeed;
  final bool landed;

  const LiveFlightPosition({
    required this.point,
    this.speed = 0,
    this.vspeed = 0,
    this.landed = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...point.toJson(),
        'speed': speed,
        'vspeed': vspeed,
        'landed': landed,
      };

  factory LiveFlightPosition.fromJson(Map<String, dynamic> m) =>
      LiveFlightPosition(
        point: LiveTrackpoint.fromJson(m),
        speed: (m['speed'] as num?)?.toDouble() ?? 0,
        vspeed: (m['vspeed'] as num?)?.toDouble() ?? 0,
        landed: m['landed'] as bool? ?? false,
      );
}

class LiveFlightCountry {
  final String iso;
  final String name;
  const LiveFlightCountry({this.iso = '', this.name = ''});
  factory LiveFlightCountry.fromJson(Map<String, dynamic> m) =>
      LiveFlightCountry(iso: m['iso'] as String? ?? '', name: m['name'] as String? ?? '');
}

class LiveFlightInfo {
  final LiveFlightUser user;
  final LiveFlightCountry country;
  final String glider;
  final String faiCategory;
  final String launch;
  final LiveTrackpoint? launchPoint;

  const LiveFlightInfo({
    this.user = const LiveFlightUser(),
    this.country = const LiveFlightCountry(),
    this.glider = '',
    this.faiCategory = '',
    this.launch = '',
    this.launchPoint,
  });

  factory LiveFlightInfo.fromJson(Map<String, dynamic> m) => LiveFlightInfo(
        user: m['user'] == null
            ? const LiveFlightUser()
            : LiveFlightUser.fromJson(m['user'] as Map<String, dynamic>),
        country: m['country'] == null
            ? const LiveFlightCountry()
            : LiveFlightCountry.fromJson(m['country'] as Map<String, dynamic>),
        glider: m['glider'] as String? ?? '',
        faiCategory: m['faiCategory'] as String? ?? '',
        launch: m['launch'] as String? ?? '',
        launchPoint: m['launchPoint'] == null
            ? null
            : LiveTrackpoint.fromJson(m['launchPoint'] as Map<String, dynamic>),
      );
}

class LiveMsgContent {
  final String tag;
  final String text;
  const LiveMsgContent({this.tag = 'TextMessage', this.text = ''});
  Map<String, dynamic> toJson() => <String, dynamic>{'tag': tag, 'text': text};
}

class LiveMsgTarget {
  final String? groupId;
  final String? username;
  const LiveMsgTarget({this.groupId, this.username});
  Map<String, dynamic> toJson() => groupId != null
      ? <String, dynamic>{'groupid': groupId}
      : <String, dynamic>{'username': username};
}

// ---------------------------------------------------------------------------
// client -> server
// ---------------------------------------------------------------------------

/// Anything the client can put on the wire.
abstract class OutFrame {
  Map<String, dynamic> toJson();
}

class AdditionalInfo {
  final List<double> windFromMs;
  final String? xcActivity;
  final int xcActivityConfidence;

  const AdditionalInfo({
    this.windFromMs = const <double>[0, 0],
    this.xcActivity,
    this.xcActivityConfidence = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'windFromMs': windFromMs,
        'xcActivity': xcActivity,
        'xcActivityConfidence': xcActivityConfidence,
      };
}

class XCSendChunkHP implements OutFrame {
  final List<LiveTrackpointHP> pointsHP;
  final AdditionalInfo addInfo;
  final String tag;

  XCSendChunkHP({required this.pointsHP, required this.addInfo})
      : tag = 'xcSendChunkHP';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tag': tag,
        'pointsHP': compressPoints(pointsHP),
        'addInfo': addInfo.toJson(),
      };
}

class ConnOptions {
  final List<String> knownFlights;
  final bool receiveAllPositions;
  const ConnOptions({this.knownFlights = const <String>[], this.receiveAllPositions = false});
}

class XCSetOptions implements OutFrame {
  final ConnOptions options;
  final String tag;
  XCSetOptions({required this.options}) : tag = 'xcSetOptions';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tag': tag,
        // The `options` field is @SerializedName("contents") and the
        // ConnOptions object is the value directly - i.e. a top-level
        // `contents`, NOT `options.contents`
        // (LiveProto$XCSetOptions.smali:10-13). The server rejects the nested
        // form with: parsing ProtoXcSetOptions failed, key "contents" not found.
        'contents': <String, dynamic>{
          'knownFlights': options.knownFlights,
          'receiveAllPositions': options.receiveAllPositions,
        },
      };
}

class FollowParam {
  final String flightUuid;
  final DateTime? start;
  const FollowParam({required this.flightUuid, this.start});
}

class XCFollow implements OutFrame {
  final List<FollowParam> flights;
  final String tag;
  XCFollow({this.flights = const <FollowParam>[]}) : tag = 'xcFollow';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tag': tag,
        'contents': flights
            .map((f) => <String, dynamic>{
                  'flightUuid': f.flightUuid,
                  'start': f.start == null ? null : utcToJson(f.start!),
                })
            .toList(),
      };
}

class XCLanding implements OutFrame {
  final bool claimContest;
  final bool faiCompliant;
  final String tag;
  XCLanding({this.claimContest = false, this.faiCompliant = false})
      : tag = 'xcLanding';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tag': tag,
        'claimContest': claimContest,
        'faiCompliant': faiCompliant,
      };
}

class XCSendMessage implements OutFrame {
  final String uuid;
  final LiveMsgContent content;
  final LiveMsgTarget target;
  final DateTime tstamp;
  final String tag;
  XCSendMessage({
    required this.uuid,
    required this.content,
    required this.target,
    required this.tstamp,
  }) : tag = 'xcSendMessage';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tag': tag,
        'uuid': uuid,
        'content': content.toJson(),
        'target': target.toJson(),
        'tstamp': utcToJson(tstamp),
      };
}

class XCMsgAck implements OutFrame {
  final String uuid;
  final String tag;
  XCMsgAck({required this.uuid}) : tag = 'xcMsgAck';
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'tag': tag, 'uuid': uuid};
}

class FlarmFlightPosition {
  final double lat;
  final double lon;
  final DateTime timestamp;
  final int alt;
  final double speed;
  final double vspeed;
  final int heading;
  final int elevation;

  const FlarmFlightPosition({
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.alt = 0,
    this.speed = 0,
    this.vspeed = 0,
    this.heading = 0,
    this.elevation = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': lat,
        'lon': lon,
        'timestamp': utcToJson(timestamp),
        'alt': alt,
        'speed': speed,
        'vspeed': vspeed,
        'heading': heading,
        'elevation': elevation,
      };
}

class XcNearbyFlarms implements OutFrame {
  final Map<String, FlarmFlightPosition> positions;
  final String tag;
  XcNearbyFlarms({required this.positions}) : tag = 'xcNearbyFlarms';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tag': tag,
        'positions': positions.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class XCGetMessageStatus implements OutFrame {
  final List<String> uuids;
  final String tag;
  XCGetMessageStatus({required this.uuids}) : tag = 'xcGetMessageStatus';
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'tag': tag,
        'contents': uuids,
      };
}

// ---------------------------------------------------------------------------
// server -> client
// ---------------------------------------------------------------------------

abstract class SvrFrame {
  String get tag;
}

class SvrAckChunk implements SvrFrame {
  @override
  final String tag = 'ackChunk';
  final DateTime? lastTstamp;
  SvrAckChunk({this.lastTstamp});
}

class SvrLandingAck implements SvrFrame {
  @override
  final String tag = 'landingAck';
  final String url;
  final int xcFlightId;
  SvrLandingAck({this.url = '', this.xcFlightId = 0});
}

class SvrFlightInfos implements SvrFrame {
  @override
  final String tag = 'flightInfos';
  final Map<String, LiveFlightInfo> infos;
  SvrFlightInfos({required this.infos});
}

class SvrFlightPositions implements SvrFrame {
  @override
  final String tag = 'flightPositions';
  final Map<String, LiveFlightPosition> positions;
  SvrFlightPositions({required this.positions});
}

class SvrFlightChunk implements SvrFrame {
  @override
  final String tag = 'flightChunk';
  final String? flightId;
  final LiveFlightPosition? position;
  final List<LiveTrackpoint> trackChunk;
  SvrFlightChunk({this.flightId, this.position, required this.trackChunk});
}

class SvrMessage implements SvrFrame {
  @override
  final String tag = 'message';
  final String uuid;
  final LiveFlightUser from;
  final String? srcGroup;
  final DateTime? tstamp;
  final LiveMsgContent content;
  SvrMessage({
    required this.uuid,
    required this.from,
    this.srcGroup,
    this.tstamp,
    required this.content,
  });
}

class SvrAckMsg implements SvrFrame {
  @override
  final String tag = 'ackMsg';
  final String uuid;
  final String targetUser;
  final DateTime? ackTimestamp;
  SvrAckMsg({required this.uuid, this.targetUser = '', this.ackTimestamp});
}

class SvrAckMsgSvr implements SvrFrame {
  @override
  final String tag = 'ackMsgSvr';
  final String uuid;
  final String targetUser;
  final DateTime? ackTimestamp;
  SvrAckMsgSvr({required this.uuid, this.targetUser = '', this.ackTimestamp});
}

class SvrServerInfo implements SvrFrame {
  @override
  final String tag = 'serverInfo';
  final int following;
  final int interval;
  final List<dynamic> groups;
  SvrServerInfo({this.following = 0, this.interval = 0, this.groups = const <dynamic>[]});
}

class SvrError implements SvrFrame {
  @override
  final String tag = 'error';
  final String error;
  SvrError({this.error = ''});
}

class SvrFlightTerminated implements SvrFrame {
  @override
  final String tag = 'flightTerminated';
  final String? flightId;
  SvrFlightTerminated({this.flightId});
}

class SvrUnknownFrame implements SvrFrame {
  @override
  final String tag;
  final Map<String, dynamic> raw;
  SvrUnknownFrame({required this.tag, required this.raw});
}

// ---------------------------------------------------------------------------
// LiveDeserializer
// ---------------------------------------------------------------------------

class LiveDeserializer {
  static SvrFrame parseMap(Map<String, dynamic> m) {
    final tag = m['tag'] as String? ?? '';
    switch (tag) {
      case 'ackChunk':
        return SvrAckChunk(
          lastTstamp: m['lastTstamp'] == null ? null : utcFromJson(m['lastTstamp'] as String),
        );
      case 'landingAck':
        return SvrLandingAck(
          url: m['url'] as String? ?? '',
          xcFlightId: (m['xcFlightId'] as num?)?.toInt() ?? 0,
        );
      case 'flightPositions':
        return SvrFlightPositions(positions: _contents(m['positions']).map(
            (k, v) => MapEntry(k, LiveFlightPosition.fromJson(v))));
      case 'flightInfos':
        return SvrFlightInfos(infos: _contents(m['infos'])
            .map((k, v) => MapEntry(k, LiveFlightInfo.fromJson(v))));
      case 'flightChunk':
        return SvrFlightChunk(
          flightId: m['flightId'] as String?,
          position: m['position'] == null
              ? null
              : LiveFlightPosition.fromJson(m['position'] as Map<String, dynamic>),
          trackChunk: decompressPoints(m['trackChunk'] as String? ?? ''),
        );
      case 'message':
        final c = m['content'] as Map<String, dynamic>? ?? <String, dynamic>{};
        return SvrMessage(
          uuid: m['uuid'] as String? ?? '',
          from: LiveFlightUser.fromJson(m['from'] as Map<String, dynamic>? ?? <String, dynamic>{}),
          srcGroup: m['srcGroup'] as String?,
          tstamp: m['tstamp'] == null ? null : utcFromJson(m['tstamp'] as String),
          content: LiveMsgContent(
            tag: c['tag'] as String? ?? 'TextMessage',
            text: c['text'] as String? ?? '',
          ),
        );
      case 'ackMsg':
        return SvrAckMsg(
          uuid: m['uuid'] as String? ?? '',
          targetUser: m['targetUser'] as String? ?? '',
          ackTimestamp: m['ackTimestamp'] == null ? null : utcFromJson(m['ackTimestamp'] as String),
        );
      case 'ackMsgSvr':
        return SvrAckMsgSvr(
          uuid: m['uuid'] as String? ?? '',
          targetUser: m['targetUser'] as String? ?? '',
          ackTimestamp: m['ackTimestamp'] == null ? null : utcFromJson(m['ackTimestamp'] as String),
        );
      case 'serverInfo':
        return SvrServerInfo(
          following: (m['following'] as num?)?.toInt() ?? 0,
          interval: (m['interval'] as num?)?.toInt() ?? 0,
          groups: (m['groups'] as List<dynamic>?) ?? const <dynamic>[],
        );
      case 'error':
        return SvrError(error: m['error'] as String? ?? '');
      case 'flightTerminated':
        return SvrFlightTerminated(flightId: m['flightId'] as String?);
      default:
        return SvrUnknownFrame(tag: tag, raw: m);
    }
  }

  static Map<String, Map<String, dynamic>> _contents(dynamic node) {
    final map = (node as Map<String, dynamic>?) ?? <String, dynamic>{};
    if (map.containsKey('contents')) {
      final inner = map['contents'] as Map<String, dynamic>;
      return inner.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
    }
    return map.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
  }
}
