import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../data/gcj02.dart';
import '../data/map_source.dart';
import '../data/map_tile_cache.dart';

/// Simple runtime map view for the provider catalog.
///
/// Coordinates passed to this widget are always WGS-84. GCJ-02 providers have
/// their display center transformed before the raster map is created. Use
/// [MapSourceManager] with [MapSourceSwitcher] to change sources without
/// rebuilding the surrounding screen.
class MapSourceMap extends StatelessWidget {
  const MapSourceMap({
    required this.manager,
    this.center = const ll.LatLng(46.5197, 6.6323),
    this.zoom = 10,
    this.userAgentPackageName = 'com.beacon.parabeacon',
    super.key,
  });

  final MapSourceManager manager;
  final ll.LatLng center;
  final double zoom;
  final String userAgentPackageName;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final source = manager.selectedSource;
        return Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(key: ValueKey(source.id), child: _buildMap(source)),
            Positioned(
              right: 8,
              bottom: 8,
              child: _AttributionChip(text: source.attribution),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap(MapSource source) {
    if (source.requiresInsecureHttp ||
        source.url?.startsWith('http://') == true) {
      return const _SourceUnavailable(
        message:
            'This provider only supplied an HTTP URL. Cleartext map traffic is disabled for security. Use a verified HTTPS endpoint or an HTTPS proxy.',
      );
    }

    return switch (source.type) {
      MapSourceType.rasterTiles => _buildRasterMap(source),
      MapSourceType.vectorStyle => _buildVectorMap(source),
    };
  }

  Widget _buildRasterMap(MapSource source) {
    final template = source.url;
    if (template == null) {
      return const _SourceUnavailable(message: 'Raster URL is missing.');
    }

    var displayCenter = center;
    if (source.requiresGcjShift) {
      final shifted = Gcj02.wgsToGcj(center.latitude, center.longitude);
      displayCenter = ll.LatLng(shifted[0], shifted[1]);
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: displayCenter,
        initialZoom: zoom.clamp(2, source.maxZoom).toDouble(),
        maxZoom: source.maxZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: template,
          tileProvider: MapTileCacheProvider(),
          maxNativeZoom: source.maxZoom.round(),
          userAgentPackageName: userAgentPackageName,
        ),
      ],
    );
  }

  Widget _buildVectorMap(MapSource source) {
    final isNativeMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!kIsWeb && !isNativeMobile) {
      return const _SourceUnavailable(
        message:
            'Vector styles are supported on Android, iOS, and web. Choose a raster source on desktop.',
      );
    }

    final styleUrl = source.styleUrl;
    if (styleUrl == null || !styleUrl.startsWith('https://')) {
      return const _SourceUnavailable(
        message: 'A valid HTTPS MapLibre style URL is required.',
      );
    }

    return ml.MapLibreMap(
      initialCameraPosition: ml.CameraPosition(
        target: ml.LatLng(center.latitude, center.longitude),
        zoom: zoom.clamp(2, source.maxZoom).toDouble(),
      ),
      styleString: styleUrl,
    );
  }
}

/// Compact selector intended for toolbars, settings panels, or demo pages.
class MapSourceSwitcher extends StatelessWidget {
  const MapSourceSwitcher({
    required this.manager,
    this.expanded = false,
    super.key,
  });

  final MapSourceManager manager;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) => DropdownButton<String>(
        value: manager.selectedId,
        isExpanded: expanded,
        onChanged: (id) {
          if (id != null) manager.select(id);
        },
        items: [
          for (final source in MapSourceCatalog.all)
            DropdownMenuItem<String>(
              value: source.id,
              child: Text(source.label, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

class _AttributionChip extends StatelessWidget {
  const _AttributionChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _SourceUnavailable extends StatelessWidget {
  const _SourceUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
