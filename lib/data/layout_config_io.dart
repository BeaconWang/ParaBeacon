import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controls/dash_page.dart';
import '../controls/placed_control.dart';
import 'flight_file_output_service.dart';
import 'layout_store.dart';

/// Imports and exports dashboard layouts without including account credentials,
/// device state, recordings, or other app preferences.
class LayoutConfigIO {
  LayoutConfigIO._();

  static final LayoutConfigIO instance = LayoutConfigIO._();

  static const String _formatId = 'parabeacon.dashboard';
  static const int _formatVersion = 1;
  static const String extension = 'pblayout';
  static const int maxFileBytes = 5 * 1024 * 1024;
  static const int _maxPages = 100;
  static const int _maxControls = 5000;

  /// Encodes a complete dashboard layout as a portable JSON configuration.
  String buildBundle(SavedLayout layout) {
    return jsonEncode({
      'format': _formatId,
      'version': _formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'gridSize': layout.gridSize,
      'currentPage': layout.currentPage,
      'pages': layout.pages.map((page) => page.toJson()).toList(),
    });
  }

  /// Reads a configuration file after checking its size, then validates it.
  Future<SavedLayout> importFile(String path) async {
    final file = File(path);
    final length = await file.length();
    if (length <= 0 || length > maxFileBytes) {
      throw const FormatException('Invalid configuration size.');
    }
    return parseBundle(await file.readAsBytes());
  }

  /// Parses and validates an imported configuration before it can be applied.
  /// Unknown control types are ignored by [PlacedControl.fromJson] to remain
  /// compatible with layouts created by newer app versions.
  SavedLayout parseBundle(List<int> bytes) {
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

      final gridSize = decoded['gridSize'];
      if (gridSize is! num ||
          !gridSize.isFinite ||
          gridSize < 16 ||
          gridSize > 120) {
        throw const FormatException('Invalid grid size.');
      }

      final pagesJson = decoded['pages'];
      if (pagesJson is! List ||
          pagesJson.isEmpty ||
          pagesJson.length > _maxPages) {
        throw const FormatException('Invalid dashboard pages.');
      }

      final pageIds = <String>{};
      final controlIds = <String>{};
      var totalControls = 0;
      final pages = <DashPage>[];

      for (final pageJson in pagesJson) {
        if (pageJson is! Map<String, dynamic>) {
          throw const FormatException('Invalid dashboard page.');
        }
        final pageId = pageJson['id'];
        final title = pageJson['title'];
        final iconCodePoint = pageJson['iconCodePoint'];
        final controlsJson = pageJson['controls'];
        if (pageId is! String ||
            pageId.isEmpty ||
            pageId.length > 128 ||
            !pageIds.add(pageId) ||
            (title != null && (title is! String || title.length > 256)) ||
            (iconCodePoint != null && iconCodePoint is! int) ||
            controlsJson is! List) {
          throw const FormatException('Invalid dashboard page.');
        }

        totalControls += controlsJson.length;
        if (controlsJson.length > _maxControls ||
            totalControls > _maxControls) {
          throw const FormatException('Too many dashboard controls.');
        }

        for (final controlJson in controlsJson) {
          if (controlJson is! Map<String, dynamic>) {
            throw const FormatException('Invalid dashboard control.');
          }
          _validateControl(controlJson, controlIds);
        }

        pages.add(DashPage.fromJson(pageJson));
      }

      final rawCurrentPage = decoded['currentPage'] ?? 0;
      if (rawCurrentPage is! num ||
          !rawCurrentPage.isFinite ||
          rawCurrentPage % 1 != 0) {
        throw const FormatException('Invalid current page.');
      }

      return SavedLayout(
        pages: pages,
        gridSize: gridSize.toDouble(),
        currentPage: rawCurrentPage.toInt().clamp(0, pages.length - 1),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid dashboard configuration.');
    }
  }

  /// Exports the serialized configuration as a `.pblayout` file.
  ///
  /// On Android, [saveToDownloads] writes into Downloads/ParaBeacon. Otherwise,
  /// the file is placed in temporary storage and opened in the share sheet.
  /// Returns false if the user cancels the Android save picker.
  Future<bool> exportAndShare(
    SavedLayout layout, {
    bool saveToDownloads = false,
  }) async {
    final bytes = utf8.encode(buildBundle(layout));
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final fileName =
        'parabeacon_layout_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}.$extension';

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
    ], subject: 'ParaBeacon dashboard configuration');
    return true;
  }

  void _validateControl(Map<String, dynamic> json, Set<String> controlIds) {
    final instanceId = json['instanceId'];
    final typeId = json['typeId'];
    final settings = json['settings'];
    if (instanceId is! String ||
        instanceId.isEmpty ||
        instanceId.length > 128 ||
        !controlIds.add(instanceId) ||
        typeId is! String ||
        typeId.isEmpty ||
        typeId.length > 128 ||
        (settings != null && settings is! Map)) {
      throw const FormatException('Invalid dashboard control.');
    }

    for (final field in const ['col', 'row', 'cols', 'rows']) {
      final value = json[field];
      if (value == null) continue;
      if (value is! num || !value.isFinite || value % 1 != 0) {
        throw const FormatException('Invalid dashboard control geometry.');
      }
      final integer = value.toInt();
      if ((field == 'col' || field == 'row') &&
          (integer < -10000 || integer > 10000)) {
        throw const FormatException('Invalid dashboard control position.');
      }
      if ((field == 'cols' || field == 'rows') &&
          (integer < 1 || integer > 10000)) {
        throw const FormatException('Invalid dashboard control size.');
      }
    }

    if (settings is Map) {
      if (settings.length > 256) {
        throw const FormatException('Too many dashboard control settings.');
      }
      for (final entry in settings.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String || key.isEmpty || key.length > 128) {
          throw const FormatException('Invalid dashboard control setting.');
        }
        if (value != null &&
            value is! bool &&
            value is! num &&
            value is! String) {
          throw const FormatException('Invalid dashboard control setting.');
        }
        if (value is num && !value.isFinite) {
          throw const FormatException('Invalid dashboard control setting.');
        }
        if (value is String && value.length > 4096) {
          throw const FormatException('Invalid dashboard control setting.');
        }
      }
    }
  }
}
