import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../data/gcj02.dart';
import '../data/geocoding_service.dart';
import '../data/weather_favorites.dart';
import '../data/weather_service.dart' show WeatherException;
import '../l10n/app_localizations.dart';
import 'favorite_rename_dialog.dart';
import 'map_control.dart' show MapTileSource, MapTileSources;
import 'search_query_policy.dart';

/// Resolves the device's current position, or null when unavailable.
typedef CurrentLocationResolver = Future<(double, double)?> Function();

/// Opens a full-screen map so the user can pick a location by dragging the
/// map under a fixed centre crosshair.
///
/// Returns the picked position as **WGS-84** `(latitude, longitude)`, or null
/// when the user cancels. GCJ-02 tile sources (AMap) are un-shifted on the way
/// out, so the caller always receives true GPS coordinates.
///
/// [resolveCurrentLocation] backs the "my location" button; when omitted the
/// button is hidden.
Future<(double, double)?> showMapPickerSheet(
  BuildContext context, {
  double? initialLat,
  double? initialLon,
  String initialTileSourceId = MapPickerDefaults.tileSourceId,
  CurrentLocationResolver? resolveCurrentLocation,
}) {
  return showModalBottomSheet<(double, double)>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (context) => _MapPickerSheet(
      initialLat: initialLat,
      initialLon: initialLon,
      initialTileSourceId: initialTileSourceId,
      resolveCurrentLocation: resolveCurrentLocation,
    ),
  );
}

/// Defaults for the map picker.
class MapPickerDefaults {
  MapPickerDefaults._();

  /// Use the same AMap satellite default as the live and replay maps.
  static const String tileSourceId = MapTileSources.defaultId;
}

class _MapPickerSheet extends StatefulWidget {
  const _MapPickerSheet({
    required this.initialLat,
    required this.initialLon,
    required this.initialTileSourceId,
    required this.resolveCurrentLocation,
  });

  final double? initialLat;
  final double? initialLon;
  final String initialTileSourceId;
  final CurrentLocationResolver? resolveCurrentLocation;

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  /// Fallback centre when the caller has no position yet (Lausanne, as used
  /// elsewhere in the app).
  static const LatLng _fallback = LatLng(46.5197, 6.6323);

  final MapController _map = MapController();
  final WeatherFavoritesStore _favorites = WeatherFavoritesStore.instance;

  late String _tileSourceId;

  /// Current crosshair position in WGS-84 (the value handed back).
  late LatLng _wgs;

  double _zoom = 11;
  bool _ready = false;

  /// Set while we programmatically re-centre after a tile-source change, so
  /// the position callback does not re-interpret a stale camera centre with
  /// the new (possibly shifted) coordinate system.
  bool _syncing = false;

  /// True while the "my location" button waits for a device fix.
  bool _locating = false;

  /// True while a favorite is being saved (reverse geocode in flight).
  bool _savingFavorite = false;

  // ── Search state (place name -> coordinates, via Nominatim) ──────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _searching = false;
  bool _searchFailed = false;
  List<GeocodedPlace> _searchResults = const [];

  /// Incremented per issued request so a late response from an older query
  /// cannot overwrite newer results.
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    _tileSourceId = MapTileSources.byId(widget.initialTileSourceId).id;
    final lat = widget.initialLat;
    final lon = widget.initialLon;
    _wgs = (lat != null && lon != null && _validLat(lat) && _validLon(lon))
        ? LatLng(lat, lon)
        : _fallback;
    _favorites.addListener(_onFavoritesChanged);
    _favorites.load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _favorites.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  static bool _validLat(double v) => v >= -90 && v <= 90 && !v.isNaN;
  static bool _validLon(double v) => v >= -180 && v <= 180 && !v.isNaN;

  MapTileSource get _src => MapTileSources.byId(_tileSourceId);

  bool get _isFavorite =>
      _favorites.contains(_wgs.latitude, _wgs.longitude);

  /// WGS-84 -> tile coordinate system (GCJ-02 for the Chinese providers).
  LatLng _toDisplay(LatLng wgs) {
    if (!_src.requiresGcjShift) return wgs;
    final p = Gcj02.wgsToGcj(wgs.latitude, wgs.longitude);
    return LatLng(p[0], p[1]);
  }

  /// Tile coordinate system -> WGS-84.
  LatLng _toWgs(LatLng display) {
    if (!_src.requiresGcjShift) return display;
    final p = Gcj02.gcjToWgs(display.latitude, display.longitude);
    return LatLng(p[0], p[1]);
  }

  void _onTileSourceChanged(String id) {
    if (id == _tileSourceId) return;
    final wgs = _wgs; // captured under the *old* projection
    setState(() {
      _syncing = true;
      _tileSourceId = id;
      _zoom = _zoom.clamp(2.0, MapTileSources.byId(id).maxZoom);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_ready) _map.move(_toDisplay(wgs), _zoom);
      setState(() => _syncing = false);
    });
  }

  void _zoomBy(double delta) {
    if (!_ready) return;
    final next = (_map.camera.zoom + delta).clamp(2.0, _src.maxZoom);
    _map.move(_map.camera.center, next);
    setState(() => _zoom = next);
  }

  /// Moves the crosshair to [wgs] (keeping the zoom, or [zoom] when given).
  void _moveTo(LatLng wgs, {double? zoom}) {
    final target = (zoom ?? _zoom).clamp(2.0, _src.maxZoom);
    setState(() {
      _wgs = wgs;
      _zoom = target;
    });
    if (_ready) _map.move(_toDisplay(wgs), target);
  }

  /// Re-centres on the device's current position.
  Future<void> _goToCurrentLocation() async {
    final resolve = widget.resolveCurrentLocation;
    if (resolve == null || _locating) return;
    setState(() => _locating = true);
    final fix = await resolve();
    if (!mounted) return;
    setState(() => _locating = false);
    if (fix == null || !_validLat(fix.$1) || !_validLon(fix.$2)) {
      _snack(AppLocalizations.of(context).weatherNoGps);
      return;
    }
    _moveTo(LatLng(fix.$1, fix.$2), zoom: math.max(_zoom, 12));
  }

  /// Saves (or un-saves) the crosshair position as a favorite. The name comes
  /// from a best-effort reverse geocode, falling back to the coordinates.
  Future<void> _toggleFavorite() async {
    if (_savingFavorite) return;
    final l10n = AppLocalizations.of(context);
    final wgs = _wgs;
    if (_favorites.contains(wgs.latitude, wgs.longitude)) {
      await _favorites.removeSpot(wgs.latitude, wgs.longitude);
      if (mounted) _snack(l10n.weatherFavoriteRemoved);
      return;
    }
    setState(() => _savingFavorite = true);
    final language = Localizations.localeOf(context).languageCode;
    final name = await GeocodingService.instance.reverseName(
      lat: wgs.latitude,
      lon: wgs.longitude,
      language: language,
    );
    if (!mounted) return;
    setState(() => _savingFavorite = false);
    final place = FavoritePlace.create(
      name: (name == null || name.trim().isEmpty)
          ? _coordsLabel(wgs)
          : name.trim(),
      lat: wgs.latitude,
      lon: wgs.longitude,
    );
    if (place == null) return;
    await _favorites.add(place);
    if (mounted) _snack(l10n.weatherFavoriteSaved(place.name));
  }

  // ── Search ───────────────────────────────────────────────────────────────

  /// Schedules a geocode for the field's current contents.
  ///
  /// The delay comes from [SearchQueryPolicy], which gives text the IME still
  /// marks provisional a longer quiet period — a pinyin session collapses to
  /// one request instead of geocoding every romanization fragment.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final value = _searchController.value;
    if (value.text.trim().isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchFailed = false;
        _searching = false;
      });
      return;
    }
    final delay = SearchQueryPolicy.debounceFor(value);
    if (delay == null) return;
    // Re-read the field when the timer fires: during a long composing wait
    // the IME may have committed something quite different.
    _searchDebounce = Timer(delay, () => _runSearch(_searchController.text));
  }

  void _onSearchSubmitted(String text) {
    _searchDebounce?.cancel();
    if (!SearchQueryPolicy.canSubmit(text)) return;
    _runSearch(text);
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) return;
    // Requests can complete out of order (or after the field was cleared);
    // only the newest one is allowed to publish its outcome.
    final seq = ++_searchSeq;
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final results = await GeocodingService.instance.search(
        query,
        language: language,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _searchResults = results;
      });
    } on WeatherException {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
        _searchResults = const [];
      });
    }
  }

  /// Centres the crosshair on a search hit and dismisses the result list.
  void _selectSearchResult(GeocodedPlace place) {
    _searchDebounce?.cancel();
    _searchSeq++; // drop anything still in flight
    _searchFocus.unfocus();
    setState(() {
      _searchResults = const [];
      _searchFailed = false;
      _searching = false;
      _searchController.text = place.name;
    });
    _moveTo(LatLng(place.lat, place.lon), zoom: math.max(_zoom, 12));
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchSeq++; // drop anything still in flight
    _searchController.clear();
    setState(() {
      _searchResults = const [];
      _searchFailed = false;
      _searching = false;
    });
  }

  /// Prompts for a new name for a saved location.
  Future<void> _renameFavorite(FavoritePlace place) async {
    await showFavoriteRenameDialog(
      context,
      place,
      coordsLabel: _coordsLabel(LatLng(place.lat, place.lon)),
    );
  }

  void _snack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _coordsLabel([LatLng? at]) {
    final p = at ?? _wgs;
    final latHemi = p.latitude >= 0 ? 'N' : 'S';
    final lonHemi = p.longitude >= 0 ? 'E' : 'W';
    return '${p.latitude.abs().toStringAsFixed(4)}°$latHemi  '
        '${p.longitude.abs().toStringAsFixed(4)}°$lonHemi';
  }

  String _sourceLabel(AppLocalizations l10n, String id) => switch (id) {
        'none' => l10n.settingMapSourceNone,
        'osm' => l10n.settingMapSourceOsm,
        'osmfr' => l10n.settingMapSourceOsmFr,
        'carto-dark' => l10n.settingMapSourceCartoDark,
        'carto-voyager' => l10n.settingMapSourceCartoVoyager,
        'amap' => l10n.settingMapSourceAmap,
        'amap-sat' => l10n.settingMapSourceAmapSat,
        _ => MapTileSources.byId(id).label,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final src = _src;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C1B3A), Color(0xFF040917)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildTopBar(l10n),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: _toDisplay(_wgs),
                        initialZoom: _zoom,
                        minZoom: 2,
                        maxZoom: src.maxZoom,
                        onMapReady: () => _ready = true,
                        onPositionChanged: (camera, _) {
                          if (_syncing) return;
                          final wgs = _toWgs(camera.center);
                          setState(() {
                            _wgs = wgs;
                            _zoom = camera.zoom;
                          });
                        },
                        onTap: (_, point) {
                          // A tap on the map is also a way out of the search
                          // overlay (dismiss the list and the keyboard).
                          if (_searchFocus.hasFocus) _searchFocus.unfocus();
                          if (_searchResults.isNotEmpty || _searchFailed) {
                            setState(() {
                              _searchResults = const [];
                              _searchFailed = false;
                            });
                          }
                          _map.move(point, _map.camera.zoom);
                        },
                      ),
                      children: [
                        if (!src.isNone)
                          TileLayer(
                            key: ValueKey<String>('picker-tile-$_tileSourceId'),
                            urlTemplate: src.urlTemplate,
                            maxNativeZoom: src.maxZoom.round(),
                            // Rely on flutter_map's own User-Agent (see the
                            // note in MapControl): a custom header is dropped
                            // on Android and breaks OSM's usage policy check.
                            userAgentPackageName: 'com.beacon.parabeacon',
                          ),
                      ],
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(child: Center(child: _Crosshair())),
                  ),
                  // Search overlays the map rather than taking a row of its
                  // own, so the pickable area stays as large as possible.
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSearchField(l10n),
                        if (_searchResults.isNotEmpty || _searchFailed)
                          _buildSearchResults(l10n),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      children: [
                        if (widget.resolveCurrentLocation != null)
                          _MapRoundButton(
                            icon: Icons.my_location,
                            busy: _locating,
                            tooltip: l10n.mapPickerMyLocation,
                            onPressed: _goToCurrentLocation,
                          ),
                        if (widget.resolveCurrentLocation != null)
                          const SizedBox(height: 8),
                        _MapRoundButton(
                          icon: Icons.add,
                          onPressed: () => _zoomBy(1),
                        ),
                        const SizedBox(height: 8),
                        _MapRoundButton(
                          icon: Icons.remove,
                          onPressed: () => _zoomBy(-1),
                        ),
                      ],
                    ),
                  ),
                  if (!src.isNone)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          src.attribution,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomBar(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xE6101B33),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              // Read the controller (not the raw string) so the composing
              // region is available to SearchQueryPolicy.
              onChanged: (_) => _onSearchChanged(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: l10n.weatherSearchHint,
                hintStyle: TextStyle(color: Colors.white.withAlpha(110)),
              ),
            ),
          ),
          if (_searching)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70),
            )
          else if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: const Icon(Icons.close, size: 16, color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: const Color(0xF2101B33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: _searchFailed
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                l10n.weatherSearchFailed,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            )
          : _searchResults.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    l10n.weatherNoResults,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, i) {
                    final place = _searchResults[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined,
                          size: 18, color: Colors.white54),
                      title: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        place.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withAlpha(130), fontSize: 11),
                      ),
                      onTap: () => _selectSearchResult(place),
                    );
                  },
                ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    final favorites = _favorites.places;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.pin_drop_outlined, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.mapPickerTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (favorites.isNotEmpty)
            PopupMenuButton<int>(
              icon: const Icon(Icons.bookmarks_outlined, color: Colors.white70),
              tooltip: l10n.weatherFavorites,
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 340),
              onSelected: (i) {
                if (i < 0 || i >= favorites.length) return;
                final p = favorites[i];
                _moveTo(LatLng(p.lat, p.lon), zoom: math.max(_zoom, 11));
              },
              itemBuilder: (context) => [
                for (var i = 0; i < favorites.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            favorites[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                              Icons.drive_file_rename_outline,
                              size: 18),
                          tooltip: l10n.weatherFavoriteRename,
                          visualDensity: VisualDensity.compact,
                          // Close the menu first: the dialog must not be
                          // torn down with the popup route.
                          onPressed: () {
                            final place = favorites[i];
                            Navigator.of(context).pop();
                            _renameFavorite(place);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers_outlined, color: Colors.white70),
            tooltip: l10n.settingMapSource,
            initialValue: _tileSourceId,
            onSelected: _onTileSourceChanged,
            itemBuilder: (context) => [
              for (final s in MapTileSources.all)
                PopupMenuItem(
                  value: s.id,
                  child: Text(_sourceLabel(l10n, s.id)),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: l10n.cancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    final saved = _isFavorite;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mapPickerHint,
            style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _coordsLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IconButton(
                icon: _savingFavorite
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white70),
                      )
                    : Icon(
                        saved ? Icons.star : Icons.star_border,
                        color: saved ? Colors.amberAccent : Colors.white70,
                      ),
                tooltip: saved
                    ? l10n.weatherFavoriteRemove
                    : l10n.weatherFavoriteAdd,
                onPressed: _toggleFavorite,
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.mapPickerConfirm),
                onPressed: () => Navigator.of(context)
                    .pop((_wgs.latitude, _wgs.longitude)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fixed centre marker: the map moves under it, the crosshair stays put.
class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(painter: _CrosshairPainter()),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final halo = Paint()
      ..color = Colors.black.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final line = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final p in [halo, line]) {
      canvas.drawCircle(c, 9, p);
      canvas.drawLine(Offset(c.dx, 0), Offset(c.dx, c.dy - 13), p);
      canvas.drawLine(Offset(c.dx, c.dy + 13), Offset(c.dx, size.height), p);
      canvas.drawLine(Offset(0, c.dy), Offset(c.dx - 13, c.dy), p);
      canvas.drawLine(Offset(c.dx + 13, c.dy), Offset(size.width, c.dy), p);
    }
    canvas.drawCircle(c, 1.6, Paint()..color = Colors.orangeAccent);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) => false;
}

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool busy;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.black.withAlpha(140),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: SizedBox(
          width: 38,
          height: 38,
          child: busy
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white70),
                  ),
                )
              : Icon(icon, size: 20, color: Colors.white70),
        ),
      ),
    );
    final label = tooltip;
    return label == null ? button : Tooltip(message: label, child: button);
  }
}
