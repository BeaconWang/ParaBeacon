import 'dart:io';

class ParaBeaconServerConfig {
  ParaBeaconServerConfig._();

  static const String baseUrl = String.fromEnvironment(
    'PARABEACON_SERVER_BASE_URL',
    defaultValue: 'https://www.parabeacon.icu',
  );

  static final Uri apiBaseUri = _parseBaseUri(baseUrl);

  static Uri get apiV1BaseUri => apiBaseUri.resolve('/api/v1/');

  static Uri _parseBaseUri(String value) {
    final uri = Uri.tryParse(value);
    if (!isValidOrigin(uri)) {
      throw FormatException(
        'PARABEACON_SERVER_BASE_URL must be a public HTTP or HTTPS origin.',
      );
    }
    return uri!;
  }

  static bool isValidOrigin(Uri? uri) {
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        _isDisallowedHost(uri.host)) {
      return false;
    }
    try {
      return uri.port >= 1 && uri.port <= 65535;
    } on FormatException {
      return false;
    }
  }

  static bool _isDisallowedHost(String host) {
    final normalized = host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
    if (normalized == 'localhost' ||
        normalized.endsWith('.localhost') ||
        normalized.endsWith('.local') ||
        normalized.endsWith('.internal')) {
      return true;
    }

    final parts = normalized.split('.');
    if (parts.length == 4 &&
        parts.every((part) => int.tryParse(part) != null)) {
      final octets = parts.map(int.parse).toList(growable: false);
      if (octets.any((octet) => octet < 0 || octet > 255)) return true;
      final first = octets[0];
      final second = octets[1];
      return first == 0 ||
          first == 9 ||
          first == 10 ||
          first == 11 ||
          first == 21 ||
          first == 30 ||
          first == 127 ||
          (first == 169 && second == 254) ||
          (first == 172 && second >= 16 && second <= 31) ||
          (first == 192 && second == 168);
    }
    if (normalized.contains(':')) {
      if (InternetAddress.tryParse(normalized) == null) return true;
      return normalized == '::' ||
          normalized == '::1' ||
          normalized.startsWith('fc') ||
          normalized.startsWith('fd') ||
          normalized.startsWith('fe80:');
    }
    return false;
  }
}
