import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'flight_file_output_service.dart';
import 'landing_point_store.dart';

class LandingPointsBundle {
  LandingPointsBundle({required List<LandingPoint> points, this.defaultId})
    : points = List.unmodifiable(points);

  final List<LandingPoint> points;
  final String? defaultId;
}

class LandingPointImportCandidate {
  const LandingPointImportCandidate({
    required this.key,
    required this.point,
    required this.fromFile,
  });

  final String key;
  final LandingPoint point;
  final bool fromFile;
}

class LandingPointNameConflict {
  LandingPointNameConflict({
    required this.nameKey,
    required List<LandingPointImportCandidate> candidates,
  }) : candidates = List.unmodifiable(candidates);

  final String nameKey;
  final List<LandingPointImportCandidate> candidates;
}

class LandingPointsMergeResult {
  LandingPointsMergeResult({required List<LandingPoint> points, this.defaultId})
    : points = List.unmodifiable(points);

  final List<LandingPoint> points;
  final String? defaultId;
}

class LandingPointsLimitException implements Exception {
  const LandingPointsLimitException();
}

/// Imports and exports saved landing points as a portable JSON file.
class LandingPointsConfigIO {
  LandingPointsConfigIO._();

  static final LandingPointsConfigIO instance = LandingPointsConfigIO._();

  static const String extension = 'pblpoints';
  static const int maxFileBytes = 1024 * 1024;
  static const String _formatId = 'parabeacon.landing-points';
  static const int _formatVersion = 1;

  String buildBundle(List<LandingPoint> points, {String? defaultId}) {
    if (points.length > LandingPointStore.maxEntries) {
      throw const FormatException('Too many landing points.');
    }
    final ids = <String>{};
    for (final point in points) {
      if (!ids.add(point.id)) {
        throw const FormatException('Duplicate landing point id.');
      }
    }
    if (defaultId != null && !ids.contains(defaultId)) {
      throw const FormatException('Invalid default landing point.');
    }
    return jsonEncode({
      'format': _formatId,
      'version': _formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'defaultId': defaultId,
      'points': points.map((point) => point.toJson()).toList(),
    });
  }

  /// Parses and validates a landing-point bundle before it can be applied.
  LandingPointsBundle parseBundle(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw const FormatException('Invalid configuration size.');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != _formatId ||
          decoded['version'] != _formatVersion) {
        throw const FormatException('Unsupported configuration format.');
      }

      final entries = decoded['points'];
      if (entries is! List || entries.length > LandingPointStore.maxEntries) {
        throw const FormatException('Invalid landing points.');
      }
      final ids = <String>{};
      final points = <LandingPoint>[];
      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Invalid landing point.');
        }
        final altitude = entry['altitudeM'];
        final notes = entry['notes'];
        if ((altitude != null &&
                (altitude is! num ||
                    !altitude.isFinite ||
                    altitude < -12000 ||
                    altitude > 100000)) ||
            (notes != null && notes is! String)) {
          throw const FormatException('Invalid landing point metadata.');
        }
        final point = LandingPoint.tryParse(entry);
        if (point == null || !ids.add(point.id)) {
          throw const FormatException('Invalid or duplicate landing point.');
        }
        points.add(point);
      }

      final defaultId = decoded['defaultId'];
      if ((defaultId != null && defaultId is! String) ||
          (defaultId is String && !ids.contains(defaultId))) {
        throw const FormatException('Invalid default landing point.');
      }
      return LandingPointsBundle(
        points: points,
        defaultId: defaultId as String?,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid landing-point configuration.');
    }
  }

  List<LandingPointNameConflict> findNameConflicts(
    List<LandingPoint> savedPoints,
    List<LandingPoint> importedPoints,
  ) {
    return _groupCandidates(savedPoints, importedPoints).entries
        .where(
          (entry) =>
              entry.value.length > 1 &&
              entry.value.any((candidate) => candidate.fromFile),
        )
        .map(
          (entry) => LandingPointNameConflict(
            nameKey: entry.key,
            candidates: entry.value,
          ),
        )
        .toList(growable: false);
  }

  LandingPointsMergeResult merge({
    required List<LandingPoint> savedPoints,
    required String? savedDefaultId,
    required LandingPointsBundle imported,
    required Map<String, String> conflictChoices,
  }) {
    final groups = _groupCandidates(savedPoints, imported.points);
    final selectedByName = <String, LandingPointImportCandidate>{};
    final selectedCandidates = <LandingPointImportCandidate>[];
    for (final entry in groups.entries) {
      final candidates = entry.value;
      if (candidates.length == 1) {
        selectedByName[entry.key] = candidates.single;
        selectedCandidates.add(candidates.single);
      } else if (candidates.any((candidate) => candidate.fromFile)) {
        final selectedKey = conflictChoices[entry.key];
        final selected = candidates.where((item) => item.key == selectedKey);
        if (selected.isEmpty) {
          throw const FormatException('Missing landing-point name choice.');
        }
        selectedByName[entry.key] = selected.first;
        selectedCandidates.add(selected.first);
      } else {
        selectedCandidates.addAll(candidates);
      }
    }

    if (selectedCandidates.length > LandingPointStore.maxEntries) {
      throw const LandingPointsLimitException();
    }
    final reservedSavedIds = selectedCandidates
        .where((candidate) => !candidate.fromFile)
        .map((candidate) => candidate.point.id)
        .toSet();
    final usedIds = <String>{};
    final pointsByCandidateKey = <String, LandingPoint>{};
    final mergedPoints = <LandingPoint>[];
    for (final candidate in selectedCandidates) {
      var point = candidate.point;
      if ((candidate.fromFile && reservedSavedIds.contains(point.id)) ||
          usedIds.contains(point.id)) {
        point = _copyWithNewId(point, {...reservedSavedIds, ...usedIds});
      }
      usedIds.add(point.id);
      pointsByCandidateKey[candidate.key] = point;
      mergedPoints.add(point);
    }

    final savedDefaultCandidate = _findCandidateById(
      savedPoints,
      savedDefaultId,
      fromFile: false,
    );
    final importedDefaultCandidate = _findCandidateById(
      imported.points,
      imported.defaultId,
      fromFile: true,
    );
    final defaultReference = savedDefaultCandidate ?? importedDefaultCandidate;
    LandingPointImportCandidate? resolveDefaultCandidate(
      LandingPointImportCandidate? candidate,
    ) {
      if (candidate == null) return null;
      final nameKey = _nameKey(candidate.point.name);
      final group = groups[nameKey];
      if (group != null &&
          group.length > 1 &&
          group.any((item) => item.fromFile)) {
        return selectedByName[nameKey];
      }
      return candidate;
    }

    final keptDefaultCandidate = resolveDefaultCandidate(defaultReference);

    return LandingPointsMergeResult(
      points: mergedPoints,
      defaultId: keptDefaultCandidate == null
          ? null
          : pointsByCandidateKey[keptDefaultCandidate.key]?.id,
    );
  }

  Map<String, List<LandingPointImportCandidate>> _groupCandidates(
    List<LandingPoint> savedPoints,
    List<LandingPoint> importedPoints,
  ) {
    final groups = <String, List<LandingPointImportCandidate>>{};
    void addPoints(
      List<LandingPoint> points, {
      required String source,
      required bool fromFile,
    }) {
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        final key = _nameKey(point.name);
        groups
            .putIfAbsent(key, () => [])
            .add(
              LandingPointImportCandidate(
                key: '$source:$index',
                point: point,
                fromFile: fromFile,
              ),
            );
      }
    }

    addPoints(savedPoints, source: 'saved', fromFile: false);
    addPoints(importedPoints, source: 'file', fromFile: true);
    return groups;
  }

  LandingPointImportCandidate? _findCandidateById(
    List<LandingPoint> points,
    String? id, {
    required bool fromFile,
  }) {
    if (id == null) return null;
    final index = points.indexWhere((point) => point.id == id);
    if (index < 0) return null;
    return LandingPointImportCandidate(
      key: '${fromFile ? 'file' : 'saved'}:$index',
      point: points[index],
      fromFile: fromFile,
    );
  }

  String _nameKey(String name) => name.trim().toLowerCase();

  LandingPoint _copyWithNewId(LandingPoint point, Set<String> usedIds) {
    LandingPoint? copy;
    do {
      copy = LandingPoint.create(
        name: point.name,
        latitude: point.latitude,
        longitude: point.longitude,
        altitudeM: point.altitudeM,
        createdAt: point.createdAt,
        notes: point.notes,
      );
    } while (copy == null || usedIds.contains(copy.id));
    return copy;
  }

  Future<LandingPointsBundle> importFile(String path) async {
    final file = File(path);
    final length = await file.length();
    if (length <= 0 || length > maxFileBytes) {
      throw const FormatException('Invalid configuration size.');
    }
    return parseBundle(await file.readAsBytes());
  }

  /// Saves to Android Downloads when selected; otherwise opens the share sheet.
  Future<bool> exportAndShare(
    List<LandingPoint> points, {
    String? defaultId,
    bool saveToDownloads = false,
  }) async {
    final bytes = utf8.encode(buildBundle(points, defaultId: defaultId));
    if (bytes.length > maxFileBytes) {
      throw const FormatException('Invalid configuration size.');
    }

    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final fileName =
        'parabeacon_landing_points_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.$extension';

    if (saveToDownloads) {
      final destination = await FlightFileOutputService.instance
          .saveToDownloads(
            bytes: bytes,
            fileName: fileName,
            mimeType: 'application/json',
          );
      return destination != null;
    }

    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(file.path, name: fileName, mimeType: 'application/json'),
    ], subject: 'ParaBeacon landing points');
    return true;
  }
}
