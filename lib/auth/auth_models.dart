/// Auth payloads, mirroring AuthLoginApi$TokenResponse / $IntrospectResponse.
library;

/// rest/apis/g.smali is the sealed base; apis/d=ERROR, apis/e=FORBIDDEN,
/// apis/f=OK(fullName)  (rest/apis/d.smali:66, e.smali:66, f.smali:89).
enum AuthStatus { ok, forbidden, error }

/// `AuthLoginApi$TokenResponse`: access_token, uid, full_name.
/// There is no refresh_token and no expires_in in the protocol.
class TokenResponse {
  final String accessToken;
  final String uid;
  final String? fullName;

  const TokenResponse({
    required this.accessToken,
    required this.uid,
    this.fullName,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> m) => TokenResponse(
        accessToken: m['access_token'] as String? ?? '',
        uid: m['uid'] as String? ?? '',
        fullName: m['full_name'] as String?,
      );

  @override
  String toString() =>
      'TokenResponse(access_token=$accessToken, uid=$uid, full_name=$fullName)';
}

/// `AuthLoginApi$IntrospectResponse`: scope, username.
class IntrospectResponse {
  final String scope;
  final String username;

  const IntrospectResponse({required this.scope, required this.username});

  factory IntrospectResponse.fromJson(Map<String, dynamic> m) =>
      IntrospectResponse(
        scope: m['scope'] as String? ?? '',
        username: m['username'] as String? ?? '',
      );
}

/// Outcome of a login / session check.
class AuthResult {
  final AuthStatus status;
  final String? token;
  final String? uid;
  final String? fullName;
  final String? message;

  const AuthResult({
    required this.status,
    this.token,
    this.uid,
    this.fullName,
    this.message,
  });

  bool get isOk => status == AuthStatus.ok;

  factory AuthResult.ok({required String token, String? uid, String? fullName}) =>
      AuthResult(
        status: AuthStatus.ok,
        token: token,
        uid: uid,
        fullName: fullName,
      );

  factory AuthResult.forbidden([String? message]) =>
      AuthResult(status: AuthStatus.forbidden, message: message);

  factory AuthResult.error(String message) =>
      AuthResult(status: AuthStatus.error, message: message);

  @override
  String toString() => 'AuthResult(${status.name}, ${message ?? fullName ?? token})';
}

/// The signed-in session held in memory.
class AuthSession {
  final String username;
  final String token;
  final String uid;
  final String? fullName;

  const AuthSession({
    required this.username,
    required this.token,
    required this.uid,
    this.fullName,
  });

  /// Every REST call in the APK builds this by concatenating "Bearer " with
  /// the stored token (live/c1.smali:3719, live/p1.smali:137, rest/s.smali:852).
  String get authHeader => 'Bearer $token';

  bool get hasToken => token.isNotEmpty;
}
