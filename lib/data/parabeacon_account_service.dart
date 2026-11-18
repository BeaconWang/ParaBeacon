import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'live_tracking_proxy_auth_service.dart';
import 'parabeacon_server_config.dart';
import 'user_agent_settings.dart';

abstract interface class AccountSessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class ParaBeaconUser {
  const ParaBeaconUser({
    required this.id,
    required this.username,
    this.email,
    this.createdAt,
  });

  final String id;
  final String username;
  final String? email;
  final DateTime? createdAt;

  static ParaBeaconUser? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id'];
    final username = value['username'];
    if (id is! String ||
        id.isEmpty ||
        username is! String ||
        username.isEmpty) {
      return null;
    }
    final email = value['email'];
    final createdAtValue = value['created_at'];
    return ParaBeaconUser(
      id: id,
      username: username,
      email: email is String && email.isNotEmpty ? email : null,
      createdAt: createdAtValue is String
          ? DateTime.tryParse(createdAtValue)
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    if (email != null) 'email': email,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };
}

class ParaBeaconAccountService extends ChangeNotifier
    implements LiveTrackingProxyAuthProvider {
  ParaBeaconAccountService({
    http.Client? client,
    AccountSessionStore? sessionStore,
  }) : _client = UserAgentHttpClient(innerClient: client),
       _store = sessionStore ?? _SecureAccountSessionStore();

  static final ParaBeaconAccountService instance = ParaBeaconAccountService();

  static const _tokenStorageKey = 'parabeacon_access_token';
  static const _expiresAtStorageKey = 'parabeacon_access_token_expires_at';
  static const _refreshTokenStorageKey = 'parabeacon_refresh_token';
  static const _refreshExpiresAtStorageKey =
      'parabeacon_refresh_token_expires_at';
  static const _userStorageKey = 'parabeacon_account_user';
  static const _requestTimeout = Duration(seconds: 15);
  static const _maxDebugLogLines = 200;

  final List<String> _debugLog = <String>[];
  final http.Client _client;
  final AccountSessionStore _store;
  Uri _serverApiBaseUri = ParaBeaconServerConfig.apiV1BaseUri;

  String get _tokenKey => _sessionStorageKey(_tokenStorageKey);
  String get _expiresAtKey => _sessionStorageKey(_expiresAtStorageKey);
  String get _refreshTokenKey => _sessionStorageKey(_refreshTokenStorageKey);
  String get _refreshExpiresAtKey =>
      _sessionStorageKey(_refreshExpiresAtStorageKey);
  String get _userKey => _sessionStorageKey(_userStorageKey);

  String _sessionStorageKey(String key) {
    if (_serverApiBaseUri == ParaBeaconServerConfig.defaultApiV1BaseUri) {
      return key;
    }
    final origin = _serverApiBaseUri.replace(path: '/').toString();
    final suffix = base64Url.encode(utf8.encode(origin)).replaceAll('=', '');
    return '${key}_$suffix';
  }

  bool _loaded = false;
  bool _loading = false;
  String? _token;
  DateTime? _expiresAt;
  String? _refreshToken;
  Future<void>? _refreshFuture;
  bool _loggingOut = false;
  ParaBeaconUser? _user;
  String? _errorCode;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  bool get isBusy => _loading || _refreshFuture != null;

  List<String> get debugLog => List<String>.unmodifiable(_debugLog);
  bool get isSignedIn =>
      _token != null &&
      _token!.isNotEmpty &&
      (_expiresAt == null || _expiresAt!.isAfter(DateTime.now()));
  ParaBeaconUser? get user => _user;
  String? get errorCode => _errorCode;
  bool get _canRefresh => _refreshToken?.isNotEmpty == true;
  bool get _needsAccessRefresh =>
      _expiresAt == null ||
      !_expiresAt!.isAfter(DateTime.now().add(const Duration(minutes: 2)));

  Future<void> load() async {
    if (_loaded || _loading) return;
    _log('Session restore started.');
    _loading = true;
    _errorCode = null;
    notifyListeners();
    try {
      _token = await _store.read(_tokenKey);
      final expiresAtValue = await _store.read(_expiresAtKey);
      _expiresAt = expiresAtValue == null
          ? null
          : DateTime.tryParse(expiresAtValue);
      _refreshToken = await _store.read(_refreshTokenKey);
      _user = _decodeStoredUser(await _store.read(_userKey));

      if (_canRefresh && _needsAccessRefresh) {
        try {
          await _refreshAccessToken();
        } on TimeoutException {
          _errorCode = 'accountConnectionFailure';
        } on Exception {
          _errorCode ??= 'accountServiceUnavailable';
        }
      }
      if (isSignedIn) {
        _log('Saved session found; refreshing profile.');
        await _refreshProfile();
      } else if (!_canRefresh) {
        _log('No valid saved session; clearing local session data.');
        await _clearStoredSession();
        _token = null;
        _expiresAt = null;
        _refreshToken = null;
        _user = null;
      }
    } on Exception {
      _errorCode = 'accountStorageFailure';
      _log('Session restore failed (secure storage).');
    } finally {
      _loaded = true;
      _loading = false;
      _log(isSignedIn ? 'Session restore complete.' : 'No active session.');
      notifyListeners();
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    final normalizedIdentifier = identifier.trim();
    if (normalizedIdentifier.isEmpty ||
        normalizedIdentifier.length > 254 ||
        password.isEmpty ||
        utf8.encode(password).length > 72) {
      _setError('accountInvalidInput');
      return false;
    }
    if (_loading) return false;

    _log('Sign-in requested.');
    _beginRequest();
    try {
      return await _performLogin(normalizedIdentifier, password);
    } on TimeoutException {
      _errorCode = 'accountConnectionFailure';
      _log('Sign-in request timed out.');
      return false;
    } on Exception {
      _errorCode = 'accountServiceUnavailable';
      _log('Sign-in request failed due to a network or service error.');
      return false;
    } finally {
      _endRequest();
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedEmail = email.trim();
    final usernameLength = normalizedUsername.runes.length;
    if (usernameLength < 3 ||
        usernameLength > 32 ||
        (normalizedEmail.isNotEmpty && !_looksLikeEmail(normalizedEmail)) ||
        (normalizedEmail.length > 254) ||
        utf8.encode(password).length > 72 ||
        password.runes.length < 6) {
      _setError('accountInvalidInput');
      return false;
    }
    if (_loading) return false;

    _log('Registration requested.');
    _beginRequest();
    try {
      final payload = <String, String>{
        'username': normalizedUsername,
        'password': password,
        if (normalizedEmail.isNotEmpty) 'email': normalizedEmail,
      };
      final response = await _client
          .post(
            _apiUri('auth/register'),
            headers: _jsonHeaders,
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);
      _log('Registration response received (HTTP ${response.statusCode}).');

      if (response.statusCode == 409) {
        _errorCode = 'accountAlreadyExists';
        return false;
      }
      if (response.statusCode == 400) {
        _errorCode = 'accountInvalidInput';
        return false;
      }
      if (response.statusCode != 201) {
        _errorCode = response.statusCode >= 500
            ? 'accountServiceUnavailable'
            : 'accountRequestFailed';
        return false;
      }

      return await _performLogin(normalizedUsername, password);
    } on TimeoutException {
      _errorCode = 'accountConnectionFailure';
      _log('Registration request timed out.');
      return false;
    } on Exception {
      _errorCode = 'accountServiceUnavailable';
      _log('Registration request failed due to a network or service error.');
      return false;
    } finally {
      _endRequest();
    }
  }

  Future<void> logout() async {
    if (_loading || _loggingOut) return;
    _loggingOut = true;
    _loading = true;
    _log('Sign-out requested.');
    notifyListeners();
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) {
      try {
        await activeRefresh;
      } on Exception {
        // Continue with local sign-out if refresh failed.
      }
    }
    final refreshToken = _refreshToken;
    _token = null;
    _expiresAt = null;
    _refreshToken = null;
    _user = null;
    _errorCode = null;
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _client
            .post(
              _apiUri('auth/logout'),
              headers: _jsonHeaders,
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 3));
      }
    } on Exception {
      _log('Remote refresh-token revocation failed; local session cleared.');
    }
    try {
      await _clearStoredSession();
    } on Exception {
      _errorCode = 'accountStorageFailure';
      _log('Sign-out failed to clear the saved session.');
    }
    _loaded = true;
    _loading = false;
    _log('Sign-out complete.');
    notifyListeners();
  }

  @override
  Future<Map<String, String>> authorizationHeaders() async {
    if (_loggingOut) {
      throw const LiveTrackingProxyAuthException('account_signing_out');
    }
    await load();
    if (_loggingOut) {
      throw const LiveTrackingProxyAuthException('account_signing_out');
    }
    if (_canRefresh && _needsAccessRefresh) {
      await _refreshAccessToken();
    }
    final token = _token;
    if (!isSignedIn || token == null || token.isEmpty) {
      throw const LiveTrackingProxyAuthException('parabeacon_account_required');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void clearError() {
    if (_errorCode == null) return;
    _errorCode = null;
    notifyListeners();
  }

  Future<bool> _performLogin(String identifier, String password) async {
    final response = await _client
        .post(
          _apiUri('auth/login'),
          headers: _jsonHeaders,
          body: jsonEncode({'identifier': identifier, 'password': password}),
        )
        .timeout(_requestTimeout);
    _log('Sign-in response received (HTTP ${response.statusCode}).');

    if (response.statusCode == 401) {
      _errorCode = 'accountInvalidCredentials';
      return false;
    }
    if (response.statusCode == 400) {
      _errorCode = 'accountInvalidInput';
      return false;
    }
    if (response.statusCode != 200) {
      _errorCode = response.statusCode >= 500
          ? 'accountServiceUnavailable'
          : 'accountRequestFailed';
      return false;
    }

    final decoded = _decodeMap(response.body);
    final token = decoded?['access_token'];
    final user = ParaBeaconUser.fromJson(decoded?['user']);
    if (token is! String || token.isEmpty || user == null) {
      _errorCode = 'accountRequestFailed';
      return false;
    }

    final expiresAt = _parseExpiry(decoded!);
    final refreshTokenValue = decoded['refresh_token'];
    final refreshExpiresAtValue = decoded['refresh_expires_at'];
    final refreshExpiresAt = refreshExpiresAtValue is String
        ? DateTime.tryParse(refreshExpiresAtValue)
        : null;
    if ((refreshTokenValue != null && refreshTokenValue is! String) ||
        (refreshTokenValue is String &&
            (refreshTokenValue.isEmpty ||
                (refreshExpiresAtValue != null && refreshExpiresAt == null)))) {
      _errorCode = 'accountRequestFailed';
      return false;
    }
    final refreshToken = refreshTokenValue as String?;
    try {
      await _store.write(_tokenKey, token);
      if (expiresAt == null) {
        await _store.delete(_expiresAtKey);
      } else {
        await _store.write(_expiresAtKey, expiresAt.toIso8601String());
      }
      if (refreshToken == null) {
        await _store.delete(_refreshTokenKey);
        await _store.delete(_refreshExpiresAtKey);
      } else {
        await _store.write(_refreshTokenKey, refreshToken);
        if (refreshExpiresAt == null) {
          await _store.delete(_refreshExpiresAtKey);
        } else {
          await _store.write(
            _refreshExpiresAtKey,
            refreshExpiresAt.toIso8601String(),
          );
        }
      }
      await _store.write(_userKey, jsonEncode(user.toJson()));
    } on Exception {
      try {
        await _clearStoredSession();
      } on Exception {
        // Keep the session signed out even if secure-store cleanup also fails.
      }
      _errorCode = 'accountStorageFailure';
      _log('Sign-in succeeded remotely but secure session storage failed.');
      return false;
    }

    _token = token;
    _expiresAt = expiresAt;
    _refreshToken = refreshToken;
    _user = user;
    _errorCode = null;
    _log('Sign-in succeeded; session stored securely.');
    return true;
  }

  Future<void> _refreshAccessToken() {
    final current = _refreshFuture;
    if (current != null) return current;
    final task = _refreshAccessTokenOnce();
    _refreshFuture = task;
    return task.whenComplete(() {
      if (identical(_refreshFuture, task)) _refreshFuture = null;
    });
  }

  Future<void> _refreshAccessTokenOnce() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const LiveTrackingProxyAuthException('account_refresh_required');
    }
    final response = await _client
        .post(
          _apiUri('auth/refresh'),
          headers: _jsonHeaders,
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(_requestTimeout);
    _log(
      'Access-token refresh response received (HTTP ${response.statusCode}).',
    );
    if (response.statusCode == 400 || response.statusCode == 401) {
      _token = null;
      _expiresAt = null;
      _refreshToken = null;
      _user = null;
      _errorCode = 'accountRequestFailed';
      try {
        await _clearStoredSession();
      } on Exception {
        // Keep the in-memory session signed out if secure-store cleanup fails.
      }
      notifyListeners();
      throw const LiveTrackingProxyAuthException('account_session_expired');
    }
    if (response.statusCode != 200) {
      throw LiveTrackingProxyAuthException(
        'account_refresh_http_${response.statusCode}',
      );
    }
    final decoded = _decodeMap(response.body);
    final accessToken = decoded?['access_token'];
    final nextRefreshToken = decoded?['refresh_token'];
    final expiresAt = decoded == null ? null : _parseExpiry(decoded);
    final refreshExpiresAtValue = decoded?['refresh_expires_at'];
    final refreshExpiresAt = refreshExpiresAtValue is String
        ? DateTime.tryParse(refreshExpiresAtValue)
        : null;
    if (accessToken is! String ||
        accessToken.isEmpty ||
        nextRefreshToken is! String ||
        nextRefreshToken.isEmpty ||
        expiresAt == null ||
        (refreshExpiresAtValue != null &&
            (refreshExpiresAtValue is! String || refreshExpiresAt == null))) {
      throw const LiveTrackingProxyAuthException(
        'account_refresh_invalid_response',
      );
    }

    _token = accessToken;
    _expiresAt = expiresAt;
    _refreshToken = nextRefreshToken;
    _errorCode = null;
    try {
      await _store.write(_tokenKey, accessToken);
      await _store.write(_expiresAtKey, expiresAt.toIso8601String());
      await _store.write(_refreshTokenKey, nextRefreshToken);
      if (refreshExpiresAt == null) {
        await _store.delete(_refreshExpiresAtKey);
      } else {
        await _store.write(
          _refreshExpiresAtKey,
          refreshExpiresAt.toIso8601String(),
        );
      }
    } on Exception {
      _errorCode = 'accountStorageFailure';
    }
    _log('Access token refreshed and refresh token rotated.');
    notifyListeners();
  }

  Future<void> _refreshProfile() async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            _apiUri('user/profile'),
            headers: {..._jsonHeaders, 'Authorization': 'Bearer $_token'},
          )
          .timeout(_requestTimeout);
      _log('Profile response received (HTTP ${response.statusCode}).');
    } on TimeoutException {
      _errorCode = 'accountConnectionFailure';
      _log('Profile refresh timed out.');
      return;
    } on http.ClientException {
      _errorCode = 'accountConnectionFailure';
      _log('Profile refresh failed due to a connection error.');
      return;
    } on Exception {
      _errorCode = 'accountServiceUnavailable';
      _log('Profile refresh failed due to a service error.');
      return;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _log('Saved session was rejected; clearing it locally.');
      await _clearStoredSession();
      _token = null;
      _expiresAt = null;
      _refreshToken = null;
      _user = null;
      return;
    }
    if (response.statusCode != 200) {
      _errorCode = response.statusCode >= 500
          ? 'accountServiceUnavailable'
          : 'accountRequestFailed';
      _log('Profile refresh failed (HTTP ${response.statusCode}).');
      return;
    }

    final user = ParaBeaconUser.fromJson(_decodeMap(response.body)?['user']);
    if (user == null) {
      _errorCode = 'accountRequestFailed';
      _log('Profile response was invalid.');
      return;
    }
    _user = user;
    try {
      await _store.write(_userKey, jsonEncode(user.toJson()));
      _log('Profile refreshed and saved locally.');
    } on Exception {
      _errorCode = 'accountStorageFailure';
      _log('Profile refreshed but secure profile storage failed.');
    }
  }

  Future<void> _clearStoredSession() async {
    for (final key in [
      _tokenKey,
      _expiresAtKey,
      _refreshTokenKey,
      _refreshExpiresAtKey,
      _userKey,
    ]) {
      await _store.delete(key);
    }
  }

  void _log(String message) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${now.millisecond.toString().padLeft(3, '0')}';
    final line = '$stamp  $message';
    _debugLog.add(line);
    if (_debugLog.length > _maxDebugLogLines) {
      _debugLog.removeRange(0, _debugLog.length - _maxDebugLogLines);
    }
    debugPrint('ParaBeaconAccount: $line');
    notifyListeners();
  }

  void _beginRequest() {
    _loggingOut = false;
    _loading = true;
    _errorCode = null;
    notifyListeners();
  }

  void _endRequest() {
    _loaded = true;
    _loading = false;
    notifyListeners();
  }

  void _setError(String code) {
    _errorCode = code;
    notifyListeners();
  }

  Uri _apiUri(String path) => _serverApiBaseUri.resolve(path);

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  static DateTime? _parseExpiry(Map<String, dynamic> value) {
    final expiresAt = value['expires_at'];
    if (expiresAt is String) {
      final parsed = DateTime.tryParse(expiresAt);
      if (parsed != null) return parsed;
    }
    final expiresIn = value['expires_in'];
    if (expiresIn is num && expiresIn > 0) {
      return DateTime.now().add(Duration(seconds: expiresIn.floor()));
    }
    return null;
  }

  static Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static ParaBeaconUser? _decodeStoredUser(String? value) {
    if (value == null) return null;
    try {
      return ParaBeaconUser.fromJson(jsonDecode(value));
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _SecureAccountSessionStore implements AccountSessionStore {
  _SecureAccountSessionStore() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
