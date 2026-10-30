import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserAgentSettings extends ChangeNotifier {
  UserAgentSettings._();

  static final UserAgentSettings instance = UserAgentSettings._();
  static const preferenceKey = 'pb.network.userAgent';
  static const chromeDefault =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/131.0.0.0 Safari/537.36';
  static const _maxLength = 512;

  static final http.Client sharedClient = UserAgentHttpClient();

  String _userAgent = chromeDefault;
  bool _loaded = false;

  String get userAgent => _userAgent;
  Map<String, String> get requestHeaders => {'User-Agent': _userAgent};

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(preferenceKey);
      if (saved != null && isValid(saved)) _userAgent = saved.trim();
    } catch (_) {
      // The Chrome-compatible default still applies in memory.
    }
    notifyListeners();
  }

  static bool isValid(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > _maxLength) return false;
    return normalized.runes.every(
      (rune) => rune >= 0x20 && (rune < 0x7f || rune > 0x9f),
    );
  }

  Future<bool> setUserAgent(String value) async {
    if (!isValid(value)) return false;
    final normalized = value.trim();
    if (_userAgent == normalized) return true;
    _userAgent = normalized;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(preferenceKey, normalized);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
    return true;
  }

  Future<void> resetToChromeDefault() async {
    final changed = _userAgent != chromeDefault;
    _userAgent = chromeDefault;
    if (changed) notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(preferenceKey);
    } catch (_) {
      // The in-memory default still applies for this session.
    }
  }

  String forRequest(Uri uri) {
    final userAgent = _userAgent;
    if (uri.host.toLowerCase() == 'nominatim.openstreetmap.org' &&
        !userAgent.toLowerCase().contains('parabeacon')) {
      return '$userAgent ParaBeacon/0.1 (paraglider flight assistant)';
    }
    return userAgent;
  }
}

class UserAgentHttpClient extends http.BaseClient {
  UserAgentHttpClient({http.Client? innerClient})
    : _innerClient = innerClient ?? http.Client(),
      _ownsInnerClient = innerClient == null;

  final http.Client _innerClient;
  final bool _ownsInnerClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = UserAgentSettings.instance.forRequest(
      request.url,
    );
    return _innerClient.send(request);
  }

  @override
  void close() {
    if (_ownsInnerClient) _innerClient.close();
  }
}
