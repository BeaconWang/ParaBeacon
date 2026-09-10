import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gcj02.dart';
import 'geo_name_settings.dart';

/// Resolves a latitude/longitude to a short human place name via the AMap
/// (AutoNavi) reverse-geocoding web service.
///
/// Security / privacy notes:
///  * The API key is read only from [GeoNameSettings] (a user secret), never
///    hard-coded.
///  * Requests only ever go to the single fixed host `restapi.amap.com` over
///    HTTPS. No user- or flight-supplied host is ever contacted, so this cannot
///    be steered at an internal/metadata endpoint (no SSRF surface).
///  * AMap consumes GCJ-02 coordinates; GPS fixes are WGS-84, so we convert
///    with [Gcj02.wgsToGcj] before querying.
class ReverseGeocoderService {
  ReverseGeocoderService._();
  static final ReverseGeocoderService instance = ReverseGeocoderService._();

  /// The ONLY host this service will ever contact.
  static const String _host = 'restapi.amap.com';
  static const String _path = '/v3/geocode/regeo';

  final http.Client _client = http.Client();

  /// Reverse-geocodes WGS-84 [lat]/[lon] to a short place name, or null when
  /// geocoding is not configured, the request fails, or no name is found.
  Future<String?> lookup(double lat, double lon) async {
    final settings = GeoNameSettings.instance;
    await settings.load();
    final key = settings.amapKey;
    if (key == null || key.isEmpty) return null;

    // AMap expects GCJ-02 (lon,lat) within mainland China; elsewhere it has no
    // coverage, so skip the request entirely.
    if (Gcj02.outOfChina(lat, lon)) return null;
    final gcj = Gcj02.wgsToGcj(lat, lon);

    final uri = Uri.https(_host, _path, {
      'key': key,
      'location': '${gcj[1].toStringAsFixed(6)},${gcj[0].toStringAsFixed(6)}',
      'extensions': 'base',
      'radius': '1000',
    });
    // Defense-in-depth: the URI host is built from a constant, but assert it
    // anyway so a future refactor can't accidentally point elsewhere.
    assert(uri.host == _host);

    try {
      final resp =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body);
      if (body is! Map || body['status'] != '1') return null;
      final regeo = body['regeocode'];
      if (regeo is! Map) return null;
      return _shortName(regeo);
    } catch (_) {
      return null;
    }
  }

  /// Convenience: reverse-geocode the given coordinate, swallowing errors.
  Future<String?> tryLookup(double lat, double lon) => lookup(lat, lon);

  /// Extracts a concise place name from an AMap `regeocode` object, preferring
  /// the nearest township/AOI over the full formatted address.
  String? _shortName(Map regeo) {
    final comp = regeo['addressComponent'];
    if (comp is Map) {
      // Prefer the most specific local name available.
      final township = _str(comp['township']);
      final district = _str(comp['district']);
      final city = _firstStr(comp['city']);
      final province = _str(comp['province']);
      final parts = [township, district, city, province]
          .where((e) => e != null && e.isNotEmpty)
          .cast<String>()
          .toList();
      if (parts.isNotEmpty) {
        // Use the two most specific, e.g. "City · Township".
        return parts.take(2).join(' · ');
      }
    }
    final formatted = _str(regeo['formatted_address']);
    return (formatted != null && formatted.isNotEmpty) ? formatted : null;
  }

  String? _str(dynamic v) => v is String ? v : null;

  // AMap sometimes returns `city` as an empty list (for direct-controlled
  // municipalities); normalize that to null.
  String? _firstStr(dynamic v) {
    if (v is String) return v.isEmpty ? null : v;
    if (v is List && v.isNotEmpty && v.first is String) {
      final s = v.first as String;
      return s.isEmpty ? null : s;
    }
    return null;
  }
}
