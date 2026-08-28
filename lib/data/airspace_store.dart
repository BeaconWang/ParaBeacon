import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Severity tiers used to prioritise which airspaces are drawn and how boldly.
enum AirspaceSeverity {
  /// Class A/B/C/D/Prohibited/Restricted/Danger — always relevant.
  high,

  /// Class E/TMZ/RMZ and similar — moderate.
  medium,

  /// Class G / info / gliding sectors — low.
  low,
}

/// An immutable airspace volume: a horizontal polygon plus a vertical band.
///
/// Altitudes are stored in meters MSL. `null` floor/ceiling means
/// "ground"/"unlimited" respectively.
@immutable
class Airspace {
  const Airspace({
    required this.name,
    required this.polygon,
    required this.severity,
    this.floorM,
    this.ceilingM,
  });

  final String name;

  /// Boundary points as `[lat, lon]` pairs (WGS-84), at least 3 for a polygon.
  final List<List<double>> polygon;

  final AirspaceSeverity severity;

  /// Lower / upper altitude bounds in meters MSL (null = ground / unlimited).
  final double? floorM;
  final double? ceilingM;

  /// Whether [altMslM] falls inside this airspace's vertical band.
  bool containsAltitude(double altMslM) {
    if (floorM != null && altMslM < floorM!) return false;
    if (ceilingM != null && altMslM > ceilingM!) return false;
    return true;
  }
}

/// The proximity of the aircraft to a single [airspace] at the current fix.
@immutable
class AirspaceProximity {
  const AirspaceProximity({
    required this.airspace,
    required this.horizontalM,
    required this.verticalM,
    required this.inside,
  });

  final Airspace airspace;

  /// Horizontal distance to the polygon boundary (0 when inside), meters.
  final double horizontalM;

  /// Vertical distance to the nearest band edge (0 when within band), meters.
  final double verticalM;

  /// True when the aircraft is inside the polygon *and* within the band.
  final bool inside;
}

/// Loads and holds airspace volumes for the Map control (singleton).
///
/// Data-driven and empty-safe: the current project ships no bundled airspace,
/// so by default the store is empty and the Map control's airspace layer simply
/// renders nothing. Pilots can drop an OpenAir file at
/// `<app-documents>/airspace/airspace.txt` (or call [loadOpenAirString]) to
/// populate it. A minimal OpenAir subset (`AC`/`AN`/`AL`/`AH`/`DP`) is parsed.
///
/// The store also computes [proximityStream]: on each [updatePosition] it
/// derives per-airspace horizontal/vertical distance so the Map control can
/// colour boundaries (inside = red, near = orange, far = grey).
class AirspaceStore extends ChangeNotifier {
  AirspaceStore._();
  static final AirspaceStore instance = AirspaceStore._();

  final List<Airspace> _all = [];
  List<Airspace> get all => List.unmodifiable(_all);
  bool get isEmpty => _all.isEmpty;

  final StreamController<List<AirspaceProximity>> _proximity =
      StreamController<List<AirspaceProximity>>.broadcast();
  Stream<List<AirspaceProximity>> get proximityStream => _proximity.stream;

  List<AirspaceProximity> _lastProximity = const [];
  List<AirspaceProximity> get lastProximity => _lastProximity;

  bool _loaded = false;

  /// Loads airspace from `<app-documents>/airspace/airspace.txt` if present.
  /// Idempotent and best-effort — a missing file just leaves the store empty.
  Future<void> warmup() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final f = File(p.join(docs.path, 'airspace', 'airspace.txt'));
      if (await f.exists()) {
        loadOpenAirString(await f.readAsString());
      }
    } catch (_) {
      // Ignore: keep the store empty.
    }
  }

  /// Replaces the current airspaces with the ones parsed from an OpenAir
  /// [content] string. Notifies listeners on success.
  void loadOpenAirString(String content) {
    final parsed = _parseOpenAir(content);
    _all
      ..clear()
      ..addAll(parsed);
    notifyListeners();
  }

  /// Recomputes proximity for [latMsl] at altitude [altMslM] and emits it.
  void updatePosition(double lat, double lon, double altMslM) {
    if (_all.isEmpty) {
      if (_lastProximity.isNotEmpty) {
        _lastProximity = const [];
        _proximity.add(_lastProximity);
      }
      return;
    }
    final out = <AirspaceProximity>[];
    for (final a in _all) {
      if (a.polygon.length < 3) continue;
      final horiz = _distanceToPolygonM(lat, lon, a.polygon);
      final insideHoriz = horiz <= 0;
      final withinBand = a.containsAltitude(altMslM);
      double vert;
      if (withinBand) {
        vert = 0;
      } else if (a.floorM != null && altMslM < a.floorM!) {
        vert = a.floorM! - altMslM;
      } else if (a.ceilingM != null && altMslM > a.ceilingM!) {
        vert = altMslM - a.ceilingM!;
      } else {
        vert = 0;
      }
      out.add(AirspaceProximity(
        airspace: a,
        horizontalM: insideHoriz ? 0 : horiz,
        verticalM: vert,
        inside: insideHoriz && withinBand,
      ));
    }
    _lastProximity = out;
    _proximity.add(out);
  }

  @override
  void dispose() {
    _proximity.close();
    super.dispose();
  }

  // ── OpenAir parsing (minimal subset) ──────────────────────────────────────
  //
  // Supported records: AC (class), AN (name), AL (floor), AH (ceiling),
  // DP (polygon point "lat lon" in DD:MM:SS N/E). Arc/circle records (V/DC/DB)
  // are ignored — such airspaces simply come out as their listed DP points.
  static List<Airspace> _parseOpenAir(String content) {
    final out = <Airspace>[];
    String? name;
    String klass = '';
    double? floor;
    double? ceil;
    var poly = <List<double>>[];

    void flush() {
      if (poly.length >= 3) {
        out.add(Airspace(
          name: name ?? klass,
          polygon: poly,
          severity: _severityForClass(klass),
          floorM: floor,
          ceilingM: ceil,
        ));
      }
      name = null;
      klass = '';
      floor = null;
      ceil = null;
      poly = <List<double>>[];
    }

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('*') || line.startsWith('#')) {
        continue;
      }
      final sp = line.indexOf(' ');
      final tag = sp < 0 ? line : line.substring(0, sp);
      final rest = sp < 0 ? '' : line.substring(sp + 1).trim();
      switch (tag.toUpperCase()) {
        case 'AC':
          // A new AC starts a new airspace block.
          if (poly.isNotEmpty || name != null) flush();
          klass = rest;
          break;
        case 'AN':
          name = rest;
          break;
        case 'AL':
          floor = _parseAltitudeM(rest);
          break;
        case 'AH':
          ceil = _parseAltitudeM(rest);
          break;
        case 'DP':
          final pt = _parseCoord(rest);
          if (pt != null) poly.add(pt);
          break;
        default:
          break; // V / DC / DB / DA / SP / SB ... ignored
      }
    }
    flush();
    return out;
  }

  static AirspaceSeverity _severityForClass(String klass) {
    final k = klass.toUpperCase();
    if (k.startsWith('A') ||
        k.startsWith('B') ||
        k.startsWith('C') ||
        k.startsWith('D') ||
        k.contains('P') || // Prohibited
        k.contains('R') || // Restricted
        k.contains('Q') || // Danger
        k.contains('CTR')) {
      return AirspaceSeverity.high;
    }
    if (k.startsWith('E') || k.contains('TMZ') || k.contains('RMZ')) {
      return AirspaceSeverity.medium;
    }
    return AirspaceSeverity.low;
  }

  /// Parses an OpenAir altitude token, e.g. `2500 MSL`, `FL65`, `1000 AGL`,
  /// `GND`, `UNL`/`UNLIM`. AGL is treated as MSL here (no DEM in this project).
  static double? _parseAltitudeM(String s) {
    final u = s.toUpperCase().trim();
    if (u.isEmpty || u == 'GND' || u == 'SFC' || u == '0') return null;
    if (u.startsWith('UNL')) return null;
    final fl = RegExp(r'FL\s*(\d+)').firstMatch(u);
    if (fl != null) {
      final hundredsFt = int.parse(fl.group(1)!) * 100;
      return hundredsFt * 0.3048;
    }
    final num = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(u);
    if (num == null) return null;
    final v = double.parse(num.group(1)!);
    // Bare numbers in OpenAir are feet unless "M" is present.
    if (u.contains('M') && !u.contains('MSL') && !u.contains('AMSL')) {
      return v; // explicit meters
    }
    return v * 0.3048; // feet -> meters
  }

  /// Parses `DD:MM:SS N DDD:MM:SS E` (or decimal) → `[lat, lon]`.
  static List<double>? _parseCoord(String s) {
    final m = RegExp(
      r'([\d:.]+)\s*([NS])\s+([\d:.]+)\s*([EW])',
      caseSensitive: false,
    ).firstMatch(s);
    if (m == null) return null;
    final lat = _dms(m.group(1)!) * (m.group(2)!.toUpperCase() == 'S' ? -1 : 1);
    final lon = _dms(m.group(3)!) * (m.group(4)!.toUpperCase() == 'W' ? -1 : 1);
    return [lat, lon];
  }

  static double _dms(String token) {
    final parts = token.split(':');
    if (parts.length == 1) return double.tryParse(parts[0]) ?? 0;
    final d = double.tryParse(parts[0]) ?? 0;
    final min = parts.length > 1 ? (double.tryParse(parts[1]) ?? 0) : 0;
    final sec = parts.length > 2 ? (double.tryParse(parts[2]) ?? 0) : 0;
    return d + min / 60.0 + sec / 3600.0;
  }

  // ── Geometry helpers ──────────────────────────────────────────────────────

  /// Signed-ish distance to a polygon: <= 0 when inside, else meters to the
  /// nearest edge. Uses an equirectangular local projection (fine for the
  /// small distances relevant to airspace proximity).
  static double _distanceToPolygonM(
      double lat, double lon, List<List<double>> poly) {
    if (_pointInPolygon(lat, lon, poly)) return 0;
    var best = double.infinity;
    const mPerDegLat = 111320.0;
    final mPerDegLon = 111320.0 * math.cos(lat * math.pi / 180.0);
    double px = lon * mPerDegLon;
    double py = lat * mPerDegLat;
    for (int i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final ax = a[1] * mPerDegLon, ay = a[0] * mPerDegLat;
      final bx = b[1] * mPerDegLon, by = b[0] * mPerDegLat;
      final d = _segDist(px, py, ax, ay, bx, by);
      if (d < best) best = d;
    }
    return best;
  }

  static bool _pointInPolygon(double lat, double lon, List<List<double>> poly) {
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final yi = poly[i][0], xi = poly[i][1];
      final yj = poly[j][0], xj = poly[j][1];
      final intersect = ((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / ((yj - yi) + 1e-12) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static double _segDist(
      double px, double py, double ax, double ay, double bx, double by) {
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    double t = len2 == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }
}
