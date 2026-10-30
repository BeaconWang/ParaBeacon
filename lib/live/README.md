# Live-tracking logic (XCTrack, reverse engineered)

A Dart re-implementation of XCTrack's live-tracking pipeline, reconstructed
from the decompiled APK. Pure Dart — no plugins, no network, no pub packages.

```bash
dart run bin/demo.dart              # full 20-minute flight, end to end
flutter test test/live_logic_test.dart   # 23 unit tests
```

The scenario runs on a virtual clock, so it is deterministic. The "WebSocket"
is an in-memory pair of queues (`wire.dart`) carrying exactly the same UTF-8
JSON text frames okhttp would.

## Class map (smali → here)

| APK class (smali_classes3/org/xcontest/XCTrack/…) | here |
|---|---|
| `live/LiveTrackpoint`, `live/LiveTrackpointHP` | `trackpoint.dart` |
| `util/y.f` / `util/y.c` (polyline varint) | `codec.dart` |
| `live/LiveCompressAdapter` | `codec.dart` |
| `util/UTCTimeAdapter` | `timeutil.dart` |
| `live/LiveProto$*`, `live/LiveDeserializer` | `proto.dart` |
| `live/i1` (singleton `info/t.H0`) | `live_manager.dart` |
| `live/c1` (WS engine) + `live/r0` (sender) | `live_client.dart` |
| `config/t0`, `rest/apis/LivetrackApi` | `config.dart` |
| `live2.xcontest.org` | `mock_server.dart` |
| okhttp WebSocket | `wire.dart` |

`sha256.dart` is a dependency-free SHA-256/HMAC — it exists only so the
`client-hmac` header can be reproduced without adding `package:crypto`.

## The pipeline

```
GPS fix (org/xcontest/XCTrack/j)
  │  info/t.b(fix) → r0.e(fix)                        info/t.smali:4745,4803
  ▼
c1.h(loc) ── validity gate c1.m(loc) ──► drop dup / out-of-order fixes
  │                                                     c1.smali:2496-2591
  ▼
queue: Queue<LiveTrackpointHP>                          c1.w
  │  flush every sendIntervalMs (60 s default; server may retune 1..119 s)
  ▼
batch = first min(len, 1000) points                     j8/n.smali:687-722
  ▼
XCSendChunkHP{ tag, pointsHP, addInfo }
  │  pointsHP: int[6] → reverse delta → polyline string  LiveCompressAdapter
  ▼
jsonEncode → UTF-8 bytes → WebSocket text frame         c1.smali:7084-7110
  ▼
server "ackChunk" → purge acked points, re-arm flush    c1.smali:4987-5561
```

Downlink is symmetric: `c1.d(ws,text)` → `LiveDeserializer` (dispatch on `tag`)
→ `c1.l(frame)` → `i1` state → UI via EventBus (not LiveData).

## Wire frames

Client → server: `xcSendChunkHP`, `xcSetOptions`, `xcFollow`, `xcLanding`,
`xcSendMessage`, `xcMsgAck`, `xcNearbyFlarms`, `xcGetMessageStatus`.

Server → client: `ackChunk`, `landingAck`, `flightInfos`, `flightPositions`,
`flightChunk`, `message`, `ackMsg`, `ackMsgSvr`, `serverInfo`, `error`,
`flightTerminated`. Unknown tags become `SvrUnknownFrame` and are only logged.

## Constants

| constant | value | source |
|---|---|---|
| base URL | `https://live2.xcontest.org/api/` | `config/t0.smali:5772-5812` |
| `protoVersion` | 4 | `LivetrackApi$FlightOptions.smali:163-166` |
| default flush period | 60 000 ms | `live/c1.smali:79-84` |
| server interval clamp | 1…119 s | `live/c1.smali:6080-6156` |
| max points per chunk | 1000 | `j8/n.smali:687-722` |
| idle disconnect | 130 000 ms | `live/c1.smali:434-477` |
| nearby-FLARM report | every 3 min | `live/c1.smali:6543-6579` |
| nearby-FLARM age-out | 300 000 ms | `live/i1.smali:1144-1371` |
| reconnect backoff | 20 s ×2 up to 5 h (landed); 2 s / 20 s (flying) | `live/c1.smali:920-1215` |
| coordinate quantisation | 1/60000° (base), 1/600000° (HP) | `LiveTrackpoint*.smali` |

Measured on the demo flight (241 fixes): **≈35 bytes per fix** on the wire,
about 4.8× smaller than shipping the raw `int[6]` array as JSON.

## Security note

`live/c1.smali:3784-3875` hardcodes the request-signing secret
`WVSYYxF9hY7TX1Yqtv5n3AP04VmPlziK` (with `client-id: xctrack`) inside the APK.
Anyone can extract it and mint valid `POST /api/flight` requests, so it must be
treated as public — server-side trust should not rest on it.

## Known approximations

* Flight identifiers are plain strings here; the APK uses `java.util.UUID`.
* `MemInfo` mirrors `ActivityManager.MemoryInfo` from what Gson would emit
  (`availMem`/`totalMem`/`threshold`/`lowMemory`); not verified against a real
  device.
* `LiveCompressAdapter.read` builds the base `LiveTrackpoint` even for HP lists
  (1e5 vs 1e6 scaling) — reproduced as-is; worth checking against a real frame.
* `LiveScore` distance accumulation and the task/optimiser integration are
  stubbed; only transport and state machine are modelled.
