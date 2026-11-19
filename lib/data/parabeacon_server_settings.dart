import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parabeacon_server_config.dart';

typedef ServerAddressLookup =
    Future<List<InternetAddress>> Function(String host);

class ParaBeaconServerSettings extends ChangeNotifier {
  ParaBeaconServerSettings();

  static final ParaBeaconServerSettings instance = ParaBeaconServerSettings();
  static const preferenceKey = 'pb.network.paraBeaconServerAddress';
  static const _lookupTimeout = Duration(seconds: 5);

  bool _loaded = false;
  Uri _selectedBaseUri = ParaBeaconServerConfig.apiBaseUri;
  Uri get baseUri => ParaBeaconServerConfig.apiBaseUri;
  Uri get selectedBaseUri => _selectedBaseUri;
  String get serverAddress => _selectedBaseUri.toString();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(preferenceKey);
      final uri = saved == null ? null : parseAddress(saved);
      if (uri != null) {
        _selectedBaseUri = uri;
        ParaBeaconServerConfig.configureBaseUri(uri);
      }
    } on Object {
      // The compiled public default remains available if preferences fail.
    }
    notifyListeners();
  }

  static Uri? parseAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 2048 ||
        trimmed.contains(RegExp(r'[\s\\]'))) {
      return null;
    }
    final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final parsed = Uri.tryParse(candidate);
    if (!ParaBeaconServerConfig.isValidUserOrigin(parsed)) return null;
    try {
      return Uri(
        scheme: 'https',
        host: parsed!.host,
        port: parsed.hasPort && parsed.port != 443 ? parsed.port : null,
      );
    } on FormatException {
      return null;
    }
  }

  Future<bool> isPublicServerAddress(
    String value, {
    ServerAddressLookup lookup = InternetAddress.lookup,
  }) async {
    final uri = parseAddress(value);
    return uri != null && await _resolvesOnlyToPublicAddresses(uri, lookup);
  }

  Future<bool> setServerAddress(
    String value, {
    ServerAddressLookup lookup = InternetAddress.lookup,
  }) async {
    final uri = parseAddress(value);
    if (uri == null || !await _resolvesOnlyToPublicAddresses(uri, lookup)) {
      return false;
    }
    if (uri == _selectedBaseUri) {
      ParaBeaconServerConfig.configureBaseUri(uri);
      return true;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(preferenceKey, uri.toString());
    } on Object {
      return false;
    }
    _selectedBaseUri = uri;
    ParaBeaconServerConfig.configureBaseUri(uri);
    notifyListeners();
    return true;
  }

  Future<bool> resetToDefault({
    ServerAddressLookup lookup = InternetAddress.lookup,
  }) async {
    return setServerAddress(
      ParaBeaconServerConfig.defaultBaseUrl,
      lookup: lookup,
    );
  }

  Future<bool> _resolvesOnlyToPublicAddresses(
    Uri uri,
    ServerAddressLookup lookup,
  ) async {
    try {
      final addresses = await lookup(uri.host).timeout(_lookupTimeout);
      return addresses.isNotEmpty &&
          addresses.every(ParaBeaconServerConfig.isPublicAddress);
    } on Object {
      return false;
    }
  }
}
