import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../data/map_source.dart';
import 'map_source_map.dart';

/// Minimal integration example. Push this page from an app route or embed
/// [MapSourceSwitcher] and [MapSourceMap] in an existing screen.
class MapSourceDemoPage extends StatefulWidget {
  const MapSourceDemoPage({super.key});

  @override
  State<MapSourceDemoPage> createState() => _MapSourceDemoPageState();
}

class _MapSourceDemoPageState extends State<MapSourceDemoPage> {
  late final MapSourceManager _manager = MapSourceManager(
    initialSourceId: 'openfreemap-liberty',
  );

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map source example'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: MapSourceSwitcher(manager: _manager)),
          ),
        ],
      ),
      body: MapSourceMap(
        manager: _manager,
        center: const ll.LatLng(46.5197, 6.6323),
        zoom: 10,
      ),
    );
  }
}
