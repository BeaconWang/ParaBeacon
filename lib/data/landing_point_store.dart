import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class LandingPoint {
  const LandingPoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.altitudeM,
    this.notes = '',
  });

  static const int maxNameLength = 60;
  static const int maxNotesLength = 500;

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double? altitudeM;
  final DateTime createdAt;
  final String notes;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'altitudeM': altitudeM,
    'createdAt': createdAt.toIso8601String(),
    'notes': notes,
  };

  static LandingPoint? create({
    required String name,
    required double latitude,
    required double longitude,
    double? altitudeM,
    DateTime? createdAt,
    String notes = '',
  }) {
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    final cleanName = _sanitize(name, maxNameLength);
    if (cleanName.isEmpty) return null;
    final safeAltitude =
        altitudeM != null &&
            altitudeM.isFinite &&
            altitudeM >= -12000 &&
            altitudeM <= 100000
        ? altitudeM
        : null;
    return LandingPoint(
      id: _newId(),
      name: cleanName,
      latitude: latitude,
      longitude: longitude,
      altitudeM: safeAltitude,
      createdAt: createdAt ?? DateTime.now(),
      notes: _sanitize(notes, maxNotesLength),
    );
  }

  static LandingPoint? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final latitude = raw['latitude'];
    final longitude = raw['longitude'];
    final createdAt = raw['createdAt'];
    if (id is! String || id.isEmpty || id.length > 100) return null;
    if (name is! String || latitude is! num || longitude is! num) return null;
    if (createdAt is! String) return null;
    final parsedDate = DateTime.tryParse(createdAt);
    if (parsedDate == null) return null;
    final altitude = raw['altitudeM'];
    final notes = raw['notes'];
    final validated = create(
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      altitudeM: altitude is num ? altitude.toDouble() : null,
      createdAt: parsedDate,
      notes: notes is String ? notes : '',
    );
    if (validated == null) return null;
    return LandingPoint(
      id: id,
      name: validated.name,
      latitude: validated.latitude,
      longitude: validated.longitude,
      altitudeM: validated.altitudeM,
      createdAt: validated.createdAt,
      notes: validated.notes,
    );
  }

  static int _nextId = 0;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  static String _sanitize(String raw, int limit) {
    final buffer = StringBuffer();
    for (final code in raw.runes) {
      if (code >= 0x20 && code != 0x7f && !(code >= 0x80 && code < 0xa0)) {
        buffer.writeCharCode(code);
      }
    }
    final clean = buffer.toString().trim();
    return clean.length > limit ? clean.substring(0, limit).trim() : clean;
  }
}

class LandingPointStore extends ChangeNotifier {
  LandingPointStore._();

  static final LandingPointStore instance = LandingPointStore._();
  static const String _key = 'pb.landingPoints.v1';
  static const int maxEntries = 100;

  final List<LandingPoint> _points = [];
  String? _defaultId;
  bool _loaded = false;
  Future<void>? _loading;

  List<LandingPoint> get points => List.unmodifiable(_points);
  LandingPoint? get defaultPoint => _byId(_defaultId);
  bool get isLoaded => _loaded;

  LandingPoint? nearestPointTo(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    LandingPoint? nearest;
    var shortestDistance = double.infinity;
    for (final point in _points) {
      final distance = _distanceMeters(
        latitude,
        longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearest = point;
      }
    }
    return nearest;
  }

  static double _distanceMeters(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusMeters = 6371008.8;
    final latA = latitudeA * math.pi / 180;
    final latB = latitudeB * math.pi / 180;
    final deltaLat = (latitudeB - latitudeA) * math.pi / 180;
    final deltaLon = (longitudeB - longitudeA) * math.pi / 180;
    final sinHalfLat = math.sin(deltaLat / 2);
    final sinHalfLon = math.sin(deltaLon / 2);
    final haversine =
        sinHalfLat * sinHalfLat +
        math.cos(latA) * math.cos(latB) * sinHalfLon * sinHalfLon;
    final bounded = haversine.clamp(0.0, 1.0);
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(bounded), math.sqrt(1 - bounded));
  }

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final entries = decoded['points'];
      if (entries is List) {
        for (final entry in entries) {
          final point = LandingPoint.tryParse(entry);
          if (point == null || _points.any((saved) => saved.id == point.id)) {
            continue;
          }
          _points.add(point);
          if (_points.length >= maxEntries) break;
        }
      }
      final defaultId = decoded['defaultId'];
      _defaultId = defaultId is String ? defaultId : null;
      _repairReferences();
      if (_points.isNotEmpty || _defaultId != null) {
        notifyListeners();
      }
    } catch (_) {
      _points.clear();
      _defaultId = null;
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  Future<bool> add(LandingPoint point) async {
    await load();
    if (_points.any((saved) => saved.id == point.id)) return false;
    _points.insert(0, point);
    if (_points.length > maxEntries) {
      final removed = _points.removeLast();
      if (_defaultId == removed.id) _defaultId = null;
    }
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> update(LandingPoint point) async {
    await load();
    final index = _points.indexWhere((saved) => saved.id == point.id);
    if (index < 0) return false;
    _points[index] = point;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> applyImportMerge(
    List<LandingPoint> mergedPoints, {
    String? defaultId,
  }) async {
    await load();
    if (mergedPoints.length > maxEntries) {
      throw ArgumentError.value(
        mergedPoints.length,
        'mergedPoints',
        'Too many entries.',
      );
    }
    final ids = mergedPoints.map((point) => point.id).toSet();
    final names = mergedPoints.map((point) => _nameKey(point.name)).toSet();
    if (ids.length != mergedPoints.length ||
        (defaultId != null && !ids.contains(defaultId)) ||
        (_defaultId != null && defaultId == null) ||
        _points.any((point) => !names.contains(_nameKey(point.name)))) {
      throw ArgumentError('Import merge must preserve existing point names.');
    }
    _points
      ..clear()
      ..addAll(mergedPoints);
    _defaultId = defaultId;
    notifyListeners();
    await _persist();
  }

  String _nameKey(String name) => name.trim().toLowerCase();

  Future<void> setDefault(String? id) async {
    await load();
    if (id != null && _byId(id) == null) return;
    if (_defaultId == id) return;
    _defaultId = id;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    await load();
    final index = _points.indexWhere((point) => point.id == id);
    if (index < 0) return;
    _points.removeAt(index);
    if (_defaultId == id) _defaultId = null;
    notifyListeners();
    await _persist();
  }

  LandingPoint? _byId(String? id) {
    if (id == null) return null;
    for (final point in _points) {
      if (point.id == id) return point;
    }
    return null;
  }

  void _repairReferences() {
    if (_byId(_defaultId) == null) _defaultId = null;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'points': _points.map((point) => point.toJson()).toList(),
          'defaultId': _defaultId,
        }),
      );
    } catch (_) {
      // Keep the current in-memory collection available if storage is offline.
    }
  }
}
