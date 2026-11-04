import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../geo_math.dart';
import 'competition_task.dart';
import 'task_optimizer.dart';

/// Holds the single active competition task, persists it, caches its optimized
/// geometry, and tracks live navigation progress (which turnpoint is next).
///
/// Follows the app-wide singleton `ChangeNotifier` + `SharedPreferences`
/// pattern (see [LandingPointStore]); widgets and the map listen to it so edits
/// and progress repaint live.
class CompetitionTaskStore extends ChangeNotifier {
  CompetitionTaskStore._();

  static final CompetitionTaskStore instance = CompetitionTaskStore._();

  static const String _key = 'pb.competition.task.v1';

  CompetitionTask? _task;
  OptimizedTask? _optimized;

  /// Number of turnpoints already achieved in the current flight. The "next"
  /// turnpoint to navigate to is [reachedCount] (when < turnpoint count).
  int _reachedCount = 0;

  bool _loaded = false;
  Future<void>? _loading;

  CompetitionTask? get task => _task;
  OptimizedTask? get optimized => _optimized;
  bool get hasTask => _task != null && !_task!.isEmpty;
  bool get isLoaded => _loaded;
  int get reachedCount => _reachedCount;

  /// Index of the next turnpoint to reach, or null when the task is complete
  /// or empty.
  int? get nextTurnpointIndex {
    final task = _task;
    if (task == null || task.isEmpty) return null;
    if (_reachedCount >= task.turnpoints.length) return null;
    return _reachedCount;
  }

  Turnpoint? get nextTurnpoint {
    final index = nextTurnpointIndex;
    if (index == null) return null;
    return _task!.turnpoints[index];
  }

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final task = CompetitionTask.tryParse(decoded['task']);
          if (task != null) {
            _task = task;
            _optimized = TaskOptimizer.optimize(task);
          }
          final reached = decoded['reachedCount'];
          if (reached is num) {
            _reachedCount = reached.toInt().clamp(
              0,
              _task?.turnpoints.length ?? 0,
            );
          }
        }
      }
      if (_task != null) notifyListeners();
    } catch (_) {
      _task = null;
      _optimized = null;
      _reachedCount = 0;
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  /// Replaces the active task (or clears it when [task] is null).
  Future<void> setTask(CompetitionTask? task) async {
    await load();
    if (task == null || task.isEmpty) {
      _task = null;
      _optimized = null;
    } else {
      _task = task;
      _optimized = TaskOptimizer.optimize(task);
    }
    _reachedCount = 0;
    notifyListeners();
    await _persist();
  }

  Future<void> clear() => setTask(null);

  // ── Turnpoint editing ──────────────────────────────────────────────────

  Future<void> addTurnpoint(Turnpoint turnpoint) async {
    await load();
    final current = _task ?? const CompetitionTask();
    final updated = [...current.turnpoints, turnpoint];
    await _updateTask(current.copyWith(turnpoints: updated));
  }

  Future<void> updateTurnpoint(int index, Turnpoint turnpoint) async {
    await load();
    final current = _task;
    if (current == null || index < 0 || index >= current.turnpoints.length) {
      return;
    }
    final updated = [...current.turnpoints];
    updated[index] = turnpoint;
    await _updateTask(current.copyWith(turnpoints: updated));
  }

  Future<void> removeTurnpoint(int index) async {
    await load();
    final current = _task;
    if (current == null || index < 0 || index >= current.turnpoints.length) {
      return;
    }
    final updated = [...current.turnpoints]..removeAt(index);
    await _updateTask(current.copyWith(turnpoints: updated));
  }

  Future<void> moveTurnpoint(int oldIndex, int newIndex) async {
    await load();
    final current = _task;
    if (current == null) return;
    final updated = [...current.turnpoints];
    if (oldIndex < 0 || oldIndex >= updated.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target > updated.length - 1) target = updated.length - 1;
    final item = updated.removeAt(oldIndex);
    updated.insert(target, item);
    await _updateTask(current.copyWith(turnpoints: updated));
  }

  /// Assigns a role to a turnpoint, enforcing single SSS/TAKEOFF where needed.
  Future<void> setTurnpointRole(int index, TurnpointRole role) async {
    await load();
    final current = _task;
    if (current == null || index < 0 || index >= current.turnpoints.length) {
      return;
    }
    final updated = [...current.turnpoints];
    // SSS and TAKEOFF are unique; demote any existing holder.
    if (role == TurnpointRole.sss || role == TurnpointRole.takeoff) {
      for (var i = 0; i < updated.length; i++) {
        if (i != index && updated[i].role == role) {
          updated[i] = updated[i].copyWith(role: TurnpointRole.turnpoint);
        }
      }
    }
    updated[index] = updated[index].copyWith(role: role);
    var next = current.copyWith(turnpoints: updated);
    // Make sure a start config exists once an SSS is defined.
    if (role == TurnpointRole.sss && next.start == null) {
      next = next.copyWith(start: const TaskStart());
    }
    await _updateTask(next);
  }

  Future<void> setStart(TaskStart? start) async {
    await load();
    final current = _task;
    if (current == null) return;
    await _updateTask(
      current.copyWith(start: start, clearStart: start == null),
    );
  }

  Future<void> setGoal(TaskGoal goal) async {
    await load();
    final current = _task;
    if (current == null) return;
    await _updateTask(current.copyWith(goal: goal));
  }

  Future<void> setEarthModel(TaskEarthModel model) async {
    await load();
    final current = _task;
    if (current == null) return;
    await _updateTask(current.copyWith(earthModel: model));
  }

  Future<void> setName(String name) async {
    await load();
    final current = _task;
    if (current == null) return;
    await _updateTask(current.copyWith(name: name));
  }

  Future<void> _updateTask(CompetitionTask task) async {
    if (task.isEmpty) {
      _task = null;
      _optimized = null;
      _reachedCount = 0;
    } else {
      _task = task;
      _optimized = TaskOptimizer.optimize(task);
      if (_reachedCount > task.turnpoints.length) {
        _reachedCount = task.turnpoints.length;
      }
    }
    notifyListeners();
    await _persist();
  }

  // ── Live navigation ────────────────────────────────────────────────────

  /// Resets progress to the first turnpoint.
  void resetProgress() {
    if (_reachedCount == 0) return;
    _reachedCount = 0;
    notifyListeners();
    _persist();
  }

  /// Manually marks the next turnpoint as reached.
  void advance() {
    final task = _task;
    if (task == null) return;
    if (_reachedCount >= task.turnpoints.length) return;
    _reachedCount++;
    notifyListeners();
    _persist();
  }

  /// Sets the next target to the turnpoint closest to [latitude]/[longitude],
  /// marking every earlier turnpoint as already reached.
  ///
  /// Used at takeoff: when a task is loaded, the nearest turnpoint to the
  /// launch position becomes the current target so navigation starts from the
  /// relevant part of the course instead of always the first turnpoint.
  /// No-op when there is no task or the chosen target is already current.
  void setProgressToNearest(double latitude, double longitude) {
    final task = _task;
    if (task == null || task.isEmpty) return;
    if (!latitude.isFinite || !longitude.isFinite) return;
    var bestIndex = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < task.turnpoints.length; i++) {
      final tp = task.turnpoints[i];
      final d = GeoMath.distanceMeters(
        latitude,
        longitude,
        tp.latitude,
        tp.longitude,
      );
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }
    if (_reachedCount == bestIndex) return;
    _reachedCount = bestIndex;
    notifyListeners();
    _persist();
  }

  /// Feeds a live position; auto-advances when the pilot enters the next
  /// turnpoint's cylinder. Returns true when progress changed.
  bool updatePosition(double latitude, double longitude) {
    final task = _task;
    if (task == null || task.isEmpty) return false;
    if (_reachedCount >= task.turnpoints.length) return false;
    final tp = task.turnpoints[_reachedCount];
    final distance = GeoMath.distanceMeters(
      latitude,
      longitude,
      tp.latitude,
      tp.longitude,
    );
    // Entry-based crossing: inside the cylinder counts as reached. A small
    // tolerance absorbs GPS noise near the edge.
    if (distance <= tp.radiusMeters + 5) {
      _reachedCount++;
      notifyListeners();
      _persist();
      return true;
    }
    return false;
  }

  /// Real-time shortest route from [latitude]/[longitude] through the
  /// remaining turnpoints to goal, as an ordered list of `(lat, lon)` points
  /// beginning at the given position and ending at the goal touch point.
  ///
  /// Returns null when there is no task or the task is already complete.
  ///
  /// The whole route — including the first leg from the current position to the
  /// target (next) turnpoint — is the globally shortest path across the entire
  /// remaining course (re-optimized from the live position via
  /// [TaskOptimizer.optimizeFromStart]). The first leg therefore crosses the
  /// target cylinder exactly where the shortest finish line passes through it,
  /// while still terminating on that cylinder's boundary (see
  /// [_targetCylinderCrossing]) so the connection visibly goes *to the target
  /// circle* rather than piercing through toward the following turnpoint.
  List<(double, double)>? liveRouteToGoal(double latitude, double longitude) {
    final task = _task;
    final index = nextTurnpointIndex;
    if (task == null || index == null) return null;
    final remaining = task.turnpoints.sublist(index);
    if (remaining.isEmpty) return null;

    // Global shortest route from the live position through every remaining
    // cylinder's optimal touch point to goal.
    final pts = TaskOptimizer.optimizeFromStart(latitude, longitude, remaining);
    final lats = pts[0];
    final lons = pts[1];
    if (lats.isEmpty) return null;

    // Where that shortest path crosses the target (next) cylinder, snapped to
    // the boundary so the drawn leg ends on the circle.
    final target = remaining.first;
    final crossing = _targetCylinderCrossing(
      fromLat: latitude,
      fromLon: longitude,
      centreLat: target.latitude,
      centreLon: target.longitude,
      radius: target.radiusMeters,
      nextLat: lats.length > 1 ? lats[1] : null,
      nextLon: lons.length > 1 ? lons[1] : null,
      optimizedLat: lats[0],
      optimizedLon: lons[0],
    );

    final out = <(double, double)>[(latitude, longitude), crossing];
    for (var i = 1; i < lats.length; i++) {
      out.add((lats[i], lons[i]));
    }
    return out;
  }

  /// The point on the target cylinder's boundary where the globally shortest
  /// path crosses it, given the current position and the next point on that
  /// path. When the straight segment current → next passes through the
  /// cylinder the crossing is the near (entry) intersection; otherwise it is
  /// the graze point on the arc facing both the current position and the
  /// onward leg. Falls back to the optimizer's touch point only in degenerate
  /// cases. Returns the current position when already inside the cylinder.
  (double, double) _targetCylinderCrossing({
    required double fromLat,
    required double fromLon,
    required double centreLat,
    required double centreLon,
    required double radius,
    required double? nextLat,
    required double? nextLon,
    required double optimizedLat,
    required double optimizedLon,
  }) {
    if (radius <= 0) return (centreLat, centreLon);
    final centreDist = GeoMath.distanceMeters(
      fromLat,
      fromLon,
      centreLat,
      centreLon,
    );
    if (centreDist <= radius) return (fromLat, fromLon);

    // Local planar frame centred on the cylinder (metres).
    const mPerDegLat = 111320.0;
    final mPerDegLon =
        mPerDegLat * math.cos(centreLat * math.pi / 180.0).abs();
    final lonScale = mPerDegLon < 1e-6 ? 1e-6 : mPerDegLon;
    double px(double lon) => (lon - centreLon) * lonScale;
    double py(double lat) => (lat - centreLat) * mPerDegLat;
    (double, double) toLatLon(double x, double y) =>
        (centreLat + y / mPerDegLat, centreLon + x / lonScale);

    final ax = px(fromLon);
    final ay = py(fromLat);

    // No onward leg (target is the goal): nearest boundary point to current.
    if (nextLat == null || nextLon == null) {
      final len = math.sqrt(ax * ax + ay * ay);
      if (len < 1e-6) return (fromLat, fromLon);
      return toLatLon(ax / len * radius, ay / len * radius);
    }

    final bx = px(nextLon);
    final by = py(nextLat);

    // Straight segment current → next intersects the circle → enter at the
    // near intersection (the shortest path goes straight through).
    final dx = bx - ax;
    final dy = by - ay;
    final segLen2 = dx * dx + dy * dy;
    if (segLen2 > 1e-9) {
      final bb = 2 * (ax * dx + ay * dy);
      final cc = ax * ax + ay * ay - radius * radius;
      final disc = bb * bb - 4 * segLen2 * cc;
      if (disc >= 0) {
        final t = (-bb - math.sqrt(disc)) / (2 * segLen2);
        if (t >= 0 && t <= 1) return toLatLon(ax + t * dx, ay + t * dy);
      }
    }

    // Otherwise graze: touch point on the arc bisecting the directions to the
    // current position and the onward leg.
    final la = math.sqrt(ax * ax + ay * ay);
    final lb = math.sqrt(bx * bx + by * by);
    final gx = (la > 1e-6 ? ax / la : 0.0) + (lb > 1e-6 ? bx / lb : 0.0);
    final gy = (la > 1e-6 ? ay / la : 0.0) + (lb > 1e-6 ? by / lb : 0.0);
    final gl = math.sqrt(gx * gx + gy * gy);
    if (gl < 1e-6) return (optimizedLat, optimizedLon);
    return toLatLon(gx / gl * radius, gy / gl * radius);
  }

  /// Optimized distance (metres) from [latitude]/[longitude] to goal, routed
  /// through the remaining turnpoints. Null when no task/next turnpoint.
  double? remainingDistanceToGoal(double latitude, double longitude) {
    final task = _task;
    final optimized = _optimized;
    final index = nextTurnpointIndex;
    if (task == null || optimized == null || index == null) return null;
    if (optimized.isEmpty) return null;
    // Distance to the next turnpoint's optimized touch point …
    final toNext = GeoMath.distanceMeters(
      latitude,
      longitude,
      optimized.optimizedLat[index],
      optimized.optimizedLon[index],
    );
    // … plus the optimized route from there to goal.
    return toNext + optimized.cumulativeToGoalM[index];
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final task = _task;
      if (task == null) {
        await prefs.remove(_key);
        return;
      }
      await prefs.setString(
        _key,
        jsonEncode({'task': task.toJson(), 'reachedCount': _reachedCount}),
      );
    } catch (_) {
      // Best-effort; keep the in-memory task if storage is unavailable.
    }
  }
}
