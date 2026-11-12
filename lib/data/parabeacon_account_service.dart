import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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

class ParaBeaconAccountService extends ChangeNotifier {
  ParaBeaconAccountService({
    http.Client? client,
    AccountSessionStore? sessionStore,
  }) : _client = UserAgentHttpClient(innerClient: client),
       _store = sessionStore ?? _SecureAccountSessionStore();

  static final ParaBeaconAccountService instance = ParaBeaconAccountService();

  static final Uri _apiBaseUri = Uri.https('www.parabeacon.icu', '/api/v1/');
  static const _tokenKey = 'parabeacon_access_token';
  static const _expiresAtKey = 'parabeacon_access_token_expires_at';
  static const _userKey = 'parabeacon_account_user';
  static const _requestTimeout = Duration(seconds: 15);

  final http.Client _client;
  final AccountSessionStore _store;

  bool _loaded = false;
  bool _loading = false;
  String? _token;
  DateTime? _expiresAt;
  ParaBeaconUser? _user;
  String? _errorCode;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  bool get isSignedIn =>
      _token != null &&
      _token!.isNotEmpty &&
      (_expiresAt == null || _expiresAt!.isAfter(DateTime.now()));
  ParaBeaconUser? get user => _user;
  String? get errorCode => _errorCode;

  Future<void> load() async {
    if (_loaded || _loading) return;
    _loading = true;
    _errorCode = null;
    notifyListeners();
    try {
      _token = await _store.read(_tokenKey);
      final expiresAtValue = await _store.read(_expiresAtKey);
      _expiresAt = expiresAtValue == null
          ? null
          : DateTime.tryParse(expiresAtValue);
      _user = _decodeStoredUser(await _store.read(_userKey));

      if (!isSignedIn) {
        await _clearStoredSession();
        _token = null;
        _expiresAt = null;
        _user = null;
      } else {
        await _refreshProfile();
      }
    } on Exception {
      _errorCode = 'accountStorageFailure';
    } finally {
      _loaded = true;
      _loading = false;
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

    _beginRequest();
    try {
      return await _performLogin(normalizedIdentifier, password);
    } on TimeoutException {
      _errorCode = 'accountConnectionFailure';
      return false;
    } on Exception {
      _errorCode = 'accountServiceUnavailable';
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
      return false;
    } on Exception {
      _errorCode = 'accountServiceUnavailable';
      return false;
    } finally {
      _endRequest();
    }
  }

  Future<void> logout() async {
    _token = null;
    _expiresAt = null;
    _user = null;
    _errorCode = null;
    try {
      await _clearStoredSession();
    } on Exception {
      _errorCode = 'accountStorageFailure';
    }
    notifyListeners();
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
    try {
      await _store.write(_tokenKey, token);
      if (expiresAt == null) {
        await _store.delete(_expiresAtKey);
      } else {
        await _store.write(_expiresAtKey, expiresAt.toIso8601String());
      }
      await _store.write(_userKey, jsonEncode(user.toJson()));
    } on Exception {
      try {
        await _clearStoredSession();
      } on Exception {
        // Keep the session signed out even if secure-store cleanup also fails.
      }
      _errorCode = 'accountStorageFailure';
      return false;
    }

    _token = token;
    _expiresAt = expiresAt;
    _user = user;
    _errorCode = null;
    return true;
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
    } on TimeoutException {
      _errorCode = 'accountConnectionFailure';
      return;
    } on http.ClientException {
      _errorCode = 'accountConnectionFailure';
      return;
    } on Exception {
      _errorCode = 'accountServiceUnavailable';
      return;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await _clearStoredSession();
      _token = null;
      _expiresAt = null;
      _user = null;
      return;
    }
    if (response.statusCode != 200) {
      _errorCode = response.statusCode >= 500
          ? 'accountServiceUnavailable'
          : 'accountRequestFailed';
      return;
    }

    final user = ParaBeaconUser.fromJson(_decodeMap(response.body)?['user']);
    if (user == null) {
      _errorCode = 'accountRequestFailed';
      return;
    }
    _user = user;
    try {
      await _store.write(_userKey, jsonEncode(user.toJson()));
    } on Exception {
      _errorCode = 'accountStorageFailure';
    }
  }

  Future<void> _clearStoredSession() async {
    for (final key in [_tokenKey, _expiresAtKey, _userKey]) {
      await _store.delete(key);
    }
  }

  void _beginRequest() {
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

  static Uri _apiUri(String path) => _apiBaseUri.resolve(path);

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
