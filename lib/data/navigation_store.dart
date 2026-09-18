import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flight_data.dart';

@immutable
class Waypoint {
  const Waypoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusM = 100,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusM;

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': latitude,
    'lon': longitude,
    'radiusM': radiusM,
  };

  static Waypoint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final lat = raw['lat'];
    final lon = raw['lon'];
    final radius = raw['radiusM'];
    if (name is! String ||
        name.trim().isEmpty ||
        lat is! num ||
        lon is! num ||
        radius is! num) {
      return null;
    }
    final latitude = lat.toDouble();
    final longitude = lon.toDouble();
    final radiusM = radius.toDouble();
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        !radiusM.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        radiusM < 1 ||
        radiusM > 100000) {
      return null;
    }
    return Waypoint(
      name: name.trim().substring(0, math.min(name.trim().length, 80)),
      latitude: latitude,
      longitude: longitude,
      radiusM: radiusM,
    );
  }
}

@immutable
class NavigationTask {
  const NavigationTask({required this.name, required this.waypoints});

  final String name;
  final List<Waypoint> waypoints;

  bool get isValid => waypoints.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'name': name,
    'waypoints': waypoints.map((w) => w.toJson()).toList(),
  };

  static NavigationTask? fromJson(Object? raw) {
    if (raw is! Map || raw['waypoints'] is! List) return null;
    final points = <Waypoint>[];
    for (final item in raw['waypoints'] as List) {
      final point = Waypoint.fromJson(item);
      if (point != null) points.add(point);
      if (points.length >= 100) break;
    }
    if (points.isEmpty) return null;
    final rawName = raw['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim().substring(0, math.min(rawName.trim().length, 80))
        : 'Task';
    return NavigationTask(name: name, waypoints: List.unmodifiable(points));
  }
}

@immutable
class NavigationSnapshot {
  const NavigationSnapshot({
    this.task,
    this.activeIndex = 0,
    this.distanceM,
    this.bearingDeg,
    this.remainingM,
    this.arrived = false,
    this.hasFix = false,
  });

  final NavigationTask? task;
  final int activeIndex;
  final double? distanceM;
  final double? bearingDeg;
  final double? remainingM;
  final bool arrived;
  final bool hasFix;

  Waypoint? get target => task != null && activeIndex < task!.waypoints.length
      ? task!.waypoints[activeIndex]
      : null;
}

/// Stores a pilot's task and calculates live target navigation values.
///
/// The store deliberately owns all bearing/distance calculations so controls,
/// map layers and future alert rules use the same navigation result.
class NavigationStore extends ChangeNotifier {
  NavigationStore._();
  static final NavigationStore instance = NavigationStore._();

  static const _key = 'pb.navigation.task.v1';

  NavigationTask? _task;
  int _activeIndex = 0;
  NavigationSnapshot _snapshot = const NavigationSnapshot();

  NavigationTask? get task => _task;
  int get activeIndex => _activeIndex;
  NavigationSnapshot get snapshot => _snapshot;
  Waypoint? get target => _snapshot.target;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      final task = NavigationTask.fromJson(decoded);
      if (task == null) return;
      _task = task;
      _activeIndex = 0;
      _rebuildSnapshot();
      notifyListeners();
    } catch (_) {
      // Corrupt local task data must not prevent the instrument from starting.
    }
  }

  Future<void> setTask(NavigationTask? task) async {
    _task = task;
    _activeIndex = 0;
    _rebuildSnapshot();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (task == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(task.toJson()));
      }
    } catch (_) {
      // Best effort; the active task remains available in memory.
    }
  }

  void clearTask() => unawaited(setTask(null));

  void setActiveIndex(int index) {
    final task = _task;
    if (task == null || task.waypoints.isEmpty) return;
    final next = index.clamp(0, task.waypoints.length - 1);
    if (_activeIndex == next) return;
    _activeIndex = next;
    _rebuildSnapshot();
    notifyListeners();
  }

  /// Updates live distance and bearing from the unified flight-data snapshot.
  void update(FlightData data) {
    final task = _task;
    if (task == null || !data.hasFix) {
      if (_snapshot.hasFix || _snapshot.task != task) {
        _snapshot = NavigationSnapshot(task: task, activeIndex: _activeIndex);
        notifyListeners();
      }
      return;
    }

    var index = _activeIndex;
    var distance = _distanceM(
      data.latitude,
      data.longitude,
      task.waypoints[index].latitude,
      task.waypoints[index].longitude,
    );
    if (distance <= task.waypoints[index].radiusM &&
        index < task.waypoints.length - 1) {
      index++;
      _activeIndex = index;
      distance = _distanceM(
        data.latitude,
        data.longitude,
        task.waypoints[index].latitude,
        task.waypoints[index].longitude,
      );
    }

    final target = task.waypoints[index];
    final remaining = distance + _remainingLegs(task, index);
    _snapshot = NavigationSnapshot(
      task: task,
      activeIndex: index,
      distanceM: distance,
      bearingDeg: _bearingDeg(
        data.latitude,
        data.longitude,
        target.latitude,
        target.longitude,
      ),
      remainingM: remaining,
      arrived: distance <= target.radiusM && index == task.waypoints.length - 1,
      hasFix: true,
    );
    notifyListeners();
  }

  void _rebuildSnapshot() {
    _snapshot = NavigationSnapshot(task: _task, activeIndex: _activeIndex);
  }

  double _remainingLegs(NavigationTask task, int fromIndex) {
    var total = 0.0;
    for (var i = fromIndex; i < task.waypoints.length - 1; i++) {
      total += _distanceM(
        task.waypoints[i].latitude,
        task.waypoints[i].longitude,
        task.waypoints[i + 1].latitude,
        task.waypoints[i + 1].longitude,
      );
    }
    return total;
  }

  static double _distanceM(double lat1, double lon1, double lat2, double lon2) {
    const earthM = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return earthM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _bearingDeg(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x =
        math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
