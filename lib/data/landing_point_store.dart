import 'dart:convert';

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
    this.gpsAccuracyM,
    this.notes = '',
  });

  static const int maxNameLength = 60;
  static const int maxNotesLength = 500;

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double? altitudeM;
  final double? gpsAccuracyM;
  final DateTime createdAt;
  final String notes;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'altitudeM': altitudeM,
    'gpsAccuracyM': gpsAccuracyM,
    'createdAt': createdAt.toIso8601String(),
    'notes': notes,
  };

  static LandingPoint? create({
    required String name,
    required double latitude,
    required double longitude,
    double? altitudeM,
    double? gpsAccuracyM,
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
    final safeAccuracy =
        gpsAccuracyM != null &&
            gpsAccuracyM.isFinite &&
            gpsAccuracyM >= 0 &&
            gpsAccuracyM <= 100000
        ? gpsAccuracyM
        : null;
    return LandingPoint(
      id: _newId(),
      name: cleanName,
      latitude: latitude,
      longitude: longitude,
      altitudeM: safeAltitude,
      gpsAccuracyM: safeAccuracy,
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
    final accuracy = raw['gpsAccuracyM'];
    final notes = raw['notes'];
    final validated = create(
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      altitudeM: altitude is num ? altitude.toDouble() : null,
      gpsAccuracyM: accuracy is num ? accuracy.toDouble() : null,
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
      gpsAccuracyM: validated.gpsAccuracyM,
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
  String? _lastId;
  bool _loaded = false;
  Future<void>? _loading;

  List<LandingPoint> get points => List.unmodifiable(_points);
  LandingPoint? get defaultPoint => _byId(_defaultId);
  LandingPoint? get lastPoint => _byId(_lastId);
  bool get isLoaded => _loaded;

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
      final lastId = decoded['lastId'];
      _defaultId = defaultId is String ? defaultId : null;
      _lastId = lastId is String ? lastId : null;
      _repairReferences();
      if (_points.isNotEmpty || _defaultId != null || _lastId != null) {
        notifyListeners();
      }
    } catch (_) {
      _points.clear();
      _defaultId = null;
      _lastId = null;
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
    _lastId = point.id;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> setDefault(String? id) async {
    await load();
    if (id != null && _byId(id) == null) return;
    if (_defaultId == id) return;
    _defaultId = id;
    notifyListeners();
    await _persist();
  }

  Future<void> setLast(String id) async {
    await load();
    if (_byId(id) == null || _lastId == id) return;
    _lastId = id;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    await load();
    final index = _points.indexWhere((point) => point.id == id);
    if (index < 0) return;
    _points.removeAt(index);
    if (_defaultId == id) _defaultId = null;
    if (_lastId == id) _lastId = _points.isEmpty ? null : _points.first.id;
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
    if (_byId(_lastId) == null) {
      _lastId = _points.isEmpty ? null : _points.first.id;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'points': _points.map((point) => point.toJson()).toList(),
          'defaultId': _defaultId,
          'lastId': _lastId,
        }),
      );
    } catch (_) {
      // Keep the current in-memory collection available if storage is offline.
    }
  }
}
