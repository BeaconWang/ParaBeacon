import 'dart:io';

class ParaBeaconServerConfig {
  ParaBeaconServerConfig._();

  static const String defaultBaseUrl = String.fromEnvironment(
    'PARABEACON_SERVER_BASE_URL',
    defaultValue: 'https://www.parabeacon.icu',
  );

  static final Uri defaultApiBaseUri = _parseBaseUri(defaultBaseUrl);
  static Uri _apiBaseUri = defaultApiBaseUri;

  static Uri get apiBaseUri => _apiBaseUri;
  static String get baseUrl => _apiBaseUri.toString();
  static Uri get apiV1BaseUri => _apiBaseUri.resolve('/api/v1/');
  static Uri get defaultApiV1BaseUri => defaultApiBaseUri.resolve('/api/v1/');

  static void configureBaseUri(Uri uri) {
    if (!isValidUserOrigin(uri)) {
      throw ArgumentError.value(
        uri,
        'uri',
        'Expected a public HTTP or HTTPS origin.',
      );
    }
    _apiBaseUri = uri;
  }

  static bool isValidUserOrigin(Uri? uri) => isValidOrigin(uri);

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

  static bool isPublicAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      final first = bytes[0];
      final second = bytes[1];
      final third = bytes[2];
      return !(first == 0 ||
          first == 9 ||
          first == 10 ||
          first == 11 ||
          first == 21 ||
          first == 30 ||
          first == 127 ||
          (first == 100 && second >= 64 && second <= 127) ||
          (first == 169 && second == 254) ||
          (first == 172 && second >= 16 && second <= 31) ||
          (first == 192 &&
              (second == 0 || second == 88 && third == 99 || second == 168)) ||
          (first == 198 &&
              (second == 18 || second == 19 || second == 51 && third == 100)) ||
          (first == 203 && second == 0 && third == 113) ||
          first >= 224);
    }

    final isIPv4Mapped =
        bytes.length == 16 &&
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    if (isIPv4Mapped) {
      return isPublicAddress(InternetAddress.fromRawAddress(bytes.sublist(12)));
    }
    final isGlobalUnicast = (bytes[0] & 0xe0) == 0x20;
    if (!isGlobalUnicast) return false;
    final isDocumentation =
        bytes[0] == 0x20 &&
        bytes[1] == 0x01 &&
        bytes[2] == 0x0d &&
        bytes[3] == 0xb8;
    final isSpecial2001 =
        bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] <= 0x01;
    final is6to4 = bytes[0] == 0x20 && bytes[1] == 0x02;
    final isDocumentation3fff =
        bytes[0] == 0x3f && bytes[1] == 0xff && (bytes[2] & 0xf0) == 0;
    return !isDocumentation &&
        !isSpecial2001 &&
        !is6to4 &&
        !isDocumentation3fff;
  }

  static bool _isDisallowedHost(String host) {
    final normalized = host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
    final literal = InternetAddress.tryParse(normalized);
    if (literal != null) return !isPublicAddress(literal);
    if (normalized.contains(':') || RegExp(r'^[0-9.]+$').hasMatch(normalized)) {
      return true;
    }
    if (!normalized.contains('.') ||
        normalized == 'localhost' ||
        normalized.endsWith('.localhost') ||
        normalized.endsWith('.local') ||
        normalized.endsWith('.internal') ||
        normalized.endsWith('.test') ||
        normalized.endsWith('.example') ||
        normalized.endsWith('.invalid') ||
        normalized.endsWith('.onion')) {
      return true;
    }
    return false;
  }
}
