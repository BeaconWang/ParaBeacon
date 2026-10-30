/// Login / session handling - the Dart equivalent of `rest/s.smali`.
///
/// Protocol (reverse engineered):
///   POST {authBase}token_noauth   form: grant_type=password,
///                                       clientid=xctrack,
///                                       username, password
///        -> { access_token, uid, full_name }
///   POST {authBase}introspect     form: token=TOKEN
///        header: Authorization: Basic eGN0cmFjazp4Y3RyYWNr
///        -> { scope, username }   valid iff username == stored username
///
/// There is **no refresh_token and no expiry** in this protocol: renewal is
/// simply re-running the password grant (config/frags/s.smali:304-430).
library;

import 'dart:async';
import 'dart:convert';

import '../net/http_transport.dart';
import 'auth_config.dart';
import 'auth_models.dart';
import 'credentials_store.dart';

typedef Sleeper = Future<void> Function(Duration d);

class AuthClient {
  final HttpTransport transport;
  final CredentialsStore store;
  final String baseUrl;

  /// live/c1.smali:4264 - wait this long after a successful re-auth.
  final Duration reauthRetryDelay;

  /// Injectable so tests do not really sleep.
  final Sleeper _sleep;

  /// Keeps the password so a silent re-login is possible. Off by default:
  /// only turn it on when [store] is backed by a secure store.
  final bool rememberPassword;

  AuthClient({
    required this.transport,
    CredentialsStore? store,
    this.baseUrl = kAuthBaseUrl,
    this.reauthRetryDelay = kReauthRetryDelay,
    this.rememberPassword = false,
    Sleeper? sleep,
  })  : store = store ?? MemoryCredentialsStore(),
        _sleep = sleep ?? ((d) => Future<void>.delayed(d));

  AuthSession? _session;

  AuthSession? get session => _session;

  bool get isLoggedIn => _session?.hasToken ?? false;

  /// Last request/response pair - handy for debugging and for the demo log.
  Map<String, dynamic> lastExchange = <String, dynamic>{};

  // ---------------------------------------------------------------------
  // login
  // ---------------------------------------------------------------------
  /// The password grant. Credentials default to what is in the store.
  Future<AuthResult> login({String? username, String? password}) async {
    final user = username ?? (await store.username) ?? '';
    final pass = password ?? (await store.password) ?? '';
    if (user.isEmpty || pass.isEmpty) {
      return AuthResult.error('Missing username or password');
    }

    final request = HttpRequest(
      method: 'POST',
      uri: Uri.parse('$baseUrl$kAuthPathToken'),
      form: <String, String>{
        'grant_type': 'password',
        'clientid': kOAuthClientId,
        'username': user,
        'password': pass,
      },
    );

    final res = await transport.send(request);
    lastExchange = <String, dynamic>{'request': request, 'response': res};

    if (res.isForbidden) {
      // rest/s.smali:3282-3300 - 403 clears token+uid (t0.W(null,null)) and
      // becomes FORBIDDEN, which the UI shows as "Bad XContest username or
      // password" (res/values/strings.xml liveLoginErrorMsgBadCredentials).
      await _clearSession();
      return AuthResult.forbidden(
          'Bad credentials (403 from ${request.uri.host})');
    }
    if (!res.isOk) {
      // rest/s.smali:3239-3278 - any other code is ERROR, logged there as
      // "Bad response code: <code>".
      return AuthResult.error('Bad response code: ${res.statusCode}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      return AuthResult.error('Malformed token response');
    }

    final token = TokenResponse.fromJson(body);
    if (token.accessToken.isEmpty) {
      return AuthResult.error('Empty access_token');
    }

    await store.setUsername(user);
    if (rememberPassword) {
      await store.setPassword(pass);
    } else {
      await store.setPassword(null);
    }
    await store.saveSession(token.accessToken, token.uid); // config/t0.W

    _session = AuthSession(
      username: user,
      token: token.accessToken,
      uid: token.uid,
      fullName: token.fullName,
    );
    return AuthResult.ok(
      token: token.accessToken,
      uid: token.uid,
      fullName: token.fullName,
    );
  }

  // ---------------------------------------------------------------------
  // introspect
  // ---------------------------------------------------------------------
  /// rest/s.smali:74-556 (`rest/s.a`) - the introspect check.
  ///
  /// The APK never looks at the HTTP code: it reads `Response.body()`, which
  /// Retrofit only fills for 2xx, so a 401/403 yields a null body and the check
  /// fails. Same result here. A missing token short-circuits the same way
  /// (rest/s.smali:357-373).
  Future<IntrospectResponse?> introspect([String? token]) async {
    final t = token ?? await store.token ?? _session?.token ?? '';
    if (t.isEmpty) return null;

    final request = HttpRequest(
      method: 'POST',
      uri: Uri.parse('$baseUrl$kAuthPathIntrospect'),
      headers: <String, String>{'Authorization': kIntrospectBasicHeader},
      form: <String, String>{'token': t},
    );
    final res = await transport.send(request);
    lastExchange = <String, dynamic>{'request': request, 'response': res};
    if (!res.isOk) return null;

    try {
      return IntrospectResponse.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// rest/s.smali:461-539 - valid iff `IntrospectResponse.username` equals the
  /// stored `XContest.Username` (t0.p0). "Login check OK" / "Login check
  /// failed, will try to re-login".
  Future<bool> isTokenValid() async {
    final info = await introspect();
    if (info == null) return false;
    final user = await store.username ?? _session?.username ?? '';
    return info.username.isNotEmpty && info.username == user;
  }

  // ---------------------------------------------------------------------
  // ensureLoggedIn / logout
  // ---------------------------------------------------------------------
  /// config/frags/s.smali:304-430 - introspect first, fall back to login.
  Future<AuthResult> ensureLoggedIn() async {
    if (await isTokenValid()) {
      final token = await store.token ?? '';
      final uid = await store.uid ?? '';
      _session ??= AuthSession(username: await store.username ?? '', token: token, uid: uid);
      return AuthResult.ok(token: token, uid: uid, fullName: _session?.fullName);
    }
    return login();
  }

  Future<void> logout() async {
    await _clearSession();
    await store.setUsername(null);
    await store.setPassword(null);
    _session = null;
  }

  Future<void> _clearSession() async {
    await store.saveSession(null, null);
    _session = null;
  }

  // ---------------------------------------------------------------------
  // retry wrapper for authenticated calls
  // ---------------------------------------------------------------------
  /// Runs [op] with a valid session. On 401 it re-authenticates and retries
  /// once after [reauthRetryDelay] (live/c1.smali:4007-4015, :4296).
  Future<T> withReauth<T>(Future<T> Function(AuthSession session) op) async {
    var result = await ensureLoggedIn();
    if (!result.isOk) {
      throw StateError('Not logged in: ${result.message ?? result.status.name}');
    }

    try {
      return await op(_session!);
    } on UnauthorizedException {
      result = await login();
      if (!result.isOk) rethrow;
      await _sleep(reauthRetryDelay);
      return op(_session!);
    }
  }
}
