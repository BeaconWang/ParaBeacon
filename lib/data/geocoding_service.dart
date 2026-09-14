import 'dart:convert';

import 'package:http/http.dart' as http;

import 'weather_service.dart' show WeatherException, WeatherError;

/// Free geocoding (place name → latitude/longitude) via OpenStreetMap's
/// Nominatim service. Powers the Weather screen's location search bar.
///
/// Security / privacy notes:
///  * The ONLY host ever contacted is the compile-time constant
///    `nominatim.openstreetmap.org` over HTTPS. The user's query is sent
///    exclusively as a URL *query parameter* (never a host, path or
///    header), so no user input can steer the request anywhere else —
///    no SSRF surface.
///  * Nominatim's usage policy requires requests to identify the
///    application (User-Agent) and limits burden: queries are debounced
///    by the caller (300 ms) and capped at 8 results.
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  /// The ONLY host this service will ever contact.
  static const String _host = 'nominatim.openstreetmap.org';

  static const String _userAgent =
      'ParaBeacon/0.1 (paraglider flight assistant)';

  /// Max accepted length of a user query (Nominatim is comfortable with
  /// far more; the cap only guards against accidental pastes).
  static const int _maxQueryLength = 80;

  /// Max results per search (Nominatim's documented cap is 50; 8 keeps the
  /// dropdown scannable and the response small).
  static const int _limit = 8;

  final http.Client _client = http.Client();

  /// Resolves [rawQuery] into up to 8 candidate places, best match first.
  /// Returns an empty list when nothing matches. Throws
  /// [WeatherException] on network/transport failure — an empty result set
  /// is NOT an error.
  Future<List<GeocodedPlace>> search(String rawQuery,
      {String language = 'en'}) async {
    final q = _sanitize(rawQuery);
    if (q.isEmpty) return const [];

    final uri = Uri.https(_host, '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '$_limit',
      'addressdetails': '1',
    });
    // Defense-in-depth: the URI host is built from a constant, but assert it
    // anyway so a future refactor can't accidentally point elsewhere.
    assert(uri.host == _host);

    final http.Response resp;
    try {
      resp = await _client
          .get(
            uri,
            headers: {
              // Nominatim policy: identify the application. Never sent to
              // any other host (headers are per-request here).
              'User-Agent': _userAgent,
              'Accept-Language': language,
            },
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const WeatherException(WeatherError.network);
    }
    if (resp.statusCode != 200) {
      throw const WeatherException(WeatherError.network);
    }

    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        throw const WeatherException(WeatherError.badResponse);
      }
      final places = <GeocodedPlace>[];
      for (final raw in decoded) {
        final place = GeocodedPlace.tryParse(raw);
        if (place != null) places.add(place);
      }
      return places;
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw const WeatherException(WeatherError.badResponse);
    }
  }

  /// Reverse-geocodes coordinates into a short place name for the header of
  /// the Weather screen. Returns null when the lookup fails (this is a
  /// best-effort nicety, never a hard error path).
  Future<String?> reverseName({
    required double lat,
    required double lon,
    String language = 'en',
  }) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': lat.toStringAsFixed(4),
      'lon': lon.toStringAsFixed(4),
      'format': 'jsonv2',
      'zoom': '10',
    });
    assert(uri.host == _host);
    try {
      final resp = await _client
          .get(
            uri,
            headers: {
              'User-Agent': _userAgent,
              'Accept-Language': language,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return null;
      return GeocodedPlace.tryParse(decoded)?.name;
    } catch (_) {
      return null;
    }
  }

  /// Trims, strips control characters and caps the query length. Rejects
  /// (returns empty for) queries that are empty after cleanup.
  static String _sanitize(String rawQuery) {
    final buffer = StringBuffer();
    for (final code in rawQuery.runes) {
      // Drop control characters (incl. C0/C1); keep everything printable —
      // any Unicode script is valid input for Nominatim.
      if (code >= 0x20 && code != 0x7f && !(code >= 0x80 && code < 0xa0)) {
        buffer.writeCharCode(code);
      }
    }
    final cleaned = buffer.toString().trim();
    if (cleaned.length > _maxQueryLength) {
      return cleaned.substring(0, _maxQueryLength);
    }
    return cleaned;
  }
}

/// One geocoding candidate.
class GeocodedPlace {
  final String name; // short label (city / village / place)
  final String displayName; // full "parts, region, country" label
  final double lat;
  final double lon;

  const GeocodedPlace({
    required this.name,
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  /// Parses one Nominatim jsonv2 feature; null when the entry is unusable
  /// (missing/invalid coordinates or no name at all).
  static GeocodedPlace? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    final lat = double.tryParse('${m['lat']}');
    final lon = double.tryParse('${m['lon']}');
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    final displayName = '${m['display_name']}'.trim();
    if (displayName.isEmpty) return null;
    // `name` (jsonv2) is the bare place name; fall back to the first
    // comma-separated part of the display name.
    final rawName = m['name'];
    var name = rawName == null ? '' : '$rawName'.trim();
    if (name.isEmpty) {
      name = displayName.split(',').first.trim();
    }
    if (name.isEmpty) return null;
    return GeocodedPlace(
      name: name,
      displayName: displayName,
      lat: lat,
      lon: lon,
    );
  }
}
