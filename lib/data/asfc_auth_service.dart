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
  static final Uri _captchaUri = Uri.parse(
    'https://www.57fly.com/api/files/user/imageValidateCode/loadImage',
  );
  static final Uri _sendSmsCodeUri = Uri.parse(
    'https://www.57fly.com/api/user/smsvcode/sendSmsCode',
  );
  static const _tokenKey = 'asfc_access_token';
  static const _circleTokenKey = 'asfc_circle_token';
  static const _usernameKey = 'asfc_username';
  static const _storage = FlutterSecureStorage();

  bool _loaded = false;
  bool _loading = false;
  bool _captchaLoading = false;
  bool _smsCodeLoading = false;
  Uint8List? _captchaImageBytes;
  String? _token;
  String? _circleToken;
  String? _username;
  String? _errorCode;
  String? _errorMessage;

  bool get isLoaded => _loaded;
  bool get isLoading => _loading;
  bool get isCaptchaLoading => _captchaLoading;
  bool get isSmsCodeLoading => _smsCodeLoading;
  Uint8List? get captchaImageBytes => _captchaImageBytes;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;
  String? get username => _username;
  String? get errorCode => _errorCode;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_loaded) return;
    _token = await _storage.read(key: _tokenKey);
    _circleToken = await _storage.read(key: _circleTokenKey);
    _username = await _storage.read(key: _usernameKey);
    _loaded = true;
    notifyListeners();
  }

  Future<bool> loadCaptcha({required String mobile}) async {
    final normalizedMobile = mobile.trim();
    if (normalizedMobile.isEmpty) {
      _errorCode = 'smsMobileRequired';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    _captchaLoading = true;
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await http
          .get(
            _captchaUri.replace(queryParameters: {'mobile': normalizedMobile}),
            headers: const {'Accept': 'image/*, application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        _errorCode = 'captchaLoadFailed';
        _errorMessage =
            _responseReasonFromBody(response) ??
            _responseFallbackReason(response);
        return false;
      }
      _captchaImageBytes = response.bodyBytes;
      return true;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      return false;
    } finally {
      _captchaLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendSmsCode({
    required String mobile,
    required String captcha,
  }) async {
    final normalizedMobile = mobile.trim();
    final normalizedCaptcha = captcha.trim();
    if (normalizedMobile.isEmpty || normalizedCaptcha.isEmpty) {
      _errorCode = normalizedMobile.isEmpty
          ? 'smsMobileRequired'
          : 'captchaRequired';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    _smsCodeLoading = true;
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await http
          .get(
            _sendSmsCodeUri.replace(
              queryParameters: {
                'type': 'login',
                'mobile': normalizedMobile,
                'verificationCode': normalizedCaptcha,
              },
            ),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      final decoded = _decodeMap(response.body);
      final status = decoded?['status']?.toString().toLowerCase();
      final code = decoded?['code']?.toString();
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (status == 'success' || status == '200' || code == '200');
      if (!success) {
        _errorCode = 'smsCodeSendFailed';
        _errorMessage = decoded == null
            ? _responseFallbackReason(response)
            : _extractResponseReason(decoded) ??
                  _responseFallbackReason(response, status: status, code: code);
        return false;
      }
      return true;
    } on Exception {
      _errorCode = 'connectionFailed';
      _errorMessage = null;
      return false;
    } finally {
      _smsCodeLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    String? smsCode,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedSmsCode = smsCode?.trim();
    final isSmsLogin = normalizedSmsCode != null;
    final hasMissingCredentials =
        normalizedUsername.isEmpty ||
        (isSmsLogin ? normalizedSmsCode.isEmpty : password.isEmpty);
    if (hasMissingCredentials) {
      _errorCode = isSmsLogin ? 'smsCredentialsRequired' : 'missingCredentials';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    _loading = true;
    _errorCode = null;
    _errorMessage = null;
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
              'sys': 'portal',
              if (isSmsLogin) ...{
                'code': normalizedSmsCode,
                'loginType': 'sms_login',
              } else
                'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        _errorCode = 'loginFailed';
        _errorMessage = _responseFallbackReason(response);
        return false;
      }
      if (decoded is! Map<String, dynamic>) {
        _errorCode = 'loginFailed';
        _errorMessage = _responseFallbackReason(response);
        return false;
      }

      final status = decoded['status']?.toString().toUpperCase();
      final code = decoded['code']?.toString();
      final responseReason = _extractResponseReason(decoded);
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
        _errorMessage =
            responseReason ??
            _responseFallbackReason(response, status: status, code: code);
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

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String? _responseReasonFromBody(http.Response response) {
    final decoded = _decodeMap(response.body);
    return decoded == null ? null : _extractResponseReason(decoded);
  }

  String _responseFallbackReason(
    http.Response response, {
    String? status,
    String? code,
  }) {
    final details = <String>[
      'HTTP ${response.statusCode}',
      if (status != null && status.isNotEmpty) 'status=$status',
      if (code != null && code.isNotEmpty) 'code=$code',
    ];
    return details.join(' · ');
  }

  String? _extractResponseReason(Map<String, dynamic> response) {
    final candidates = <Object?>[
      response['message'],
      response['msg'],
      response['error'],
      response['bizStatus'],
    ];
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      candidates.addAll([data['message'], data['msg'], data['error']]);
    }
    for (final candidate in candidates) {
      if (candidate is String) {
        final reason = candidate.trim();
        if (reason.isNotEmpty) {
          return reason.length <= 200 ? reason : '${reason.substring(0, 200)}…';
        }
      }
    }
    return null;
  }

  Future<void> logout() async {
    _token = null;
    _circleToken = null;
    _username = null;
    _errorCode = null;
    _errorMessage = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _circleTokenKey);
    await _storage.delete(key: _usernameKey);
    notifyListeners();
  }
}
