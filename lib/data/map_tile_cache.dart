import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart' show ImageProvider, MemoryImage;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'gcj02.dart';
import 'offline_tiles_service.dart';

/// A snapshot of the app-wide persistent map-tile cache.
class MapTileCacheStats {
  const MapTileCacheStats({required this.bytes, required this.tileCount});

  final int bytes;
  final int tileCount;
}

/// Per-source cache details and an aggregate total for the settings summary.
class MapTileCacheSummary {
  const MapTileCacheSummary({required this.total, required this.bySource});

  final MapTileCacheStats total;
  final Map<String, MapTileCacheStats> bySource;
}

/// Shared persistent cache for online map tiles used throughout the app.
class MapTileCacheService {
  MapTileCacheService._();

  static final MapTileCacheService instance = MapTileCacheService._();

  static const _maxCacheBytes = 256 * 1024 * 1024;
  static const _trimTargetBytes = _maxCacheBytes * 3 ~/ 4;
  static const _maxTileBytes = 10 * 1024 * 1024;
  static const _trimWriteThresholdBytes = 8 * 1024 * 1024;
  static const _sourceIds = <String>[
    'osm',
    'osmfr',
    'carto-dark',
    'carto-voyager',
    'amap',
    'amap-sat',
  ];
  static const _legacySourceId = 'legacy';

  Future<Directory>? _directoryFuture;
  Future<void> _writeQueue = Future<void>.value();
  int _generation = 0;
  int _bytesSinceLastTrim = 0;
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

  String? _sourceIdForUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host == 'tile.openstreetmap.org') return 'osm';
    if (host == 'a.tile.openstreetmap.fr' && uri.path.startsWith('/osmfr/')) {
      return 'osmfr';
    }
    if (host == 'basemaps.cartocdn.com') {
      if (uri.path.startsWith('/dark_all/')) return 'carto-dark';
      if (uri.path.startsWith('/rastertiles/voyager/')) {
        return 'carto-voyager';
      }
    }
    if (host == 'webrd01.is.autonavi.com' &&
        uri.path == '/appmaptile' &&
        uri.queryParameters['style'] == '8') {
      return 'amap';
    }
    if (host == 'webst01.is.autonavi.com' &&
        uri.path == '/appmaptile' &&
        uri.queryParameters['style'] == '6') {
      return 'amap-sat';
    }
    return null;
  }

  String? _cachePathFor(String url, Directory directory) {
    final sourceId = _sourceIdForUrl(url);
    if (sourceId == null) return null;
    final key = sha256.convert(utf8.encode(url)).toString();
    return p.join(directory.path, sourceId, key);
  }

  String? _legacyCachePathFor(String url, Directory directory) {
    if (_sourceIdForUrl(url) == null) return null;
    final key = sha256.convert(utf8.encode(url)).toString();
    return p.join(directory.path, key);
  }

  /// Returns cached bytes when present, otherwise null so the provider fetches
  /// the tile from its configured public tile server.
  Future<Uint8List?> read(String url) async {
    try {
      final directory = await _directory();
      final path = _cachePathFor(url, directory);
      final legacyPath = _legacyCachePathFor(url, directory);
      if (path == null || legacyPath == null) return null;
      final cachedFile = File(path);
      final legacyFile = File(legacyPath);
      final isLegacy = !await cachedFile.exists();
      final file = isLegacy ? legacyFile : cachedFile;
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
      if (isLegacy) {
        try {
          await cachedFile.parent.create(recursive: true);
          if (!await cachedFile.exists()) {
            await file.rename(path);
          } else {
            await legacyFile.delete();
          }
        } catch (_) {}
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Returns total size and tile count for the shared disk cache.
  Future<MapTileCacheStats> getCacheStats() async =>
      (await getCacheSummary()).total;

  /// Returns cache details by online source, plus the aggregate total.
  /// File stats are processed in bounded parallel batches and intentionally do
  /// not share the tile-write queue, so opening settings cannot stall tile loads.
  Future<MapTileCacheSummary> getCacheSummary() async {
    final generation = _generation;
    final directory = await _directory();
    final sourceBytes = <String, int>{
      for (final sourceId in _sourceIds) sourceId: 0,
      _legacySourceId: 0,
    };
    final sourceTileCounts = <String, int>{
      for (final sourceId in _sourceIds) sourceId: 0,
      _legacySourceId: 0,
    };
    var totalBytes = 0;
    var totalTileCount = 0;
    final pending = <File>[];

    Future<void> flushBatch() async {
      final batch = List<File>.of(pending);
      pending.clear();
      await Future.wait(
        batch.map((file) async {
          try {
            final stat = await file.stat();
            if (stat.type != FileSystemEntityType.file || stat.size <= 0)
              return;
            final relativePath = p.relative(file.path, from: directory.path);
            final pathParts = p.split(relativePath);
            final sourceId =
                pathParts.length > 1 && sourceBytes.containsKey(pathParts.first)
                ? pathParts.first
                : _legacySourceId;
            sourceBytes[sourceId] = sourceBytes[sourceId]! + stat.size;
            sourceTileCounts[sourceId] = sourceTileCounts[sourceId]! + 1;
            totalBytes += stat.size;
            totalTileCount++;
          } on FileSystemException {
            // A tile may be removed while the settings summary is being read.
          }
        }),
      );
    }

    try {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || p.basename(entity.path).contains('.tmp-')) {
          continue;
        }
        pending.add(entity);
        if (pending.length == 64) await flushBatch();
      }
      await flushBatch();
    } on FileSystemException {
      if (generation == _generation) rethrow;
      return getCacheSummary();
    }
    if (generation != _generation) return getCacheSummary();

    return MapTileCacheSummary(
      total: MapTileCacheStats(bytes: totalBytes, tileCount: totalTileCount),
      bySource: {
        for (final sourceId in sourceBytes.keys)
          sourceId: MapTileCacheStats(
            bytes: sourceBytes[sourceId]!,
            tileCount: sourceTileCounts[sourceId]!,
          ),
      },
    );
  }

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
        await file.parent.create(recursive: true);
        if (!await file.exists()) {
          final temp = File(
            '$path.tmp-${DateTime.now().microsecondsSinceEpoch}',
          );
          try {
            await temp.writeAsBytes(bytes, flush: true);
            await temp.rename(path);
            _bytesSinceLastTrim += bytes.length;
          } finally {
            if (await temp.exists()) await temp.delete();
          }
        }
        if (_bytesSinceLastTrim >= _trimWriteThresholdBytes) {
          await _trimIfNeeded(directory);
          _bytesSinceLastTrim = 0;
        }
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
    _bytesSinceLastTrim = 0;
  });

  Future<void> _trimIfNeeded(Directory directory) async {
    final files = <({File file, int size, DateTime modified})>[];
    var totalBytes = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
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

/// Uses an MBTiles tile when present and asks the selected online source only
/// for coordinates missing from that file.
class OfflineFirstTileProvider extends TileProvider {
  OfflineFirstTileProvider({required this.onlineProvider});

  final MapTileCacheProvider? onlineProvider;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    try {
      final tile = OfflineTilesService.instance.getTile(
        z: coordinates.z,
        x: coordinates.x,
        y: coordinates.y,
      );
      if (tile != null && tile.isNotEmpty) return MemoryImage(tile);
    } catch (_) {}

    final urlTemplate = options.urlTemplate;
    final network = onlineProvider;
    if (network == null || urlTemplate == null || urlTemplate.isEmpty) {
      return MemoryImage(TileProvider.transparentImage);
    }
    final onlineCoordinates =
        OfflineTilesService.instance.isActive &&
            urlTemplate.contains('is.autonavi.com')
        ? _gcjCoordinates(coordinates)
        : coordinates;
    return network.getImage(onlineCoordinates, options);
  }

  TileCoordinates _gcjCoordinates(TileCoordinates coordinates) {
    final world = 1 << coordinates.z;
    final longitude = (coordinates.x + 0.5) / world * 360 - 180;
    final latitudeRadians =
        2 *
            math.atan(
              math.exp(math.pi * (1 - 2 * (coordinates.y + 0.5) / world)),
            ) -
        math.pi / 2;
    final latitude = latitudeRadians * 180 / math.pi;
    final shifted = Gcj02.wgsToGcj(latitude, longitude);
    final shiftedLatRadians = shifted[0] * math.pi / 180;
    final shiftedX = ((shifted[1] + 180) / 360 * world).floor().clamp(
      0,
      world - 1,
    );
    final shiftedY =
        ((1 -
                    math.log(
                          math.tan(shiftedLatRadians) +
                              1 / math.cos(shiftedLatRadians),
                        ) /
                        math.pi) /
                2 *
                world)
            .floor()
            .clamp(0, world - 1);
    return TileCoordinates(shiftedX, shiftedY, coordinates.z);
  }
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
