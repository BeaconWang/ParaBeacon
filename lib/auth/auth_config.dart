/// Auth endpoints and preference keys, lifted from the APK.
///
/// rest/s.smali:294,302            auth base URL (chosen by "Devel.OAuthAPIDev")
/// rest/s.smali:3056-3162          the token_noauth field map
/// rest/s.smali:404                the hard-coded introspect Basic header
/// config/t0.smali:733,750,767,787 preference keys
library;

/// Production auth server. Note this is a *different* host from the
/// livetrack API (`https://live2.xcontest.org/api/`).
const String kAuthBaseUrl = 'https://simple-auth.xcontest.org/oauth/';

/// Selected when pref "Devel.OAuthAPIDev" is true (config/t0.smali:4594).
const String kAuthBaseUrlTest = 'https://simple-auth.test.xcontest.org/oauth/';

const String kAuthPathToken = 'token_noauth';
const String kAuthPathIntrospect = 'introspect';

/// Sent as `clientid` - note: **not** `client_id`, and there is no
/// `client_secret` and no `scope` in the request (rest/s.smali:3077).
const String kOAuthClientId = 'xctrack';

/// base64("xctrack:xctrack") - hard-coded in rest/s.smali:404.
const String kIntrospectBasicHeader = 'Basic eGN0cmFjazp4Y3RyYWNr';

/// Preference keys (group SECURE in the APK - config/n2.smali:65-77).
const String kPrefUsername = 'XContest.Username';
const String kPrefPassword = 'XContest.Password';
const String kPrefAuthToken = 'XContest.AuthToken';
const String kPrefUid = 'Sec.Xcontest.Uid';

/// OkHttp timeouts on the auth client (rest/s.smali:37-41).
const Duration kAuthTimeout = Duration(seconds: 20);

/// live/c1.smali:4264 - after a 401 the app re-authenticates and retries.
const Duration kReauthRetryDelay = Duration(seconds: 20);
