import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../geo_math.dart';
import 'competition_task.dart';
import 'task_optimizer.dart';

@immutable
class CompetitionTaskResult {
  const CompetitionTaskResult({
    required this.taskName,
    required this.finishedAt,
    this.startedAt,
    this.serverTaskOwnerId,
  });

  final String taskName;
  final DateTime? startedAt;
  final DateTime finishedAt;
  final String? serverTaskOwnerId;

  Duration? get elapsed {
    final start = startedAt;
    if (start == null) return null;
    final duration = finishedAt.difference(start);
    return duration.isNegative ? null : duration;
  }

  Map<String, Object?> toJson() => {
    'taskName': taskName,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    if (serverTaskOwnerId != null) 'serverTaskOwnerId': serverTaskOwnerId,
  };

  static CompetitionTaskResult? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final finishedAt = DateTime.tryParse(raw['finishedAt']?.toString() ?? '');
    if (finishedAt == null) return null;
    final startedRaw = raw['startedAt'];
    final startedAt = startedRaw is String
        ? DateTime.tryParse(startedRaw)
        : null;
    final ownerId = raw['serverTaskOwnerId'];
    return CompetitionTaskResult(
      taskName: raw['taskName'] is String ? raw['taskName'] as String : '',
      startedAt: startedAt,
      finishedAt: finishedAt,
      serverTaskOwnerId: ownerId is String && ownerId.isNotEmpty
          ? ownerId
          : null,
    );
  }
}

/// Holds the active competition task, persists its optimized geometry and run
/// state, and tracks the currently selected objective.
///
/// Follows the app-wide singleton `ChangeNotifier` + `SharedPreferences`
/// pattern; widgets and the map listen so task edits and progress repaint live.
class CompetitionTaskStore extends ChangeNotifier {
  CompetitionTaskStore._();

  static final CompetitionTaskStore instance = CompetitionTaskStore._();

  static const String _key = 'pb.competition.task.v1';
  static const String _runKey = 'pb.competition.run.v1';
  static const String _resultsKey = 'pb.competition.results.v1';
  static const String _radiusReductionKey =
      'pb.competition.radiusReductionMeters';
  static const int defaultRadiusReductionMeters = 10;
  static const int minimumRadiusReductionMeters = 0;
  static const int maximumRadiusReductionMeters = 100;

  CompetitionTask? _task;
  String? _serverTaskOwnerId;
  bool _isLocalServerCopy = false;
  int _radiusReductionMeters = defaultRadiusReductionMeters;
  OptimizedTask? _optimized;

  /// Index of the next objective in the task; selecting one manually does not
  /// start the timer or record a result until its cylinder is entered.
  int _reachedCount = 0;
  DateTime? _competitionStartedAt;
  List<CompetitionTaskResult> _pendingResults = [];
  List<CompetitionTaskResult> _results = [];

  bool _loaded = false;
  Future<void>? _loading;

  CompetitionTask? get task => _task;
  OptimizedTask? get optimized => _optimized;
  bool get hasTask => _task != null && !_task!.isEmpty;
  String? get serverTaskOwnerId => _serverTaskOwnerId;
  bool get isCurrentTaskServerSourced =>
      _serverTaskOwnerId != null && !_isLocalServerCopy;
  bool get isCurrentTaskLocalCopy => _isLocalServerCopy;
  bool get canAutoSyncCurrentTask =>
      _serverTaskOwnerId == null && !_isLocalServerCopy;
  bool get isLoaded => _loaded;
  int get reachedCount => _reachedCount;
  int get radiusReductionMeters => _radiusReductionMeters;
  DateTime? get competitionStartedAt => _competitionStartedAt;
  CompetitionTaskResult? get pendingResult =>
      _pendingResults.isEmpty ? null : _pendingResults.last;
  List<CompetitionTaskResult> get pendingResults =>
      List.unmodifiable(_pendingResults);
  List<CompetitionTaskResult> get savedResults => List.unmodifiable(_results);
  bool get isCompetitionFinished =>
      _task != null && _reachedCount >= _task!.turnpoints.length;

  double effectiveRadiusMeters(Turnpoint turnpoint) =>
      TaskOptimizer.effectiveRadiusMeters(
        turnpoint.radiusMeters,
        radiusReductionMeters: _radiusReductionMeters,
      );

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
      _radiusReductionMeters =
          (prefs.getInt(_radiusReductionKey) ?? defaultRadiusReductionMeters)
              .clamp(
                minimumRadiusReductionMeters,
                maximumRadiusReductionMeters,
              );
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final task = CompetitionTask.tryParse(decoded['task']);
          if (task != null) {
            _task = task;
            final ownerId = decoded['serverTaskOwnerId'];
            _serverTaskOwnerId = ownerId is String && ownerId.isNotEmpty
                ? ownerId
                : null;
            _isLocalServerCopy =
                _serverTaskOwnerId != null &&
                decoded['isLocalServerCopy'] == true;
            _optimized = TaskOptimizer.optimize(
              task,
              radiusReductionMeters: _radiusReductionMeters,
            );
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
      final runRaw = prefs.getString(_runKey);
      if (runRaw != null && runRaw.isNotEmpty) {
        try {
          final run = jsonDecode(runRaw);
          if (run is Map) {
            final started = run['startedAt'];
            _competitionStartedAt = started is String
                ? DateTime.tryParse(started)
                : null;
            final pendingRaw = run['pendingResults'];
            if (pendingRaw is List) {
              _pendingResults = pendingRaw
                  .map(CompetitionTaskResult.tryParse)
                  .whereType<CompetitionTaskResult>()
                  .take(100)
                  .toList();
            } else {
              final legacyPending = CompetitionTaskResult.tryParse(
                run['pendingResult'],
              );
              _pendingResults = legacyPending == null ? [] : [legacyPending];
            }
          }
        } on Object {
          _competitionStartedAt = null;
          _pendingResults = [];
        }
      }
      final resultsRaw = prefs.getString(_resultsKey);
      if (resultsRaw != null && resultsRaw.isNotEmpty) {
        try {
          final decodedResults = jsonDecode(resultsRaw);
          if (decodedResults is List) {
            _results = decodedResults
                .map(CompetitionTaskResult.tryParse)
                .whereType<CompetitionTaskResult>()
                .take(100)
                .toList();
          }
        } on Object {
          _results = [];
        }
      }
      notifyListeners();
    } catch (_) {
      _task = null;
      _optimized = null;
      _reachedCount = 0;
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  Future<void> setRadiusReductionMeters(int value) async {
    await load();
    final normalized = value.clamp(
      minimumRadiusReductionMeters,
      maximumRadiusReductionMeters,
    );
    if (_radiusReductionMeters == normalized) return;
    _radiusReductionMeters = normalized;
    final task = _task;
    if (task != null) {
      _optimized = TaskOptimizer.optimize(
        task,
        radiusReductionMeters: normalized,
      );
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_radiusReductionKey, normalized);
    } catch (_) {
      // Keep the updated value for this session if persistence is unavailable.
    }
  }

  /// Replaces the local task. A server-sourced task can only be replaced by
  /// explicitly copying it locally or selecting another server task.
  Future<void> setTask(CompetitionTask? task) async {
    await load();
    if (task != null && isCurrentTaskServerSourced) return;
    await _replaceTask(task, serverTaskOwnerId: null, isLocalServerCopy: false);
  }

  Future<void> setServerTask(
    CompetitionTask task, {
    required String ownerId,
  }) async {
    if (ownerId.isEmpty || task.isEmpty) return;
    await load();
    await _replaceTask(
      task,
      serverTaskOwnerId: ownerId,
      isLocalServerCopy: false,
    );
  }

  Future<void> copyTaskFromServer(
    CompetitionTask task, {
    required String ownerId,
  }) async {
    if (ownerId.isEmpty || task.isEmpty) return;
    await load();
    await _replaceTask(
      task,
      serverTaskOwnerId: ownerId,
      isLocalServerCopy: true,
    );
  }

  Future<void> makeCurrentServerTaskEditableCopy() async {
    await load();
    if (!isCurrentTaskServerSourced) return;
    _isLocalServerCopy = true;
    notifyListeners();
    await _persist();
  }

  Future<void> _replaceTask(
    CompetitionTask? task, {
    required String? serverTaskOwnerId,
    required bool isLocalServerCopy,
  }) async {
    if (task == null || task.isEmpty) {
      _task = null;
      _optimized = null;
      _serverTaskOwnerId = null;
      _isLocalServerCopy = false;
    } else {
      _task = task;
      _optimized = TaskOptimizer.optimize(
        task,
        radiusReductionMeters: _radiusReductionMeters,
      );
      _serverTaskOwnerId = serverTaskOwnerId;
      _isLocalServerCopy = isLocalServerCopy;
    }
    _reachedCount = 0;
    _competitionStartedAt = null;
    notifyListeners();
    await _persist();
  }

  Future<void> clear() => setTask(null);

  // ── Turnpoint editing ──────────────────────────────────────────────────

  Future<void> addTurnpoint(Turnpoint turnpoint) async {
    await load();
    if (isCurrentTaskServerSourced) return;
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
    if (isCurrentTaskServerSourced) return;
    if (task.isEmpty) {
      _task = null;
      _optimized = null;
      _reachedCount = 0;
      _competitionStartedAt = null;
    } else {
      _task = task;
      _optimized = TaskOptimizer.optimize(
        task,
        radiusReductionMeters: _radiusReductionMeters,
      );
      if (_reachedCount > task.turnpoints.length) {
        _reachedCount = task.turnpoints.length;
      }
    }
    notifyListeners();
    await _persist();
  }

  // ── Live navigation ────────────────────────────────────────────────────

  /// Resets the selected objective and starts a fresh competition attempt.
  void resetProgress() {
    if (_reachedCount == 0 && _competitionStartedAt == null) return;
    _reachedCount = 0;
    _competitionStartedAt = null;
    notifyListeners();
    _persist();
  }

  /// Selects the following objective without treating it as physically reached.
  void advance() {
    final task = _task;
    if (task == null || task.turnpoints.isEmpty) return;
    setNextTurnpointIndex(_reachedCount + 1);
  }

  /// Selects the previous objective without stopping an active timer.
  void retreat() {
    if (_reachedCount <= 0) return;
    setNextTurnpointIndex(_reachedCount - 1);
  }

  /// Manually selects the next objective. Reaching the end is only recorded by
  /// entering an End cylinder, not by moving this selection.
  void setNextTurnpointIndex(int index) {
    final task = _task;
    if (task == null || task.isEmpty) return;
    final clamped = index.clamp(0, task.turnpoints.length - 1);
    if (_reachedCount == clamped) return;
    if (_reachedCount >= task.turnpoints.length) {
      _competitionStartedAt = null;
    }
    _reachedCount = clamped;
    notifyListeners();
    _persist();
  }

  Future<void> savePendingResult([CompetitionTaskResult? selected]) async {
    if (_pendingResults.isEmpty) return;
    final CompetitionTaskResult result;
    if (selected == null) {
      result = _pendingResults.removeLast();
    } else {
      final pendingIndex = _pendingResults.indexWhere(
        (candidate) => identical(candidate, selected),
      );
      if (pendingIndex < 0) return;
      result = _pendingResults.removeAt(pendingIndex);
    }
    _results = [result, ..._results].take(100).toList();
    notifyListeners();
    await _persist();
  }

  /// Feeds a live position and advances only after entering the selected
  /// objective's cylinder. Entering Takeoff selects Start; entering Start
  /// starts the timer; entering End completes the attempt.
  bool updatePosition(double latitude, double longitude, {DateTime? at}) {
    final task = _task;
    if (task == null ||
        task.isEmpty ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        _reachedCount >= task.turnpoints.length) {
      return false;
    }
    final index = _reachedCount;
    final turnpoint = task.turnpoints[index];
    final distance = GeoMath.distanceMeters(
      latitude,
      longitude,
      turnpoint.latitude,
      turnpoint.longitude,
    );
    if (distance > effectiveRadiusMeters(turnpoint) + 5) return false;

    final crossedAt = at ?? DateTime.now();
    if (turnpoint.role == TurnpointRole.sss && _competitionStartedAt == null) {
      _competitionStartedAt = crossedAt;
    }
    final isEnd =
        turnpoint.role == TurnpointRole.ess ||
        (index == task.turnpoints.length - 1 &&
            turnpoint.role != TurnpointRole.takeoff &&
            turnpoint.role != TurnpointRole.sss);
    if (isEnd) {
      _reachedCount = task.turnpoints.length;
      _pendingResults.add(
        CompetitionTaskResult(
          taskName: task.name,
          startedAt: _competitionStartedAt,
          finishedAt: crossedAt,
          serverTaskOwnerId: _serverTaskOwnerId,
        ),
      );
      _competitionStartedAt = null;
    } else if (turnpoint.role == TurnpointRole.takeoff) {
      final nextStart = task.turnpoints.indexWhere(
        (candidate) => candidate.role == TurnpointRole.sss,
      );
      _reachedCount = nextStart > index ? nextStart : index + 1;
    } else {
      _reachedCount = index + 1;
    }
    notifyListeners();
    _persist();
    return true;
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
    final pts = TaskOptimizer.optimizeFromStart(
      latitude,
      longitude,
      remaining,
      radiusReductionMeters: _radiusReductionMeters,
    );
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
      radius: effectiveRadiusMeters(target),
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
    final mPerDegLon = mPerDegLat * math.cos(centreLat * math.pi / 180.0).abs();
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
      } else {
        await prefs.setString(
          _key,
          jsonEncode({
            'task': task.toJson(),
            'reachedCount': _reachedCount,
            if (_serverTaskOwnerId != null)
              'serverTaskOwnerId': _serverTaskOwnerId,
            if (_isLocalServerCopy) 'isLocalServerCopy': true,
          }),
        );
      }
      await prefs.setString(
        _runKey,
        jsonEncode({
          if (_competitionStartedAt != null)
            'startedAt': _competitionStartedAt!.toIso8601String(),
          'pendingResults': _pendingResults
              .map((result) => result.toJson())
              .toList(),
        }),
      );
      await prefs.setString(
        _resultsKey,
        jsonEncode(_results.map((result) => result.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort; keep the in-memory task if storage is unavailable.
    }
  }
}
