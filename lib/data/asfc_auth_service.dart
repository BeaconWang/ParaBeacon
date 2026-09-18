import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AsfcAuthService extends ChangeNotifier {
  AsfcAuthService._();

  static final AsfcAuthService instance = AsfcAuthService._();

  static final Uri _loginUri = Uri.parse(
    'https://www.57fly.com/api/user/user/login',
  );
  static const _tokenKey = 'asfc_access_token';
  static const _circleTokenKey = 'asfc_circle_token';
  static const _usernameKey = 'asfc_username';
  static const _storage = FlutterSecureStorage();

  bool _loaded = false;
  bool _loading = false;
  String? _token;
  String? _circleToken;
  String? _username;
  String? _errorCode;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;
  String? get username => _username;
  String? get errorCode => _errorCode;

  Future<void> load() async {
    if (_loaded) return;
    _token = await _storage.read(key: _tokenKey);
    _circleToken = await _storage.read(key: _circleTokenKey);
    _username = await _storage.read(key: _usernameKey);
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
      notifyListeners();
      return false;
    }

    _loading = true;
    _errorCode = null;
    notifyListeners();

    try {
      final response = await http
          .post(
            _loginUri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
            // Matches GoFly's password-login request. Nullable optional fields
            // are omitted, as they are by its JSON converter.
            body: jsonEncode({
              'username': normalizedUsername,
              'password': password,
              'sys': 'portal',
            }),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response');
      }

      final status = decoded['status']?.toString().toUpperCase();
      final code = decoded['code']?.toString();
      final isSuccess =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == '200' || status == 'SUCCESS' || code == '200');
      final data = decoded['data'];
      final token = data is Map<String, dynamic> ? data['token'] : null;
      final circleToken = data is Map<String, dynamic>
          ? data['circleToken']
          : null;

      if (!isSuccess || token is! String || token.isEmpty) {
        _errorCode = 'loginFailed';
        return false;
      }

      _token = token;
      _circleToken = circleToken is String ? circleToken : null;
      _username = normalizedUsername;
      await _storage.write(key: _tokenKey, value: _token);
      if (_circleToken == null || _circleToken!.isEmpty) {
        await _storage.delete(key: _circleTokenKey);
      } else {
        await _storage.write(key: _circleTokenKey, value: _circleToken);
      }
      await _storage.write(key: _usernameKey, value: _username);
      return true;
    } on FormatException {
      _errorCode = 'loginFailed';
      return false;
    } on Exception {
      _errorCode = 'connectionFailed';
      return false;
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _circleToken = null;
    _username = null;
    _errorCode = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _circleTokenKey);
    await _storage.delete(key: _usernameKey);
    notifyListeners();
  }
}
