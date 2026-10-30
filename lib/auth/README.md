# Login + sharing (XCTrack protocol)

Dart implementation of XCTrack's login flow and of "share my live track".
Everything is transport-agnostic: `lib/net/http_transport.dart` is a tiny
interface, with a `package:http` adapter and an offline fake server.

```bash
dart run bin/share_demo.dart    # login -> share -> send fixes -> land
flutter test                    # 44 tests (23 protocol + 20 auth/share + 1 widget)
```

## The login protocol

Reverse engineered from `rest/s.smali` and `config/frags/s.smali`.

```
POST https://simple-auth.xcontest.org/oauth/token_noauth
Content-Type: application/x-www-form-urlencoded
User-Agent: XCTrack 0.9.12.6; Android: 13; bt: 1770217163

grant_type=password & clientid=xctrack & username=… & password=…
        │
        ▼
{ "access_token": "…", "uid": "…", "full_name": "…" }
        │
        ▼  stored as XContest.AuthToken / Sec.Xcontest.Uid
```

Note it is `clientid`, **not** `client_id`, and there is **no** `client_secret`
and **no** `scope` in the request (`rest/s.smali:3077`).

`User-Agent` is **not** optional: `rest/f.smali:11-35` builds
`XCTrack <ver>; Android: <release>; bt: <buildTime>` and `rest/e.smali` is an
OkHttp interceptor that stamps it on every request, auth included
(`rest/f.smali:434-447`). `DartHttpTransport` does the same
(`kXCTrackUserAgent`).

Validation has no expiry field — the token is checked by introspection:

```
POST https://simple-auth.xcontest.org/oauth/introspect
Authorization: Basic eGN0cmFjazp4Y3RyYWNr      # base64("xctrack:xctrack")

token=…
        ▼
{ "scope": "…", "username": "…" }     valid iff username == stored username
```

**There is no refresh token and no `expires_in`.** Renewal is simply re-running
the password grant (`config/frags/s.smali:304-430`).

| pref key | field | source |
|---|---|---|
| `XContest.Username` | username | `config/t0.smali:733` |
| `XContest.Password` | password | `config/t0.smali:750` |
| `XContest.AuthToken` | the bearer token | `config/t0.smali:767` |
| `Sec.Xcontest.Uid` | uid from the token response | `config/t0.smali:787` |

All four live in the SECURE preference group in the APK. Here the default
`MemoryCredentialsStore` keeps everything in process memory — **the password is
never written to disk**. `AuthClient(rememberPassword: true)` only makes sense
once `store` is backed by `flutter_secure_storage` / Keystore / Keychain.

### Error handling

| HTTP | behaviour |
|---|---|
| 401 | clear token+uid, `UnauthorizedException`; `AuthClient.withReauth` re-logins and retries once after 20 s (`live/c1.smali:4007-4015`, `:4296`) |
| 403 | `AuthResult.forbidden`, session cleared (`t0.W(null,null)`), "user must re-login" (`rest/s.smali:3282-3300`, `live/c1.smali:4339`) |
| other | `AuthResult.error("Bad response code: <code>")` (`rest/s.smali:3239-3278`) |

The UI text the APK shows for these is `liveLoginErrorMsgBadCredentials`
("Bad XContest username or password…") for 403 and `liveLoginErrorMsgGeneric`
for everything else (`config/frags/s.smali:598-619`).

## Enabling live sharing

Sharing is **not** a separate endpoint — it is a flag on the flight you declare:

```
POST https://live2.xcontest.org/api/flight
Authorization: Bearer <token>
client-id: xctrack
client-hmac: HMAC_SHA256(jsonBody, "WVSYYxF9hY7TX1Yqtv5n3AP04VmPlziK")
Content-Type: application/json

{
  "position": { "lat": 45.9, "lon": 6.86, "timestamp": "2026-06-13T09:00:00.000Z",
                "gpsAlt": 1210, "baroAlt": 0, "elevation": 490 },
  "device": { "deviceId": "…",
              "device": { "model": "…", "manufacturer": "…", "display": {…}, "memory": {…} },
              "os": { "sdk": 34, "type": "Android", "version": "14", "timezone": "GMT" },
              "app": { "name": "XCTrack", "versionName": "…", "versionCode": 1 } },
  "glider": "…", "gliderCat": "FAI-3",
  "tandem": false, "simulation": false,
  "public": true, "faiCompliant": true,
  "protoVersion": 4
}
```

Three details the server is picky about (a wrong one is a 400):

* `device` is `TracklogWriter$IGCSystemInfo` — nested objects, **not** a flat
  `{manufacturer, model, …}` string map (`lib/live/system_info.dart`).
* the position field is `timestamp` with **milliseconds**
  (`yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`, `util/UTCTimeAdapter`); `tstamp` only exists
  on `LiveProto$XCSendMessage`.
* `flarmRadioId` is nullable and Gson omits nulls, so it must be absent rather
  than `null`.
* `gliderCat` is XContest's category id built by `t0.D()`
  (`config/t0.smali:10405-10730`) from pref `Glider.FAIClass` — `FAI-3`,
  **not** the `EN-C` certification shown in the UI. Anything else is
  `400 … Error in $.gliderCat: Failed reading: takeWhile1`. See
  `lib/live/glider.dart`.

`"public"` comes from `FlightOptions.flpublic`
(`rest/apis/LivetrackApi$FlightOptions.smali:80-84`), fed by pref
`Livetrack.FlightPublic`. The response `{ "uri": … }` is the WebSocket
endpoint; positions then flow as `xcSendChunkHP` frames (see `lib/live/README.md`).

**The socket needs the bearer token too** — the upgrade is authorized, not just
the REST calls: `c1.s()` adds `Authorization: Bearer <XContest.AuthToken>`
(`live/c1.smali:7412-7446`, `td/u.smali:305`). Without it the server answers
`401 Unauthorized` instead of `101`, which surfaces as
`… was not upgraded to websocket`. (The browser WebSocket API cannot set
headers at all, so only the native transport does this — `lib/live/ws_connect*.dart`.)

Switches, 1:1 with the APK preferences:

| switch | pref | effect |
|---|---|---|
| Share my position | `Livetrack.Enabled` | master switch; creates the flight + opens the socket |
| Flight is public | `Livetrack.FlightPublic` | `"public": true` — this is what publishes |
| Temporarily stop sharing | `Internal.LiveTempDontShare` | gates every fix, even while flying |
| Claim to XContest | `Livetrack.ClaimContest` | sent in `XCLanding` |

`POST group/{uuid}/enable|disable` is a **different** feature (following other
pilots), not flight sharing — `LivetrackApi.smali:115,200`.

## Files

```
lib/net/http_transport.dart       interface + 401/other exceptions
lib/net/dart_http_transport.dart  package:http adapter (real network)
lib/net/fake_transport.dart       offline auth + livetrack server
lib/auth/auth_config.dart         URLs, clientid, pref keys
lib/auth/auth_models.dart         TokenResponse / IntrospectResponse / AuthResult
lib/auth/credentials_store.dart   where credentials live (memory by default)
lib/auth/auth_client.dart         login / introspect / ensureLoggedIn / withReauth
lib/live/livetrack_api.dart       POST flight, GET flight/active, group enable
lib/share/live_share_controller.dart  wires auth + sharing + the sender
lib/ui/live_share_page.dart       login form + the four switches + status
```

## Running against the real servers

`kOfflineDemo = false` in `lib/main.dart` (the default). That swaps
`FakeTransport` → `DartHttpTransport`, creates `LivetrackApi` instead of the
mock peer, and `enableSharing` opens a real `WebSocketWire` on the `uri` that
`POST /flight` returns (`live/c1.smali:7084-7110`). A real XContest account is
required; the login fields start empty instead of pre-filled with the demo
account. Android needs `android.permission.INTERNET` (added to
`android/app/src/main/AndroidManifest.xml`).

`LiveShareController.attachWire(LiveWire)` remains the hook for plugging in a
different transport; `Wire` (offline) and `WebSocketWire` (real) both implement
the `LiveWire` interface.
