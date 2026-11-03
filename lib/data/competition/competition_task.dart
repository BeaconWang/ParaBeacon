import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'task_polyline.dart';

/// Earth model used by the task geometry (matches XCTrack's `earthModel`).
enum TaskEarthModel { wgs84, faiSphere }

/// Start-of-speed-section timing mode (XCTrack `sss.type`).
enum TaskStartType { race, elapsedTime }

/// Direction the start cylinder is crossed (XCTrack `sss.direction`).
enum TaskStartDirection { enter, exit }

/// Goal geometry (XCTrack `goal.type`).
enum TaskGoalType { line, cylinder }

/// Role a turnpoint plays in the ordered task.
enum TurnpointRole { takeoff, sss, turnpoint, ess }

extension TaskEarthModelX on TaskEarthModel {
  String get wire =>
      this == TaskEarthModel.wgs84 ? 'WGS84' : 'FAI_SPHERE';

  /// XCTSK compact (v2) integer code: 1 = WGS84, 2 = FAI_SPHERE.
  int get code => this == TaskEarthModel.wgs84 ? 1 : 2;

  static TaskEarthModel parse(Object? raw) {
    final s = raw?.toString().toUpperCase();
    if (s == 'WGS84' || s == '1') return TaskEarthModel.wgs84;
    return TaskEarthModel.faiSphere;
  }
}

extension TaskStartTypeX on TaskStartType {
  String get wire =>
      this == TaskStartType.race ? 'RACE' : 'ELAPSED-TIME';

  /// XCTSK compact (v2) integer code: 1 = RACE, 2 = ELAPSED-TIME.
  int get code => this == TaskStartType.race ? 1 : 2;

  static TaskStartType parse(Object? raw) {
    if (raw is num) {
      return raw.toInt() == 2
          ? TaskStartType.elapsedTime
          : TaskStartType.race;
    }
    final s = raw?.toString().toUpperCase().replaceAll('_', '-');
    return s == 'ELAPSED-TIME'
        ? TaskStartType.elapsedTime
        : TaskStartType.race;
  }
}

extension TaskStartDirectionX on TaskStartDirection {
  String get wire => this == TaskStartDirection.enter ? 'ENTER' : 'EXIT';

  /// XCTSK compact (v2) integer code: 1 = ENTER, 2 = EXIT.
  int get code => this == TaskStartDirection.enter ? 1 : 2;

  static TaskStartDirection parse(Object? raw) {
    if (raw is num) {
      return raw.toInt() == 1
          ? TaskStartDirection.enter
          : TaskStartDirection.exit;
    }
    final s = raw?.toString().toUpperCase();
    return s == 'ENTER' ? TaskStartDirection.enter : TaskStartDirection.exit;
  }
}

extension TaskGoalTypeX on TaskGoalType {
  String get wire => this == TaskGoalType.line ? 'LINE' : 'CYLINDER';

  /// XCTSK compact (v2) integer code: 1 = LINE, 2 = CYLINDER.
  int get code => this == TaskGoalType.line ? 1 : 2;

  static TaskGoalType parse(Object? raw) {
    if (raw is num) {
      return raw.toInt() == 1 ? TaskGoalType.line : TaskGoalType.cylinder;
    }
    final s = raw?.toString().toUpperCase();
    return s == 'LINE' ? TaskGoalType.line : TaskGoalType.cylinder;
  }
}

extension TurnpointRoleX on TurnpointRole {
  /// The XCTSK `type` string, or null for a regular turnpoint.
  String? get wire {
    switch (this) {
      case TurnpointRole.takeoff:
        return 'TAKEOFF';
      case TurnpointRole.sss:
        return 'SSS';
      case TurnpointRole.ess:
        return 'ESS';
      case TurnpointRole.turnpoint:
        return null;
    }
  }

  /// XCTSK compact (v2) integer code: 1 = TAKEOFF, 2 = SSS, 3 = ESS.
  /// Returns null for a regular turnpoint (the key is omitted).
  int? get code {
    switch (this) {
      case TurnpointRole.takeoff:
        return 1;
      case TurnpointRole.sss:
        return 2;
      case TurnpointRole.ess:
        return 3;
      case TurnpointRole.turnpoint:
        return null;
    }
  }

  static TurnpointRole parse(Object? raw) {
    if (raw is num) {
      switch (raw.toInt()) {
        case 1:
          return TurnpointRole.takeoff;
        case 2:
          return TurnpointRole.sss;
        case 3:
          return TurnpointRole.ess;
        default:
          return TurnpointRole.turnpoint;
      }
    }
    final s = raw?.toString().toUpperCase();
    switch (s) {
      case 'TAKEOFF':
        return TurnpointRole.takeoff;
      case 'SSS':
        return TurnpointRole.sss;
      case 'ESS':
        return TurnpointRole.ess;
      default:
        return TurnpointRole.turnpoint;
    }
  }
}

/// A named geographic point used as a turnpoint centre.
@immutable
class TaskWaypoint {
  const TaskWaypoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.altitudeM = 0,
    this.description = '',
  });

  final String name;
  final double latitude;
  final double longitude;

  /// Smoothed ground elevation at the waypoint (metres). XCTSK `altSmoothed`.
  final double altitudeM;
  final String description;

  TaskWaypoint copyWith({
    String? name,
    double? latitude,
    double? longitude,
    double? altitudeM,
    String? description,
  }) {
    return TaskWaypoint(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeM: altitudeM ?? this.altitudeM,
      description: description ?? this.description,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'lat': latitude,
    'lon': longitude,
    'altSmoothed': altitudeM,
  };

  static TaskWaypoint? tryParse(Object? raw) {
    if (raw is! Map) return null;
    // Accept both the long XCTSK keys and the short QR aliases.
    final double? latitude;
    final double? longitude;
    if (raw.containsKey('lat') || raw.containsKey('lon')) {
      latitude = _num(raw['lat']);
      longitude = _num(raw['lon']);
    } else {
      latitude = _num(raw['x']);
      longitude = _num(raw['y']);
    }
    if (latitude == null || longitude == null) return null;
    if (!_validLatLon(latitude, longitude)) return null;
    final name = (raw['name'] ?? raw['n'] ?? '').toString();
    final description = (raw['description'] ?? raw['d'] ?? '').toString();
    final alt = _num(raw['altSmoothed'] ?? raw['a']) ?? 0;
    return TaskWaypoint(
      name: _clean(name, 80),
      latitude: latitude,
      longitude: longitude,
      altitudeM: alt.isFinite ? alt : 0,
      description: _clean(description, 200),
    );
  }
}

/// A single cylinder/turnpoint in the ordered task.
@immutable
class Turnpoint {
  const Turnpoint({
    required this.waypoint,
    required this.radiusMeters,
    this.role = TurnpointRole.turnpoint,
  });

  final TaskWaypoint waypoint;
  final double radiusMeters;
  final TurnpointRole role;

  double get latitude => waypoint.latitude;
  double get longitude => waypoint.longitude;
  String get name => waypoint.name;

  Turnpoint copyWith({
    TaskWaypoint? waypoint,
    double? radiusMeters,
    TurnpointRole? role,
  }) {
    return Turnpoint(
      waypoint: waypoint ?? this.waypoint,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      role: role ?? this.role,
    );
  }

  Map<String, Object?> toJson() => {
    if (role.wire != null) 'type': role.wire,
    'radius': radiusMeters,
    'waypoint': waypoint.toJson(),
  };

  /// Compact (v2) turnpoint: `{z, n, d?, t?}` where `z` packs
  /// `lon·1e5, lat·1e5, alt` then `radius` as two polyline segments.
  Map<String, Object?> toCompactJson() {
    final z =
        TaskPolyline.encode([
          (waypoint.longitude * 100000).round(),
          (waypoint.latitude * 100000).round(),
          waypoint.altitudeM.truncate(),
        ]) +
        TaskPolyline.encode([radiusMeters.round()]);
    return {
      'z': z,
      'n': waypoint.name,
      if (waypoint.description.isNotEmpty) 'd': waypoint.description,
      if (role.code != null) 't': role.code,
    };
  }

  static Turnpoint? tryParse(Object? raw) {
    if (raw is! Map) return null;

    // Compact (v2) form: a `z` polyline holds lon/lat/alt + radius.
    final z = raw['z'];
    if (z is String && z.isNotEmpty) {
      final values = TaskPolyline.decode(z);
      if (values.length < 4) return null;
      final longitude = values[0] / 100000.0;
      final latitude = values[1] / 100000.0;
      final alt = values[2].toDouble();
      final radius = values[values.length - 1].toDouble();
      if (!_validLatLon(latitude, longitude)) return null;
      final safeRadius = radius.isFinite && radius >= 1 && radius <= 200000
          ? radius
          : 400.0;
      return Turnpoint(
        waypoint: TaskWaypoint(
          name: _clean((raw['n'] ?? '').toString(), 80),
          latitude: latitude,
          longitude: longitude,
          altitudeM: alt.isFinite ? alt : 0,
          description: _clean((raw['d'] ?? '').toString(), 200),
        ),
        radiusMeters: safeRadius,
        role: TurnpointRoleX.parse(raw['t']),
      );
    }

    final waypoint = TaskWaypoint.tryParse(raw['waypoint'] ?? raw['w'] ?? raw);
    if (waypoint == null) return null;
    final radius = _num(raw['radius'] ?? raw['r']) ?? 400;
    final safeRadius = radius.isFinite && radius >= 1 && radius <= 200000
        ? radius
        : 400.0;
    return Turnpoint(
      waypoint: waypoint,
      radiusMeters: safeRadius,
      role: TurnpointRoleX.parse(raw['type'] ?? raw['t']),
    );
  }
}

/// Start of speed section configuration.
@immutable
class TaskStart {
  const TaskStart({
    this.type = TaskStartType.race,
    this.direction = TaskStartDirection.exit,
    this.timeGates = const [],
  });

  final TaskStartType type;
  final TaskStartDirection direction;

  /// Start-gate open times, seconds since local midnight (ascending).
  final List<int> timeGates;

  TaskStart copyWith({
    TaskStartType? type,
    TaskStartDirection? direction,
    List<int>? timeGates,
  }) {
    return TaskStart(
      type: type ?? this.type,
      direction: direction ?? this.direction,
      timeGates: timeGates ?? this.timeGates,
    );
  }

  Map<String, Object?> toJson() => {
    'type': type.wire,
    'direction': direction.wire,
    'timeGates': timeGates.map(secondsToClock).toList(),
  };

  /// Compact (v2) form: `{t, d, g:["HH:mm:ssZ", …]}`.
  Map<String, Object?> toCompactJson() => {
    't': type.code,
    'd': direction.code,
    'g': timeGates.map(secondsToClockUtc).toList(),
  };

  static TaskStart? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final gatesRaw = raw['timeGates'] ?? raw['g'];
    final gates = <int>[];
    if (gatesRaw is List) {
      for (final g in gatesRaw) {
        final s = clockToSeconds(g?.toString());
        if (s != null) gates.add(s);
      }
    }
    gates.sort();
    return TaskStart(
      type: TaskStartTypeX.parse(raw['type'] ?? raw['t']),
      direction: TaskStartDirectionX.parse(raw['direction'] ?? raw['d']),
      timeGates: gates,
    );
  }
}

/// Goal configuration.
@immutable
class TaskGoal {
  const TaskGoal({this.type = TaskGoalType.cylinder, this.deadlineSeconds});

  final TaskGoalType type;

  /// Task close time, seconds since local midnight, or null when unset.
  final int? deadlineSeconds;

  TaskGoal copyWith({TaskGoalType? type, int? deadlineSeconds, bool clearDeadline = false}) {
    return TaskGoal(
      type: type ?? this.type,
      deadlineSeconds: clearDeadline ? null : (deadlineSeconds ?? this.deadlineSeconds),
    );
  }

  Map<String, Object?> toJson() => {
    'type': type.wire,
    if (deadlineSeconds != null) 'deadline': secondsToClock(deadlineSeconds!),
  };

  /// Compact (v2) form: `{t, d:"HH:mm:ssZ"?}`.
  Map<String, Object?> toCompactJson() => {
    't': type.code,
    if (deadlineSeconds != null) 'd': secondsToClockUtc(deadlineSeconds!),
  };

  static TaskGoal tryParse(Object? raw) {
    if (raw is! Map) return const TaskGoal();
    return TaskGoal(
      type: TaskGoalTypeX.parse(raw['type'] ?? raw['t']),
      deadlineSeconds: clockToSeconds((raw['deadline'] ?? raw['d'])?.toString()),
    );
  }
}

/// A complete XCTrack-compatible competition task (`taskType: CLASSIC`).
@immutable
class CompetitionTask {
  const CompetitionTask({
    this.name = '',
    this.version = 1,
    this.earthModel = TaskEarthModel.wgs84,
    this.turnpoints = const [],
    this.start,
    this.goal = const TaskGoal(),
  });

  /// User-facing task name (not part of the XCTSK schema; kept locally).
  final String name;
  final int version;
  final TaskEarthModel earthModel;
  final List<Turnpoint> turnpoints;
  final TaskStart? start;
  final TaskGoal goal;

  bool get isEmpty => turnpoints.isEmpty;

  int? get sssIndex {
    final i = turnpoints.indexWhere((t) => t.role == TurnpointRole.sss);
    return i < 0 ? null : i;
  }

  int? get essIndex {
    final i = turnpoints.lastIndexWhere((t) => t.role == TurnpointRole.ess);
    return i < 0 ? null : i;
  }

  CompetitionTask copyWith({
    String? name,
    int? version,
    TaskEarthModel? earthModel,
    List<Turnpoint>? turnpoints,
    TaskStart? start,
    bool clearStart = false,
    TaskGoal? goal,
  }) {
    return CompetitionTask(
      name: name ?? this.name,
      version: version ?? this.version,
      earthModel: earthModel ?? this.earthModel,
      turnpoints: turnpoints ?? this.turnpoints,
      start: clearStart ? null : (start ?? this.start),
      goal: goal ?? this.goal,
    );
  }

  /// Serializes to the standard, interoperable XCTSK JSON map.
  Map<String, Object?> toXctsk() {
    return {
      'taskType': 'CLASSIC',
      'version': version,
      'earthModel': earthModel.wire,
      if (name.trim().isNotEmpty) 'name': name.trim(),
      'turnpoints': turnpoints.map((t) => t.toJson()).toList(),
      if (start != null) 'sss': start!.toJson(),
      'goal': goal.toJson(),
    };
  }

  /// Local persistence map (same shape as XCTSK plus the local name).
  Map<String, Object?> toJson() => toXctsk();

  String toXctskString() => jsonEncode(toXctsk());

  /// The compact (version 2) XCTSK map used by XCTrack QR codes: single-letter
  /// keys, integer enums, and polyline-packed turnpoints. This keeps the QR
  /// payload small enough to scan reliably.
  Map<String, Object?> toCompactXctsk() {
    return {
      'taskType': 'CLASSIC',
      'version': 2,
      'e': earthModel.code,
      't': turnpoints.map((t) => t.toCompactJson()).toList(),
      if (start != null) 's': start!.toCompactJson(),
      'g': goal.toCompactJson(),
    };
  }

  /// The scannable task-code payload (`XCTSK:` + minified compact JSON), the
  /// exact form XCTrack renders into a QR code.
  String toTaskCode() => 'XCTSK:${jsonEncode(toCompactXctsk())}';

  /// A full-JSON task code (`XCTSK:` + long form); useful for copy/paste where
  /// size is not a concern and maximum interoperability is wanted.
  String toLongTaskCode() => 'XCTSK:${jsonEncode(toXctsk())}';

  /// Parses any supported task representation: a decoded JSON map, an XCTSK
  /// JSON string, or an `XCTSK:`-prefixed task code. Returns null on failure.
  static CompetitionTask? tryParse(Object? raw) {
    if (raw is CompetitionTask) return raw;
    Object? decoded = raw;
    if (raw is String) {
      var text = raw.trim();
      if (text.isEmpty) return null;
      if (text.startsWith('XCTSK:')) text = text.substring(6).trim();
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        return null;
      }
    }
    if (decoded is! Map) return null;

    final tpRaw = decoded['turnpoints'] ?? decoded['t'];
    if (tpRaw is! List) return null;
    final turnpoints = <Turnpoint>[];
    for (final entry in tpRaw) {
      final tp = Turnpoint.tryParse(entry);
      if (tp != null) turnpoints.add(tp);
      if (turnpoints.length >= 100) break;
    }
    if (turnpoints.isEmpty) return null;

    final versionRaw = _num(decoded['version'] ?? decoded['v']);
    final version = versionRaw == null ? 1 : versionRaw.toInt().clamp(1, 2);

    return CompetitionTask(
      name: (decoded['name'] ?? '').toString().trim(),
      version: version,
      earthModel: TaskEarthModelX.parse(decoded['earthModel'] ?? decoded['e']),
      turnpoints: turnpoints,
      start: TaskStart.tryParse(decoded['sss'] ?? decoded['s']),
      goal: TaskGoal.tryParse(decoded['goal'] ?? decoded['g']),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Formats seconds-since-midnight as `HH:MM:SS`.
String secondsToClock(int seconds) {
  final s = seconds % 86400;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(sec)}';
}

/// Formats seconds-since-midnight as the XCTrack compact `HH:MM:SSZ` form.
String secondsToClockUtc(int seconds) => '${secondsToClock(seconds)}Z';

/// Parses `HH:MM[:SS]` (optionally with a trailing `Z`) into seconds-since-
/// midnight, or null when malformed.
int? clockToSeconds(String? raw) {
  if (raw == null) return null;
  final text = raw.trim().replaceAll('Z', '');
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final s = parts.length == 3 ? int.tryParse(parts[2]) : 0;
  if (h == null || m == null || s == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59 || s < 0 || s > 59) return null;
  return h * 3600 + m * 60 + s;
}

double? _num(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}

bool _validLatLon(double lat, double lon) =>
    lat.isFinite &&
    lon.isFinite &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180;

String _clean(String raw, int limit) {
  final buffer = StringBuffer();
  for (final code in raw.runes) {
    if (code >= 0x20 && code != 0x7f && !(code >= 0x80 && code < 0xa0)) {
      buffer.writeCharCode(code);
    }
  }
  final clean = buffer.toString().trim();
  return clean.length > limit ? clean.substring(0, limit).trim() : clean;
}
