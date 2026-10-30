/// Mock of live2.xcontest.org.
///
/// Implements just enough of the server side to exercise the client:
///   * validates the client-id / client-hmac of POST /flight
///   * answers xcSendChunkHP with ackChunk(lastTstamp)
///   * answers xcLanding with landingAck(url, xcFlightId)
///   * pushes flightPositions / flightChunk / serverInfo / message
library;

import 'dart:convert';

import 'codec.dart';
import 'config.dart';
import 'sha256.dart';
import 'timeutil.dart';
import 'trackpoint.dart';
import 'wire.dart';

class ReceivedChunk {
  final int seq;
  final List<LiveTrackpointHP> points;
  final int payloadBytes;
  ReceivedChunk(this.seq, this.points, this.payloadBytes);
}

class MockLiveServer {
  Wire? wire;
  final List<ReceivedChunk> received = <ReceivedChunk>[];
  final Map<String, dynamic>? declared = null;
  bool landed = false;
  int following = 0;
  int _seq = 0;

  final List<String> otherIds;

  MockLiveServer({int otherPilots = 2})
      : otherIds = List<String>.generate(otherPilots, (i) => 'other-pilot-$i');

  /// Reproduce the server-side check of the hardcoded client secret.
  bool verifyFlightRequest(Map<String, String> headers, String body) {
    if (headers['client-id'] != kClientId) return false;
    final expected = hex(hmacSha256(
      utf8.encode(kClientHmacKey),
      utf8.encode(body),
    ));
    return expected == headers['client-hmac'];
  }

  List<String> onText(String text) {
    final Map<String, dynamic> frame;
    try {
      frame = jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      return <String>[jsonEncode(<String, dynamic>{'tag': 'error', 'error': 'malformed frame'})];
    }
    final tag = frame['tag'] as String? ?? '';
    final replies = switch (tag) {
      'xcSendChunkHP' => _onChunk(frame),
      'xcLanding' => _onLanding(),
      'xcSetOptions' => _onSetOptions(),
      'xcFollow' => _onFollow(frame),
      'xcNearbyFlarms' => <Map<String, dynamic>>[],
      'xcMsgAck' => <Map<String, dynamic>>[],
      'xcGetMessageStatus' => _onGetMessageStatus(frame),
      'xcSendMessage' => _onSendMessage(frame),
      _ => <Map<String, dynamic>>[
          <String, dynamic>{'tag': 'error', 'error': 'unknown tag $tag'},
        ],
    };
    return replies.map(jsonEncode).toList();
  }

  List<Map<String, dynamic>> _onChunk(Map<String, dynamic> frame) {
    final payload = frame['pointsHP'] as String;
    final points = decompressPointsHP(payload);
    _seq++;
    received.add(ReceivedChunk(_seq, points, utf8.encode(payload).length));

    final last = points.isEmpty ? null : points.last.timestamp;
    final out = <Map<String, dynamic>>[
      <String, dynamic>{
        'tag': 'ackChunk',
        'lastTstamp': last == null ? null : utcToJson(last),
      },
    ];
    if (_seq % 3 == 0) out.add(_flightPositions());
    return out;
  }

  List<Map<String, dynamic>> _onLanding() {
    landed = true;
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'tag': 'landingAck',
        'url': 'https://www.xcontest.org/flight/123456',
        'xcFlightId': 123456,
      },
    ];
  }

  List<Map<String, dynamic>> _onSetOptions() => <Map<String, dynamic>>[
        _serverInfo(),
      ];

  List<Map<String, dynamic>> _onFollow(Map<String, dynamic> frame) {
    final flights = (frame['contents'] as List<dynamic>?) ?? <dynamic>[];
    following = flights.length;
    final out = <Map<String, dynamic>>[_serverInfo()];
    if (flights.isNotEmpty) {
      final first = flights.first as Map<String, dynamic>;
      out.add(_flightChunk(first['flightUuid'] as String?));
    }
    return out;
  }

  List<Map<String, dynamic>> _onGetMessageStatus(Map<String, dynamic> frame) {
    final uuids = (frame['contents'] as List<dynamic>?) ?? <dynamic>[];
    return <Map<String, dynamic>>[
      for (final u in uuids)
        <String, dynamic>{
          'tag': 'ackMsgSvr',
          'uuid': u,
          'targetUser': 'demo',
          'ackTimestamp': utcToJson(DateTime.now()),
        },
    ];
  }

  List<Map<String, dynamic>> _onSendMessage(Map<String, dynamic> frame) =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'tag': 'ackMsg',
          'uuid': frame['uuid'],
          'targetUser': 'demo',
          'ackTimestamp': utcToJson(DateTime.now()),
        },
      ];

  Map<String, dynamic> _serverInfo() => <String, dynamic>{
        'tag': 'serverInfo',
        'following': following,
        'interval': 30,
        'groups': <dynamic>[],
      };

  Map<String, dynamic> _flightPositions() => <String, dynamic>{
        'tag': 'flightPositions',
        'positions': <String, dynamic>{
          'contents': <String, dynamic>{
            for (var i = 0; i < otherIds.length; i++)
              otherIds[i]: <String, dynamic>{
                'lat': 46.5 + i * 0.01,
                'lon': 6.6 + i * 0.01,
                'tstamp': utcToJson(DateTime.now()),
                'gpsAlt': 1800 + i * 50,
                'baroAlt': 1810 + i * 50,
                'elevation': 400,
                'speed': 11.0 + i,
                'vspeed': -0.6,
                'landed': false,
              },
          },
        },
      };

  /// A track segment of a followed flight - normal precision (1e5).
  Map<String, dynamic> _flightChunk(String? flightUuid) {
    final base = DateTime.now();
    final pts = <LiveTrackpoint>[
      for (var i = 0; i < 5; i++)
        LiveTrackpoint(
          lat: 46.51 + i * 0.001,
          lon: 6.61 + i * 0.001,
          timestamp: base.add(Duration(seconds: 10 * i)),
          gpsAlt: 1900 - i,
          baroAlt: 1905 - i,
          elevation: 420,
        ),
    ];
    final last = pts.last;
    return <String, dynamic>{
      'tag': 'flightChunk',
      'flightId': flightUuid,
      'trackChunk': compressPoints(pts),
      'position': <String, dynamic>{
        ...last.toJson(),
        'speed': 12.0,
        'vspeed': -0.5,
        'landed': false,
      },
    };
  }

  int _msgSeq = 0;

  String pushMessage([String text = 'Landing at Coupe Icare?']) => jsonEncode(
        <String, dynamic>{
          'tag': 'message',
          'uuid': 'msg-${++_msgSeq}',
          'from': <String, dynamic>{
            'username': 'buddy',
            'fullname': 'Buddy',
            'login': 42,
            'flarmRadioId': 'DDAABB',
          },
          'srcGroup': null,
          'tstamp': utcToJson(DateTime.now()),
          'content': <String, dynamic>{'tag': 'TextMessage', 'text': text},
        },
      );
}
