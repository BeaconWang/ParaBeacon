import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One user-saved location (Weather screen favorites).
///
/// Coordinates are always WGS-84 — the same contract the weather layer and
/// the map picker use.
@immutable
class FavoritePlace {
  const FavoritePlace({
    required this.name,
    required this.lat,
    required this.lon,
  });

  final String name;
  final double lat;
  final double lon;

  /// Max stored name length (guards against accidental pastes filling up the
  /// preferences blob).
  static const int maxNameLength = 60;

  Map<String, Object?> toJson() => {'name': name, 'lat': lat, 'lon': lon};

  /// Parses one persisted entry, returning null when it is unusable. Never
  /// trusts the stored blob: types and ranges are validated explicitly.
  static FavoritePlace? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final lat = raw['lat'];
    final lon = raw['lon'];
    if (name is! String || lat is! num || lon is! num) return null;
    return create(name: name, lat: lat.toDouble(), lon: lon.toDouble());
  }

  /// Builds a sanitized entry, or null when the name/coordinates are invalid.
  static FavoritePlace? create({
    required String name,
    required double lat,
    required double lon,
  }) {
    if (lat.isNaN || lon.isNaN) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    final clean = _sanitizeName(name);
    if (clean.isEmpty) return null;
    return FavoritePlace(name: clean, lat: lat, lon: lon);
  }

  /// Strips control characters and caps the length.
  static String _sanitizeName(String raw) {
    final buffer = StringBuffer();
    for (final code in raw.runes) {
      if (code >= 0x20 && code != 0x7f && !(code >= 0x80 && code < 0xa0)) {
        buffer.writeCharCode(code);
      }
    }
    final cleaned = buffer.toString().trim();
    return cleaned.length > maxNameLength
        ? cleaned.substring(0, maxNameLength).trim()
        : cleaned;
  }
}

/// The user's saved weather locations, persisted in this device's
/// SharedPreferences (no account, no sync, nothing secret).
class WeatherFavoritesStore extends ChangeNotifier {
  WeatherFavoritesStore._();
  static final WeatherFavoritesStore instance = WeatherFavoritesStore._();

  static const String _key = 'pb.weather.favorites';

  /// Upper bound on stored entries; adding beyond it drops the oldest.
  static const int maxEntries = 50;

  /// Two positions closer than this (in degrees, ~50 m) count as the same
  /// place, so re-saving a spot updates it instead of piling up duplicates.
  static const double _sameSpotEpsilon = 0.0005;

  final List<FavoritePlace> _places = [];
  bool _loaded = false;

  List<FavoritePlace> get places => List.unmodifiable(_places);

  bool get isLoaded => _loaded;

  /// Loads the persisted list (idempotent, best-effort).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final entry in decoded) {
        final place = FavoritePlace.tryParse(entry);
        if (place != null) _places.add(place);
        if (_places.length >= maxEntries) break;
      }
      if (_places.isNotEmpty) notifyListeners();
    } catch (_) {
      // Corrupt or unreadable store: start from an empty list.
    }
  }

  /// Whether a favorite already covers [lat]/[lon].
  bool contains(double lat, double lon) => indexOfSpot(lat, lon) >= 0;

  /// Index of the favorite at [lat]/[lon], or -1.
  int indexOfSpot(double lat, double lon) {
    for (var i = 0; i < _places.length; i++) {
      final p = _places[i];
      if ((p.lat - lat).abs() < _sameSpotEpsilon &&
          (p.lon - lon).abs() < _sameSpotEpsilon) {
        return i;
      }
    }
    return -1;
  }

  /// Saves [place] (newest first). Re-saving the same spot replaces the old
  /// entry so the name stays up to date. Returns false when the input was
  /// rejected as invalid.
  Future<bool> add(FavoritePlace place) async {
    final existing = indexOfSpot(place.lat, place.lon);
    if (existing >= 0) _places.removeAt(existing);
    _places.insert(0, place);
    if (_places.length > maxEntries) {
      _places.removeRange(maxEntries, _places.length);
    }
    notifyListeners();
    await _persist();
    return true;
  }

  /// Removes the favorite at [lat]/[lon] if present.
  Future<void> removeSpot(double lat, double lon) async {
    final index = indexOfSpot(lat, lon);
    if (index < 0) return;
    _places.removeAt(index);
    notifyListeners();
    await _persist();
  }

  /// Renames the favorite at [lat]/[lon], keeping its position in the list.
  ///
  /// Returns false when there is no such favorite or [newName] is empty after
  /// sanitizing (control characters stripped, trimmed, length-capped) — the
  /// stored name is never replaced by a blank one.
  Future<bool> rename(double lat, double lon, String newName) async {
    final index = indexOfSpot(lat, lon);
    if (index < 0) return false;
    final current = _places[index];
    final renamed = FavoritePlace.create(
      name: newName,
      lat: current.lat,
      lon: current.lon,
    );
    if (renamed == null) return false;
    if (renamed.name == current.name) return true;
    _places[index] = renamed;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _key,
        jsonEncode(_places.map((p) => p.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort: the in-memory list stays correct for this session.
    }
  }
}
