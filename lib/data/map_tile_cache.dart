import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A snapshot of the app-wide persistent map-tile cache.
class MapTileCacheStats {
  const MapTileCacheStats({required this.bytes, required this.tileCount});

  final int bytes;
  final int tileCount;
}

/// Shared persistent cache for online map tiles used throughout the app.
class MapTileCacheService {
  MapTileCacheService._();

  static final MapTileCacheService instance = MapTileCacheService._();

  static const _maxCacheBytes = 256 * 1024 * 1024;
  static const _trimTargetBytes = _maxCacheBytes * 3 ~/ 4;
  static const _maxTileBytes = 10 * 1024 * 1024;
  static const _allowedHosts = <String>{
    'tile.openstreetmap.org',
    'a.tile.openstreetmap.fr',
    'basemaps.cartocdn.com',
    'webrd01.is.autonavi.com',
    'webst01.is.autonavi.com',
  };

  Future<Directory>? _directoryFuture;
  Future<void> _writeQueue = Future<void>.value();
  int _generation = 0;
  late final http.BaseClient _httpClient = _MapTileCacheClient(this);

  int get generation => _generation;
  http.BaseClient get httpClient => _httpClient;

  Future<Directory> _directory() => _directoryFuture ??= _createDirectory();

  Future<Directory> _createDirectory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'map_tile_cache'));
    await dir.create(recursive: true);
    return dir;
  }

  String? _cachePathFor(String url, Directory directory) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !_allowedHosts.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final key = sha256.convert(utf8.encode(url)).toString();
    return p.join(directory.path, key);
  }

  /// Returns cached bytes when present, otherwise null so the provider fetches
  /// the tile from its configured public tile server.
  Future<Uint8List?> read(String url) async {
    try {
      final directory = await _directory();
      final path = _cachePathFor(url, directory);
      if (path == null) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (stat.size == 0 || stat.size > _maxTileBytes) {
        await file.delete();
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        await file.delete();
        return null;
      }
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Returns the total size and tile count for the shared disk cache.
  Future<MapTileCacheStats> getCacheStats() => _exclusive(() async {
    final directory = await _directory();
    var bytes = 0;
    var tileCount = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || p.basename(entity.path).contains('.tmp-')) {
        continue;
      }
      final stat = await entity.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size <= 0 ||
          stat.size > _maxTileBytes) {
        continue;
      }
      bytes += stat.size;
      tileCount++;
    }
    return MapTileCacheStats(bytes: bytes, tileCount: tileCount);
  });

  /// Persists a successful response if it belongs to the current cache
  /// generation. A clear operation invalidates writes already in flight.
  Future<void> store(String url, Uint8List bytes, int generation) async {
    if (bytes.isEmpty || bytes.length > _maxTileBytes) return;
    await _exclusive(() async {
      if (generation != _generation) return;
      try {
        final directory = await _directory();
        final path = _cachePathFor(url, directory);
        if (path == null) return;
        final file = File(path);
        if (!await file.exists()) {
          final temp = File(
            '$path.tmp-${DateTime.now().microsecondsSinceEpoch}',
          );
          try {
            await temp.writeAsBytes(bytes, flush: true);
            await temp.rename(path);
          } finally {
            if (await temp.exists()) await temp.delete();
          }
        }
        await _trimIfNeeded(directory);
      } catch (_) {
        // A disk-cache failure must not prevent online tiles from displaying.
      }
    });
  }

  /// Deletes the shared persistent cache used by every map view.
  Future<void> clearCache() => _exclusive(() async {
    _generation++;
    final directory = await _directory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  });

  Future<void> _trimIfNeeded(Directory directory) async {
    final files = <({File file, int size, DateTime modified})>[];
    var totalBytes = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      if (p.basename(entity.path).contains('.tmp-')) {
        try {
          await entity.delete();
        } catch (_) {}
        continue;
      }
      final stat = await entity.stat();
      if (stat.type != FileSystemEntityType.file) continue;
      totalBytes += stat.size;
      files.add((file: entity, size: stat.size, modified: stat.modified));
    }
    if (totalBytes <= _maxCacheBytes) return;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in files) {
      if (totalBytes <= _trimTargetBytes) break;
      try {
        await entry.file.delete();
        totalBytes -= entry.size;
      } catch (_) {}
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final previous = _writeQueue;
    final release = Completer<void>();
    _writeQueue = release.future;
    return (() async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    })();
  }
}

/// Network provider that reads and writes through the app-wide disk cache.
class MapTileCacheProvider extends NetworkTileProvider {
  MapTileCacheProvider()
    : super(httpClient: MapTileCacheService.instance.httpClient);
}

class _MapTileCacheClient extends http.BaseClient {
  _MapTileCacheClient(this._cache) : _client = RetryClient(http.Client());

  final MapTileCacheService _cache;
  final http.Client _client;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') return _client.send(request);

    final generation = _cache.generation;
    final cached = await _cache.read(request.url.toString());
    if (cached != null) {
      return http.StreamedResponse(
        Stream<List<int>>.value(cached),
        200,
        contentLength: cached.length,
        request: request,
        headers: const {'content-type': 'application/octet-stream'},
      );
    }

    final response = await _client.send(request);
    if (response.statusCode != 200) return response;
    final bytes = await response.stream.toBytes();
    await _cache.store(request.url.toString(), bytes, generation);
    final headers = Map<String, String>.from(response.headers)
      ..remove('content-length');
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: request,
      headers: headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    // Tile providers share this app-lifetime client; an individual layer cannot
    // close it while other map views may still be using it.
  }
}
