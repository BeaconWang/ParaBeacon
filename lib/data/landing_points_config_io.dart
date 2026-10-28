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
