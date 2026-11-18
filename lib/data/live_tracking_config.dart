import 'dart:convert';

import 'package:flutter/services.dart';

import 'parabeacon_server_config.dart';

/// Runtime endpoints and transport tuning loaded from the JSON asset.
class LiveTrackingConfig {
  LiveTrackingConfig({
    required this.apiBaseUri,
    required this.sessionStartUri,
    required this.sessionStopEndpointTemplate,
    required this.pointsEndpointTemplate,
    required this.authEndpointUri,
    required this.webSocketUri,
    required List<String> channelIds,
    required this.requestTimeout,
    required this.uploadInterval,
    required this.maximumBatchPoints,
    required this.maximumBufferedPoints,
  }) : channelIds = List.unmodifiable(channelIds) {
    _validateServerOrigin(apiBaseUri, 'PARABEACON_SERVER_BASE_URL');
    _validateSameOrigin(sessionStartUri, apiBaseUri, 'session_start_endpoint');
    _validateSameOrigin(
      sessionStopUri('__config_check__'),
      apiBaseUri,
      'session_stop_endpoint',
    );
    _validateSameOrigin(
      pointsUri('__config_check__'),
      apiBaseUri,
      'points_endpoint',
    );
    if (authEndpointUri != null) {
      _validateSameOrigin(authEndpointUri!, apiBaseUri, 'auth_endpoint');
    }
    final expectedWebSocketScheme = apiBaseUri.scheme == 'https' ? 'wss' : 'ws';
    if (webSocketUri != null &&
        (webSocketUri!.scheme != expectedWebSocketScheme ||
            webSocketUri!.host.toLowerCase() != apiBaseUri.host.toLowerCase() ||
            _effectivePort(webSocketUri!) != apiBaseUri.port ||
            webSocketUri!.userInfo.isNotEmpty ||
            webSocketUri!.hasFragment)) {
      throw const FormatException(
        'websocket_url must use the configured server origin.',
      );
    }
    if (this.channelIds.any(
      (id) => id.isEmpty || id.length > 128 || id.contains(RegExp(r'[\r\n]')),
    )) {
      throw const FormatException('channel_ids contains an invalid value.');
    }
    if (requestTimeout <= Duration.zero || uploadInterval <= Duration.zero) {
      throw const FormatException('Tracking durations must be positive.');
    }
    if (maximumBatchPoints < 1 ||
        maximumBufferedPoints < maximumBatchPoints ||
        maximumBufferedPoints > 100000) {
      throw const FormatException('Tracking point limits are invalid.');
    }
  }

  final Uri apiBaseUri;
  final Uri sessionStartUri;
  final String sessionStopEndpointTemplate;
  final String pointsEndpointTemplate;
  final Uri? authEndpointUri;
  final Uri? webSocketUri;
  final List<String> channelIds;
  final Duration requestTimeout;
  final Duration uploadInterval;
  final int maximumBatchPoints;
  final int maximumBufferedPoints;

  Uri sessionStopUri(String sessionId) {
    if (sessionId.isEmpty) throw ArgumentError.value(sessionId, 'sessionId');
    final endpoint = sessionStopEndpointTemplate.replaceAll(
      '{session_id}',
      Uri.encodeComponent(sessionId),
    );
    return _resolveUri(apiBaseUri, endpoint, 'session_stop_endpoint');
  }

  Uri pointsUri(String sessionId) {
    if (sessionId.isEmpty) throw ArgumentError.value(sessionId, 'sessionId');
    final endpoint = pointsEndpointTemplate.replaceAll(
      '{session_id}',
      Uri.encodeComponent(sessionId),
    );
    return _resolveUri(apiBaseUri, endpoint, 'points_endpoint');
  }

  factory LiveTrackingConfig.fromJson(Object? value, {Uri? apiBaseUri}) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException(
        'Live tracking config must be a JSON object.',
      );
    }

    String requiredString(String key) {
      final item = value[key];
      if (item is! String || item.trim().isEmpty) {
        throw FormatException('Missing or invalid $key.');
      }
      return item.trim();
    }

    String? optionalString(String key) {
      if (!value.containsKey(key)) {
        throw FormatException('Missing $key.');
      }
      final item = value[key];
      if (item == null) return null;
      if (item is! String) throw FormatException('Invalid $key.');
      final trimmed = item.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    int requiredInt(String key) {
      final item = value[key];
      if (item is! int) throw FormatException('Missing or invalid $key.');
      return item;
    }

    final serverBaseUri = apiBaseUri ?? ParaBeaconServerConfig.apiBaseUri;
    _validateServerOrigin(serverBaseUri, 'PARABEACON_SERVER_BASE_URL');

    final sessionStartUri = _resolveUri(
      serverBaseUri,
      requiredString('session_start_endpoint'),
      'session_start_endpoint',
    );
    final sessionStopEndpointTemplate = requiredString('session_stop_endpoint');
    if (!sessionStopEndpointTemplate.contains('{session_id}')) {
      throw const FormatException(
        'session_stop_endpoint must contain {session_id}.',
      );
    }
    final pointsEndpointTemplate = requiredString('points_endpoint');
    if (!pointsEndpointTemplate.contains('{session_id}')) {
      throw const FormatException('points_endpoint must contain {session_id}.');
    }
    final authEndpoint = optionalString('auth_endpoint');
    final authEndpointUri = authEndpoint == null
        ? null
        : _resolveUri(serverBaseUri, authEndpoint, 'auth_endpoint');
    final socketValue = optionalString('websocket_url');
    Uri? webSocketUri;
    if (socketValue != null) {
      final parsedSocket = Uri.tryParse(socketValue);
      if (parsedSocket == null) {
        throw const FormatException('Invalid websocket_url.');
      }
      webSocketUri = parsedSocket.hasScheme
          ? parsedSocket
          : serverBaseUri
                .replace(scheme: serverBaseUri.scheme == 'https' ? 'wss' : 'ws')
                .resolveUri(parsedSocket);
    }

    final rawChannelIds = value['channel_ids'];
    if (rawChannelIds is! List) {
      throw const FormatException('channel_ids must be a JSON array.');
    }
    final channelIds = <String>[];
    for (final channel in rawChannelIds) {
      if (channel is String && channel.trim().isNotEmpty) {
        channelIds.add(channel.trim());
      } else if (channel is int) {
        channelIds.add(channel.toString());
      } else {
        throw const FormatException('channel_ids contains an invalid value.');
      }
    }

    return LiveTrackingConfig(
      apiBaseUri: serverBaseUri,
      sessionStartUri: sessionStartUri,
      sessionStopEndpointTemplate: sessionStopEndpointTemplate,
      pointsEndpointTemplate: pointsEndpointTemplate,
      authEndpointUri: authEndpointUri,
      webSocketUri: webSocketUri,
      channelIds: channelIds,
      requestTimeout: Duration(seconds: requiredInt('request_timeout_seconds')),
      uploadInterval: Duration(seconds: requiredInt('upload_interval_seconds')),
      maximumBatchPoints: requiredInt('maximum_batch_points'),
      maximumBufferedPoints: requiredInt('maximum_buffered_points'),
    );
  }
}

class LiveTrackingConfigLoader {
  const LiveTrackingConfigLoader({
    AssetBundle? bundle,
    this.assetPath = 'assets/config/live_tracking_config.json',
    this.apiBaseUri,
  }) : _bundle = bundle;

  final AssetBundle? _bundle;
  final String assetPath;
  final Uri? apiBaseUri;

  Future<LiveTrackingConfig> load() async {
    final source = await (_bundle ?? rootBundle).loadString(assetPath);
    final decoded = jsonDecode(source);
    return LiveTrackingConfig.fromJson(
      decoded,
      apiBaseUri: apiBaseUri ?? ParaBeaconServerConfig.apiBaseUri,
    );
  }
}

Uri _resolveUri(Uri baseUri, String endpoint, String fieldName) {
  final parsed = Uri.tryParse(endpoint);
  if (parsed == null) throw FormatException('Invalid $fieldName.');
  final resolved = baseUri.resolveUri(parsed);
  _validateSameOrigin(resolved, baseUri, fieldName);
  return resolved;
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return uri.scheme == 'https' || uri.scheme == 'wss' ? 443 : 80;
}

void _validateServerOrigin(Uri uri, String fieldName) {
  if (!ParaBeaconServerConfig.isValidOrigin(uri)) {
    throw FormatException('$fieldName must be a public HTTP or HTTPS origin.');
  }
}

void _validateSameOrigin(Uri uri, Uri baseUri, String fieldName) {
  if (uri.scheme != baseUri.scheme ||
      uri.host.toLowerCase() != baseUri.host.toLowerCase() ||
      uri.port != baseUri.port ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw FormatException('$fieldName must use the configured server origin.');
  }
}
