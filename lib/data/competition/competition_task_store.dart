import 'dart:convert';

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
  /// The first leg connects the current position to the **target cylinder's
  /// entry point** — the nearest point on the next turnpoint's boundary — so
  /// the connection goes *to the target circle* (the checkpoint to reach next)
  /// rather than grazing through it toward the one after. The rest of the
  /// route is then optimized from that entry point through the remaining
  /// cylinders to goal.
  List<(double, double)>? liveRouteToGoal(double latitude, double longitude) {
    final task = _task;
    final index = nextTurnpointIndex;
    if (task == null || index == null) return null;
    final remaining = task.turnpoints.sublist(index);
    if (remaining.isEmpty) return null;

    // Entry point on the target (next) cylinder: the boundary point closest to
    // the current position. When already inside, the entry is the current
    // position itself.
    final target = remaining.first;
    final centreDist = GeoMath.distanceMeters(
      latitude,
      longitude,
      target.latitude,
      target.longitude,
    );
    double entryLat;
    double entryLon;
    if (centreDist <= target.radiusMeters || centreDist < 1.0) {
      entryLat = latitude;
      entryLon = longitude;
    } else {
      final bearing = GeoMath.bearingDegrees(
        latitude,
        longitude,
        target.latitude,
        target.longitude,
      );
      final p = GeoMath.destination(
        latitude,
        longitude,
        bearing,
        centreDist - target.radiusMeters,
      );
      entryLat = p[0];
      entryLon = p[1];
    }

    final out = <(double, double)>[
      (latitude, longitude),
      (entryLat, entryLon),
    ];

    // Optimize the remainder (after the target) from the entry point onward.
    final rest = remaining.sublist(1);
    if (rest.isNotEmpty) {
      final pts = TaskOptimizer.optimizeFromStart(entryLat, entryLon, rest);
      final lats = pts[0];
      final lons = pts[1];
      for (var i = 0; i < lats.length; i++) {
        out.add((lats[i], lons[i]));
      }
    }
    return out;
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
