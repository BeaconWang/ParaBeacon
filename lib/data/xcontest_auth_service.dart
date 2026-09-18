import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class XContestAuthService extends ChangeNotifier {
  XContestAuthService._({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static final XContestAuthService instance = XContestAuthService._();

  static final Uri _tokenUri = Uri.https(
    'simple-auth.xcontest.org',
    '/oauth/token_noauth',
  );
  static const _tokenKey = 'xcontest_access_token';
  static const _uidKey = 'xcontest_uid';
  static const _usernameKey = 'xcontest_username';
  static const _fullNameKey = 'xcontest_full_name';

  final http.Client _client;
  final FlutterSecureStorage _storage;

  bool _loaded = false;
  bool _loading = false;
  String? _token;
  String? _uid;
  String? _username;
  String? _fullName;
  String? _errorCode;
  String? _errorMessage;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;
  String? get username => _username;
  String? get uid => _uid;
  String? get fullName => _fullName;
  String? get errorCode => _errorCode;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_loaded) return;
    _token = await _storage.read(key: _tokenKey);
    _uid = await _storage.read(key: _uidKey);
    _username = await _storage.read(key: _usernameKey);
    _fullName = await _storage.read(key: _fullNameKey);
    _loaded = true;
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      _errorCode = 'missingCredentials';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    _loading = true;
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _client
          .post(
            _tokenUri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'password',
              'clientid': 'xctrack',
              'username': normalizedUsername,
              // Do not persist or log the password; it is sent only for this
              // request, matching XContest's password grant.
              'password': password,
            },
          )
          .timeout(const Duration(seconds: 15));

      final decoded = _decodeMap(response.body);
      final token = decoded?['access_token'];
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          token is! String ||
          token.isEmpty) {
        _errorCode = response.statusCode == 401 || response.statusCode == 403
            ? 'invalidCredentials'
            : 'loginFailed';
        _errorMessage = _extractResponseReason(decoded);
        return false;
      }

      _token = token;
      _uid = _stringOrNull(decoded?['uid']);
      _fullName = _stringOrNull(decoded?['full_name']);
      _username = normalizedUsername;
      await _storage.write(key: _tokenKey, value: _token);
      await _writeOrDelete(_uidKey, _uid);
      await _writeOrDelete(_usernameKey, _username);
      await _writeOrDelete(_fullNameKey, _fullName);
      return true;
    } on TimeoutException {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      return false;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      return false;
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String? _stringOrNull(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return null;
  }

  String? _extractResponseReason(Map<String, dynamic>? response) {
    if (response == null) return null;
    for (final candidate in [
      response['error_description'],
      response['message'],
      response['error'],
    ]) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        final reason = candidate.trim();
        return reason.length <= 200 ? reason : '${reason.substring(0, 200)}…';
      }
    }
    return null;
  }

  Future<void> logout() async {
    _token = null;
    _uid = null;
    _username = null;
    _fullName = null;
    _errorCode = null;
    _errorMessage = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _uidKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _fullNameKey);
    notifyListeners();
  }
}
