import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class LiveTrackingProxyAuthProvider {
  Future<Map<String, String>> authorizationHeaders();
}

/// Stores the proxy-issued bearer credential in platform secure storage.
/// This is separate from the XContest OAuth token and is only sent to the
/// configured ParaBeacon proxy origin.
class LiveTrackingProxyAuthService extends ChangeNotifier
    implements LiveTrackingProxyAuthProvider {
  LiveTrackingProxyAuthService._({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static final LiveTrackingProxyAuthService instance =
      LiveTrackingProxyAuthService._();

  static const _tokenKey = 'pb.liveTracking.proxyBearer.v1';

  final FlutterSecureStorage _storage;
  String? _bearerToken;
  Future<void>? _loadFuture;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isConfigured => _bearerToken?.isNotEmpty == true;
  String get bearerTokenForSettings => _bearerToken ?? '';

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _loadOnce();
  }

  Future<void> _loadOnce() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      _bearerToken = token?.trim().isEmpty == true ? null : token?.trim();
    } on Object {
      _bearerToken = null;
    } finally {
      _loaded = true;
      _loadFuture = null;
      notifyListeners();
    }
  }

  Future<void> setBearerToken(String token) async {
    await load();
    final normalized = token.trim();
    if (normalized.isEmpty) {
      await _storage.delete(key: _tokenKey);
      _bearerToken = null;
    } else {
      await _storage.write(key: _tokenKey, value: normalized);
      _bearerToken = normalized;
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  Future<Map<String, String>> authorizationHeaders() async {
    await load();
    final token = _bearerToken;
    if (token == null || token.isEmpty) {
      throw const LiveTrackingProxyAuthException('proxy_auth_required');
    }
    return {'Authorization': 'Bearer $token'};
  }
}

class LiveTrackingProxyAuthException implements Exception {
  const LiveTrackingProxyAuthException(this.code);

  final String code;

  @override
  String toString() => 'LiveTrackingProxyAuthException($code)';
}
