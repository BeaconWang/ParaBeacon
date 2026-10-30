import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/flight_recorder.dart';
import '../data/map_tile_cache.dart';
import '../data/offline_tiles_service.dart';

class Track3DGroundMap {
  Track3DGroundMap._({
    required this.image,
    required this.zoom,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.originPixelX,
    required this.originPixelY,
    required this.halfExtentMeters,
  });

  static const _tileSize = 256;
  static const _maxTiles = 64;
  static const _maxImageDimension = 4096;
  static const _mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _maxTileBytes = 10 * 1024 * 1024;

  final ui.Image image;
  final int zoom;
  final double centerLatitude;
  final double centerLongitude;
  final double originPixelX;
  final double originPixelY;
  final double halfExtentMeters;

  static Future<Track3DGroundMap?> load(List<FlightSample> samples) async {
    if (samples.length < 2) return null;

    var latitudeSum = 0.0;
    var longitudeSum = 0.0;
    for (final sample in samples) {
      latitudeSum += sample.data.latitude;
      longitudeSum += sample.data.longitude;
    }
    final centerLatitude = latitudeSum / samples.length;
    final centerLongitude = longitudeSum / samples.length;
    const metersPerDegreeLatitude = 111320.0;
    final metersPerDegreeLongitude =
        metersPerDegreeLatitude * math.cos(centerLatitude * math.pi / 180);

    var minEast = double.infinity;
    var maxEast = double.negativeInfinity;
    var minNorth = double.infinity;
    var maxNorth = double.negativeInfinity;
    for (final sample in samples) {
      final east =
          (sample.data.longitude - centerLongitude) * metersPerDegreeLongitude;
      final north =
          (sample.data.latitude - centerLatitude) * metersPerDegreeLatitude;
      minEast = math.min(minEast, east);
      maxEast = math.max(maxEast, east);
      minNorth = math.min(minNorth, north);
      maxNorth = math.max(maxNorth, north);
    }
    final trackSpan = math.max(maxEast - minEast, maxNorth - minNorth);
    final halfExtentMeters = math.max(50.0, trackSpan * 0.75);
    final safeLatitude = centerLatitude.clamp(-85.05112878, 85.05112878);
    final cosineLatitude = math.cos(safeLatitude * math.pi / 180).abs();
    final desiredZoom =
        (math.log(
                  1024 *
                      156543.03392 *
                      math.max(0.01, cosineLatitude) /
                      (halfExtentMeters * 2),
                ) /
                math.ln2)
            .floor();
    var zoom = desiredZoom.clamp(2, 18);

    late int minTileX;
    late int maxTileX;
    late int minTileY;
    late int maxTileY;
    late double worldSize;
    while (true) {
      worldSize = _tileSize * (1 << zoom).toDouble();
      final west = _worldX(
        centerLongitude - halfExtentMeters / metersPerDegreeLongitude,
        worldSize,
      );
      final east = _worldX(
        centerLongitude + halfExtentMeters / metersPerDegreeLongitude,
        worldSize,
      );
      final north = _worldY(
        centerLatitude + halfExtentMeters / metersPerDegreeLatitude,
        worldSize,
      );
      final south = _worldY(
        centerLatitude - halfExtentMeters / metersPerDegreeLatitude,
        worldSize,
      );
      final tileCount = 1 << zoom;
      minTileX = (west / _tileSize).floor().clamp(0, tileCount - 1);
      maxTileX = (east / _tileSize).floor().clamp(0, tileCount - 1);
      minTileY = (north / _tileSize).floor().clamp(0, tileCount - 1);
      maxTileY = (south / _tileSize).floor().clamp(0, tileCount - 1);
      final columns = maxTileX - minTileX + 1;
      final rows = maxTileY - minTileY + 1;
      if (zoom <= 2 ||
          (columns * rows <= _maxTiles &&
              columns * _tileSize <= _maxImageDimension &&
              rows * _tileSize <= _maxImageDimension)) {
        break;
      }
      zoom--;
    }

    final coordinates = [
      for (var x = minTileX; x <= maxTileX; x++)
        for (var y = minTileY; y <= maxTileY; y++) (x: x, y: y),
    ];
    final loadedTiles = <({int x, int y, ui.Image image})>[];
    var nextIndex = 0;
    Future<void> loadWorker() async {
      while (nextIndex < coordinates.length) {
        final coordinate = coordinates[nextIndex++];
        final bytes = await _tileBytes(zoom, coordinate.x, coordinate.y);
        if (bytes == null) continue;
        final image = await _decodeTile(bytes);
        if (image != null) {
          loadedTiles.add((x: coordinate.x, y: coordinate.y, image: image));
        }
      }
    }

    await Future.wait(List.generate(4, (_) => loadWorker()));
    if (loadedTiles.isEmpty) return null;

    final imageWidth = (maxTileX - minTileX + 1) * _tileSize;
    final imageHeight = (maxTileY - minTileY + 1) * _tileSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.transparent, BlendMode.src);
    for (final tile in loadedTiles) {
      canvas.drawImageRect(
        tile.image,
        Rect.fromLTWH(
          0,
          0,
          tile.image.width.toDouble(),
          tile.image.height.toDouble(),
        ),
        Rect.fromLTWH(
          (tile.x - minTileX) * _tileSize.toDouble(),
          (tile.y - minTileY) * _tileSize.toDouble(),
          _tileSize.toDouble(),
          _tileSize.toDouble(),
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(imageWidth, imageHeight);
      return Track3DGroundMap._(
        image: image,
        zoom: zoom,
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
        originPixelX: minTileX * _tileSize.toDouble(),
        originPixelY: minTileY * _tileSize.toDouble(),
        halfExtentMeters: halfExtentMeters,
      );
    } finally {
      picture.dispose();
      for (final tile in loadedTiles) {
        tile.image.dispose();
      }
    }
  }

  void paint(Canvas canvas, Track3DGroundProjector projector) {
    const subdivisions = 20;
    final vertexCount = subdivisions * subdivisions * 6;
    final positions = Float32List(vertexCount * 2);
    final textureCoordinates = Float32List(vertexCount * 2);
    var vertexOffset = 0;

    void addVertex(double east, double north) {
      final screen = projector.projectGround(east, north);
      positions[vertexOffset] = screen.dx;
      positions[vertexOffset + 1] = screen.dy;
      final texture = _texturePixel(east, north);
      textureCoordinates[vertexOffset] = texture.dx;
      textureCoordinates[vertexOffset + 1] = texture.dy;
      vertexOffset += 2;
    }

    final step = halfExtentMeters * 2 / subdivisions;
    for (var row = 0; row < subdivisions; row++) {
      final north = halfExtentMeters - row * step;
      final south = north - step;
      for (var column = 0; column < subdivisions; column++) {
        final west = -halfExtentMeters + column * step;
        final east = west + step;
        addVertex(west, north);
        addVertex(east, north);
        addVertex(west, south);
        addVertex(east, north);
        addVertex(east, south);
        addVertex(west, south);
      }
    }

    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: textureCoordinates,
    );
    final shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
    );
    canvas.drawVertices(
      vertices,
      BlendMode.srcOver,
      Paint()
        ..shader = shader
        ..filterQuality = FilterQuality.medium,
    );
  }

  Offset _texturePixel(double east, double north) {
    const metersPerDegreeLatitude = 111320.0;
    final metersPerDegreeLongitude =
        metersPerDegreeLatitude * math.cos(centerLatitude * math.pi / 180);
    final longitude = centerLongitude + east / metersPerDegreeLongitude;
    final latitude = (centerLatitude + north / metersPerDegreeLatitude).clamp(
      -85.05112878,
      85.05112878,
    );
    final worldSize = _tileSize * (1 << zoom).toDouble();
    return Offset(
      _worldX(longitude, worldSize) - originPixelX,
      _worldY(latitude, worldSize) - originPixelY,
    );
  }

  static Future<Uint8List?> _tileBytes(int zoom, int x, int y) async {
    try {
      final offline = OfflineTilesService.instance.getTile(z: zoom, x: x, y: y);
      if (offline != null && offline.isNotEmpty) return offline;
    } catch (_) {}

    final url = _mapTileUrl
        .replaceAll('{z}', '$zoom')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    try {
      final response = await MapTileCacheService.instance.httpClient
          .get(
            Uri.parse(url),
            headers: const {'user-agent': 'com.beacon.parabeacon'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          response.bodyBytes.length > _maxTileBytes) {
        return null;
      }
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image?> _decodeTile(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _tileSize,
        targetHeight: _tileSize,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    } finally {
      codec?.dispose();
    }
  }

  static double _worldX(double longitude, double worldSize) =>
      (longitude + 180) / 360 * worldSize;

  static double _worldY(double latitude, double worldSize) {
    final radians = latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    final sinLatitude = math.sin(radians);
    final normalizedY =
        0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi);
    return normalizedY.clamp(0.0, 1.0) * worldSize;
  }

  void dispose() => image.dispose();
}

abstract interface class Track3DGroundProjector {
  Offset projectGround(double east, double north);
}
