import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline raster-basemap (`.mbtiles`) service for the Map control (singleton).
///
/// Ported from the reference ParaBeacon `OfflineTilesService`, trimmed to the
/// current project's needs:
///
/// * The user drops `.mbtiles` files into `<app-documents>/mbtiles/` (or imports
///   them via the Map control settings).
/// * [warmup] re-opens the file the user last activated (persisted with
///   `shared_preferences`).
/// * [tileProvider] returns a `flutter_map` provider when a file is active, or
///   `null` so the caller falls back to online tiles.
///
/// A [ValueListenable] ([revision]) ticks whenever the active source changes so
/// widgets (the Map control) can rebuild their tile layer.
class OfflineTilesService {
  OfflineTilesService._();
  static final OfflineTilesService instance = OfflineTilesService._();

  static const _kActiveKey = 'pb.map.activeMbtiles';

  Directory? _root;
  MbTiles? _mbtiles;
  String? _activeName;

  /// Ticks on every activate/deactivate so listeners rebuild the tile layer.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  String? get activeFileName => _activeName;
  bool get isActive => _mbtiles != null;

  /// Absolute path of the directory holding imported `.mbtiles` files.
  Future<String> dataDirectoryPath() async => (await _rootDir()).path;

  Future<Directory> _rootDir() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'mbtiles'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  /// Lists available `.mbtiles` file names (sorted), or empty when none.
  Future<List<String>> listAvailable() async {
    final dir = await _rootDir();
    if (!await dir.exists()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((n) => n.toLowerCase().endsWith('.mbtiles'))
        .toList()
      ..sort();
  }

  /// Re-opens the last-activated file on app start (best-effort).
  Future<void> warmup() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final wanted = sp.getString(_kActiveKey);
      if (wanted != null && wanted.isNotEmpty) {
        await activate(wanted);
      }
    } catch (_) {
      // Ignore: start with online tiles.
    }
  }

  /// Activates [fileName] (in the mbtiles directory). Passing null/empty turns
  /// the offline source off. Returns whether an offline source is now active.
  Future<bool> activate(String? fileName) async {
    await _close();
    if (fileName == null || fileName.trim().isEmpty) {
      _activeName = null;
      await _persistActive(null);
      revision.value++;
      return false;
    }
    try {
      final dir = await _rootDir();
      final path = p.join(dir.path, fileName);
      if (!await File(path).exists()) {
        debugPrint('OfflineTilesService: file not found: $path');
        revision.value++;
        return false;
      }
      _mbtiles = MbTiles(mbtilesPath: path, gzip: true);
      _activeName = fileName;
      await _persistActive(fileName);
      revision.value++;
      return true;
    } catch (e) {
      debugPrint('OfflineTilesService: activate failed: $e');
      _mbtiles = null;
      _activeName = null;
      revision.value++;
      return false;
    }
  }

  /// Copies an external `.mbtiles` file into the local directory. Returns the
  /// stored file name, or null on failure.
  Future<String?> importFile(String srcPath) async {
    if (!srcPath.toLowerCase().endsWith('.mbtiles')) return null;
    final dir = await _rootDir();
    try {
      final dst = File(p.join(dir.path, p.basename(srcPath)));
      await File(srcPath).copy(dst.path);
      return p.basename(dst.path);
    } catch (e) {
      debugPrint('OfflineTilesService: import failed: $e');
      return null;
    }
  }

  /// Deletes a stored `.mbtiles` file (deactivating it first when active).
  Future<void> removeFile(String fileName) async {
    if (_activeName == fileName) {
      await _close();
      _activeName = null;
      await _persistActive(null);
      revision.value++;
    }
    final dir = await _rootDir();
    final f = File(p.join(dir.path, fileName));
    if (await f.exists()) await f.delete();
  }

  /// A `flutter_map` tile provider backed by the active file, or null when no
  /// offline source is active (caller should fall back to online tiles).
  TileProvider? tileProvider() {
    final mb = _mbtiles;
    if (mb == null) return null;
    return MbTilesTileProvider(mbtiles: mb, silenceTileNotFound: true);
  }

  Future<void> _close() async {
    try {
      _mbtiles?.dispose();
    } catch (_) {}
    _mbtiles = null;
  }

  Future<void> _persistActive(String? name) async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (name == null) {
        await sp.remove(_kActiveKey);
      } else {
        await sp.setString(_kActiveKey, name);
      }
    } catch (_) {
      // Best-effort persistence.
    }
  }
}
