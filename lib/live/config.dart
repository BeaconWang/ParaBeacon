/// Constants lifted from the APK.
///
/// config/t0.smali:5772-5812                     base URL
/// rest/apis/LivetrackApi$FlightOptions:163-166  protoVersion
/// live/c1.smali:79-84                           default flush period
/// live/c1.smali:6080-6156                       server interval clamp
/// j8/n.smali:687-722                            max points per chunk
/// live/c1.smali:434-477                         idle disconnect
/// live/c1.smali:6543-6579                       nearby-FLARM report period
/// live/i1.smali:1144-1371                       nearby-FLARM age-out
/// live/c1.smali:920-1215                        reconnect backoff
library;

const String kBaseUrl = 'https://live2.xcontest.org/api/';
const String kBaseUrlTest = 'https://live2.test.xcontest.org/api/';

/// Hardcoded in the APK (live/c1.smali:3784-3875, :3945) - see README.
const String kClientId = 'xctrack';
const String kClientHmacKey = 'WVSYYxF9hY7TX1Yqtv5n3AP04VmPlziK';

const int kProtoVersion = 4;

const int kDefaultFlushMs = 60000;
const int kMinServerIntervalS = 1;
const int kMaxServerIntervalS = 119;
const int kMaxChunkPoints = 1000;
const int kIdleDisconnectMs = 130000;

const int kNearbyFlarmPeriodMs = 180000;
const int kNearbyFlarmAgeMs = 300000;

const int kBackoffStartMs = 20000;
const int kBackoffGiveUpMs = 18000000; // 5 h
const int kReconnectFastMs = 2000;
const int kReconnectSlowMs = 20000;
const int kConnectionShortMs = 60000;

const List<int> kColourPool = <int>[
  0xFFE53935, 0xFF43A047, 0xFF1E88E5, 0xFFFDD835,
  0xFF8E24AA, 0xFF00ACC1, 0xFFF4511E, 0xFF3949AB,
];
const int kColourFallback = 0xFF808080;
