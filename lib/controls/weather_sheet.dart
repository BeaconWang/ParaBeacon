import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../data/flight_data_provider.dart';
import '../data/geocoding_service.dart';
import '../data/weather_service.dart';
import '../data/weather_service_manager.dart';
import '../data/weather_providers.dart' show WeatherModel;
import '../data/weather_units.dart';
import '../l10n/app_localizations.dart';
import 'meteogram.dart';

/// Opens the Weather screen as a full-screen sheet: a nowcast panel, a
/// synchronized meteogram, a 16-day glance strip and a location search bar
/// (OpenStreetMap Nominatim).
///
/// All forecast state comes from the unified weather data layer
/// (weather_service_manager.dart): a single Open-Meteo request pulls the
/// full parameter set (with up to 92 past days and a selectable forecast
/// model) and fails over to the other providers if Open-Meteo is down.
Future<void> showWeatherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Background driven by the theme's bottomSheetTheme (see other sheets).
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints.expand(),
    builder: (context) => const _WeatherSheet(),
  );
}

enum _Phase { loading, ready, error }

enum _ErrorKind { noFix, network }

enum _BottomTab { meteogram, daily }

class _WeatherSheet extends StatefulWidget {
  const _WeatherSheet();

  @override
  State<_WeatherSheet> createState() => _WeatherSheetState();
}

class _WeatherSheetState extends State<_WeatherSheet> {
  _Phase _phase = _Phase.loading;
  _ErrorKind _errorKind = _ErrorKind.noFix;
  WeatherData? _data;
  double? _lat;
  double? _lon;
  String? _placeName;

  // View / interaction state.
  int? _selectedHour; // null = "now" (current conditions)
  _BottomTab _bottomTab = _BottomTab.meteogram;
  WeatherModel _model = WeatherModel.bestMatch;
  int _pastDays = 0;

  // Search state.
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _searching = false;
  bool _searchFailed = false;
  List<GeocodedPlace> _searchResults = const [];

  // True while a background re-fetch (model/unit/past-days/refresh/place)
  // updates the data — the previous forecast stays visible underneath.
  bool _refetching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  /// Resolves the location (searched place > live flight-data fix > one-shot
  /// device fix) and fetches the forecast for it.
  Future<void> _load({bool keepLocation = false}) async {
    if (!keepLocation || _lat == null || _lon == null) {
      setState(() {
        _phase = _Phase.loading;
        _data = null;
        _selectedHour = null;
      });

      // Read the live flight-data snapshot synchronously, before any await,
      // so the (possibly stale) context is only used while mounted.
      final data = FlightDataProvider.transformerOf(context).data;
      final hasLiveFix = data.hasFix &&
          (data.latitude != 0.0 || data.longitude != 0.0);

      double? lat;
      double? lon;
      if (hasLiveFix) {
        lat = data.latitude;
        lon = data.longitude;
      } else {
        final fix = await _oneShotFix();
        lat = fix?.$1;
        lon = fix?.$2;
      }

      if (!mounted) return;
      if (lat == null || lon == null) {
        setState(() {
          _phase = _Phase.error;
          _errorKind = _ErrorKind.noFix;
        });
        return;
      }
      _lat = lat;
      _lon = lon;
      if (_placeName == null) {
        // Best-effort reverse geocode for a friendly header name.
        _reverseName(lat, lon);
      }
    } else {
      setState(() => _refetching = true);
    }

    try {
      final weather = await WeatherServiceManager.instance.fetch(
        lat: _lat!,
        lon: _lon!,
        pastDays: _pastDays,
        forecastDays: OpenMeteoHorizon.days,
        model: _model,
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _data = weather;
        _selectedHour = null;
        _refetching = false;
      });
    } on WeatherException {
      if (!mounted) return;
      setState(() {
        if (_data == null) {
          _phase = _Phase.error;
          _errorKind = _ErrorKind.network;
        } else {
          // Keep showing the stale forecast; surface via the refetch flag.
          _refetching = false;
        }
      });
    }
  }

  /// Changes the query options and re-fetches (location unchanged).
  void _refetch({
    WeatherModel? model,
    int? pastDays,
  }) {
    if (!mounted) return;
    setState(() {
      if (model != null) _model = model;
      if (pastDays != null) _pastDays = pastDays;
    });
    _load(keepLocation: true);
  }

  /// A unit preference changed: the API is re-requested with the new unit
  /// parameters (server-side conversion keeps the data exact).
  void _onUnitsChanged() {
    if (!mounted) return;
    if (_lat != null && _lon != null) _load(keepLocation: true);
  }

  Future<void> _reverseName(double lat, double lon) async {
    final name = await GeocodingService.instance.reverseName(
      lat: lat,
      lon: lon,
      language: _languageCode(),
    );
    if (!mounted || name == null || _placeName != null) return;
    setState(() => _placeName = name);
  }

  /// One-shot device position fix; null when permissions/services are off or
  /// the platform cannot provide a fix (e.g. desktop without location).
  Future<(double, double)?> _oneShotFix() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchFailed = false;
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final results = await GeocodingService.instance.search(
        query,
        language: _languageCode(),
      );
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchResults = results;
      });
    } on WeatherException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
        _searchResults = const [];
      });
    }
  }

  void _selectPlace(GeocodedPlace place) {
    _searchFocus.unfocus();
    setState(() {
      _searchResults = const [];
      _searchController.text = place.name;
      _placeName = place.name;
      _lat = place.lat;
      _lon = place.lon;
    });
    _load(keepLocation: true);
  }

  String _languageCode() => Localizations.localeOf(context).languageCode;

  // ── Derived state ────────────────────────────────────────────────────────

  WeatherUnits get _units => WeatherUnitSettings.instance.units;

  /// The hour the view is pointed at: the scrubbed slot, or null for "now".
  WeatherHour? get _selectedSlot {
    final data = _data;
    final idx = _selectedHour;
    if (data == null || idx == null) return null;
    if (idx < 0 || idx >= data.hourly.length) return null;
    return data.hourly[idx];
  }

  // ── Formatting ───────────────────────────────────────────────────────────

  String _fmtWind(double v) => '${v.round()} ${_units.wind.symbol}';
  String _fmtGust(double v) => 'G ${v.round()}';
  String _fmtTemp(double v) => '${v.round()}${_units.temperature.symbol}';

  String _fmtHour(BuildContext context, DateTime t) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('HH:mm', locale).format(t);
  }

  String _coordsLabel() {
    final lat = _lat;
    final lon = _lon;
    if (lat == null || lon == null) return '';
    final latHemi = lat >= 0 ? 'N' : 'S';
    final lonHemi = lon >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(3)}°$latHemi '
        '${lon.abs().toStringAsFixed(3)}°$lonHemi';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: WeatherUnitSettings.instance,
      builder: (context, _) {
        // Static deep-sky backdrop (replaces the old animated background);
        // keeps the white foreground chrome readable.
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(l10n),
                if (_searchResults.isNotEmpty || _searchFailed)
                  _buildSearchResults(l10n),
                Expanded(
                  child: switch (_phase) {
                    _Phase.loading => _buildLoading(l10n),
                    _Phase.error => _buildError(l10n),
                    _Phase.ready => _buildReady(l10n),
                  },
                ),
                _buildBottomPanel(l10n),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Top bar (search + actions) ───────────────────────────────────────────

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildSearchField(l10n),
          ),
          IconButton(
            icon: Icon(
              Icons.straighten,
              color: _refetching ? Colors.orangeAccent : Colors.white70,
            ),
            tooltip: l10n.weatherUnits,
            onPressed: _showUnitsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: l10n.weatherRefresh,
            onPressed: _phase == _Phase.loading ? null : () => _load(keepLocation: true),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
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
              onSubmitted: _runSearch,
              onChanged: _onSearchChanged,
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
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            )
          else if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              child: const Icon(Icons.close, size: 16, color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: const Color(0xE6101B33),
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
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Text(
                            place.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withAlpha(130),
                                fontSize: 11),
                          ),
                          onTap: () => _selectPlace(place),
                        );
                      },
                    ),
    );
  }

  // ── Loading / error ──────────────────────────────────────────────────────

  Widget _buildLoading(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            l10n.weatherSubtitle,
            style: TextStyle(color: Colors.white.withAlpha(160)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    final (icon, message) = switch (_errorKind) {
      _ErrorKind.noFix => (
          Icons.location_disabled_outlined,
          l10n.weatherNoGps,
        ),
      _ErrorKind.network => (
          Icons.cloud_off_outlined,
          l10n.weatherLoadFailed,
        ),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white70),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withAlpha(200)),
            ),
          ),
          const SizedBox(height: 16),
          // When there is no fix, offer the location search as the escape
          // hatch (desktop without GPS can still browse forecasts).
          if (_errorKind == _ErrorKind.noFix)
            OutlinedButton.icon(
              icon: const Icon(Icons.search, size: 18),
              label: Text(l10n.weatherSearchHint),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => _searchFocus.requestFocus(),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.weatherRetry),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  // ── Ready layout ─────────────────────────────────────────────────────────

  Widget _buildReady(AppLocalizations l10n) {
    final data = _data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NowcastPanel(
            data: data,
            slot: _selectedSlot,
            units: _units,
            placeName: _placeName ?? _coordsLabel(),
            timezone: data.timezone,
            fmtWind: _fmtWind,
            fmtGust: _fmtGust,
            fmtTemp: _fmtTemp,
            fmtHour: (t) => _fmtHour(context, t),
            onBackToNow: _selectedHour != null
                ? () => setState(() => _selectedHour = null)
                : null,
          ),
        ],
      ),
    );
  }

  // ── Bottom overlay panel (meteogram / daily glance) ──────────────────────

  Widget _buildBottomPanel(AppLocalizations l10n) {
    final data = _data;
    final screenH = MediaQuery.of(context).size.height;
    final chartH = (screenH * 0.22).clamp(170.0, 240.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(120),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(40))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab + settings row.
          Row(
            children: [
              _pillToggle(
                l10n.weatherTabMeteogram,
                selected: _bottomTab == _BottomTab.meteogram,
                onTap: () => setState(() => _bottomTab = _BottomTab.meteogram),
              ),
              const SizedBox(width: 6),
              _pillToggle(
                l10n.weatherTabDaily,
                selected: _bottomTab == _BottomTab.daily,
                onTap: () => setState(() => _bottomTab = _BottomTab.daily),
              ),
              const Spacer(),
              _modelChip(l10n),
              const SizedBox(width: 6),
              _pastDaysChip(l10n),
            ],
          ),
          if (_refetching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Colors.orangeAccent,
                backgroundColor: Colors.transparent,
              ),
            ),
          if (data != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: _bottomTab == _BottomTab.meteogram ? chartH : 118,
              child: _bottomTab == _BottomTab.meteogram
                  ? Meteogram(
                      hours: data.hourly,
                      currentTime: data.currentTime,
                      selectedIndex: _meteogramSelection,
                      onSelect: (i) => setState(() => _selectedHour = i),
                      labelTemp: l10n.weatherAxisTemp,
                      labelPrecip: l10n.weatherAxisPrecip,
                      labelWind: l10n.weatherAxisWind,
                      labelCloud: l10n.weatherAxisCloud,
                      dark: true,
                    )
                  : _buildDailyGlance(data, l10n),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  l10n.weatherSubtitle,
                  style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 12),
                ),
              ),
            ),
          ],
          _buildAttribution(l10n, data),
        ],
      ),
    );
  }

  /// Index the meteogram cursor points at: the scrubbed hour, or "now".
  int get _meteogramSelection {
    final idx = _selectedHour;
    if (idx != null) return idx;
    final data = _data;
    final t = data?.currentTime;
    if (data == null || t == null) return 0;
    final i = data.hourly.indexWhere((h) => !h.time.isBefore(t));
    return i < 0 ? 0 : i;
  }

  Widget _pillToggle(String label,
      {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.white54 : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _modelChip(AppLocalizations l10n) {
    return PopupMenuButton<WeatherModel>(
      tooltip: l10n.weatherModel,
      color: const Color(0xE6101B33),
      onSelected: (m) => _refetch(model: m),
      itemBuilder: (context) => [
        for (final m in WeatherModel.values)
          PopupMenuItem(
            value: m,
            child: Row(
              children: [
                Icon(
                  m == _model ? Icons.check : Icons.model_training,
                  size: 16,
                  color: m == _model ? Colors.orangeAccent : Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(m.label,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.model_training, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              _model.label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pastDaysChip(AppLocalizations l10n) {
    final label = _pastDays == 0
        ? l10n.weatherPastDaysOff
        : l10n.weatherPastDaysShort(_pastDays);
    return PopupMenuButton<int>(
      tooltip: l10n.weatherPastDays,
      color: const Color(0xE6101B33),
      onSelected: (d) => _refetch(pastDays: d),
      itemBuilder: (context) => [
        for (final d in const [0, 3, 7, 30, 92])
          PopupMenuItem(
            value: d,
            child: Row(
              children: [
                Icon(
                  d == _pastDays ? Icons.check : Icons.history,
                  size: 16,
                  color: d == _pastDays ? Colors.orangeAccent : Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(
                  d == 0 ? l10n.weatherPastDaysOff : l10n.weatherPastDaysShort(d),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// Daily glance: compact cards for the whole horizon (weather icon,
  /// max/min, precipitation probability, sunrise/sunset).
  Widget _buildDailyGlance(WeatherData data, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).toString();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: data.daily.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, i) {
        final day = data.daily[i];
        final label = i == 0
            ? l10n.weatherToday
            : DateFormat.E(locale).format(day.date);
        final df = DateFormat('HH:mm', locale);
        return Container(
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              Icon(kindIcon(day.kind), size: 22, color: Colors.orangeAccent),
              Text(
                _fmtTemp(day.tMax),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                _fmtTemp(day.tMin),
                style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11),
              ),
              if (day.precipProbability > 0)
                Text(
                  l10n.weatherPrecipProbability(day.precipProbability.round()),
                  style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10),
                ),
              const Spacer(),
              if (day.sunrise != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wb_twilight, size: 10, color: Colors.amberAccent),
                    const SizedBox(width: 2),
                    Text(
                      df.format(day.sunrise!),
                      style: TextStyle(
                          color: Colors.white.withAlpha(180), fontSize: 9),
                    ),
                  ],
                ),
              if (day.sunset != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.nightlight_outlined, size: 10, color: Colors.indigoAccent),
                    const SizedBox(width: 2),
                    Text(
                      df.format(day.sunset!),
                      style: TextStyle(
                          color: Colors.white.withAlpha(180), fontSize: 9),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttribution(AppLocalizations l10n, WeatherData? data) {
    final parts = <String>[];
    if (data != null) {
      parts.add(l10n.weatherSourceBy(data.source ?? 'Open-Meteo'));
    }
    final coords = _coordsLabel();
    if (coords.isNotEmpty) parts.add(coords);
    if (data?.timezone != null) parts.add(data!.timezone!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
      child: Row(
        children: [
          if (data?.servedByFallback == true) ...[
            Icon(Icons.swap_horiz, size: 12, color: Colors.orangeAccent.withAlpha(200)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              parts.join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ── Units sheet ──────────────────────────────────────────────────────────

  Future<void> _showUnitsSheet() async {
    final settings = WeatherUnitSettings.instance;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final l10n = AppLocalizations.of(sheetContext);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.weatherUnits,
                        style: Theme.of(sheetContext).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _unitGroup<TemperatureUnit>(
                      title: l10n.weatherUnitTemperature,
                      values: TemperatureUnit.values,
                      selected: settings.temperature,
                      label: (u) => u.symbol,
                      onSelect: (u) {
                        settings.setTemperature(u).then((_) => _onUnitsChanged());
                        setSheetState(() {});
                      },
                    ),
                    const Divider(height: 24),
                    _unitGroup<WindSpeedUnit>(
                      title: l10n.weatherUnitWindSpeed,
                      values: WindSpeedUnit.values,
                      selected: settings.wind,
                      label: (u) => u.symbol,
                      onSelect: (u) {
                        settings.setWind(u).then((_) => _onUnitsChanged());
                        setSheetState(() {});
                      },
                    ),
                    const Divider(height: 24),
                    _unitGroup<PrecipitationUnit>(
                      title: l10n.weatherUnitPrecipitation,
                      values: PrecipitationUnit.values,
                      selected: settings.precipitation,
                      label: (u) => u.symbol,
                      onSelect: (u) {
                        settings.setPrecipitation(u).then((_) => _onUnitsChanged());
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _unitGroup<T extends Enum>({
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(label(v)),
                selected: v == selected,
                onSelected: (_) => onSelect(v),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Nowcast panel ────────────────────────────────────────────────────────────

/// Top-left summary card: place, big temperature, condition, feels-like,
/// the pilot's primary instrument (wind) and a chip row of the extended
/// Open-Meteo metrics available for the selected hour.
class _NowcastPanel extends StatelessWidget {
  const _NowcastPanel({
    required this.data,
    required this.slot,
    required this.units,
    required this.placeName,
    required this.timezone,
    required this.fmtWind,
    required this.fmtGust,
    required this.fmtTemp,
    required this.fmtHour,
    this.onBackToNow,
  });

  final WeatherData data;
  final WeatherHour? slot;
  final WeatherUnits units;
  final String placeName;
  final String? timezone;
  final String Function(double) fmtWind;
  final String Function(double) fmtGust;
  final String Function(double) fmtTemp;
  final String Function(DateTime) fmtHour;
  final VoidCallback? onBackToNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cur = data.current;
    final temp = slot?.temperature ?? cur.temperature;
    final kind = slot?.kind ?? cur.kind;
    final isDay = slot?.isDay ?? cur.isDay;
    final wind = slot?.windSpeed ?? cur.windSpeed;
    final gusts = slot?.windGusts ?? cur.windGusts;
    final dir = slot?.windDirection ?? cur.windDirection;
    final feels = slot?.apparentTemperature ?? cur.apparentTemperature;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(100),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: place + scrub state.
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (onBackToNow != null && slot != null)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onBackToNow,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withAlpha(60),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fmtHour(slot!.time),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.close, size: 12, color: Colors.white),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Main readout.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${temp.round()}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w300,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(kindIcon(kind, isDay: isDay),
                              size: 32, color: Colors.orangeAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kindLabel(l10n, kind),
                      style: TextStyle(
                          color: Colors.white.withAlpha(220), fontSize: 14),
                    ),
                    Text(
                      l10n.weatherFeelsLike(feels.round()),
                      style: TextStyle(
                          color: Colors.white.withAlpha(150), fontSize: 12),
                    ),
                  ],
                ),
              ),
              _WindBadge(
                speed: fmtWind(wind),
                gusts: fmtGust(gusts),
                direction: dir,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Extended metric chips (only the ones this data source provides).
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final chip in _chips(l10n))
                _MetricChip(label: chip.$1, value: chip.$2),
            ],
          ),
        ],
      ),
    );
  }

  List<(String, String)> _chips(AppLocalizations l10n) {
    final cur = data.current;
    final h = slot;
    final chips = <(String, String)>[
      (
        l10n.weatherHumidity,
        '${(h?.relativeHumidity ?? cur.humidity).round()}%'
      ),
      (
        l10n.weatherCloudCover,
        '${(h?.cloudCover ?? cur.cloudCover).round()}%'
      ),
      (
        l10n.weatherPressure,
        '${cur.pressure.round()} hPa'
      ),
      (
        l10n.weatherPrecipitation,
        _fmtAmount(h?.precipitation ?? cur.precipitation)
      ),
    ];
    if (h?.rain != null) chips.add((l10n.weatherRain, _fmtAmount(h!.rain!)));
    if (h?.snowfall != null) {
      chips.add((l10n.weatherSnowfall, _fmtAmount(h!.snowfall!)));
    }
    if (h?.visibility != null) {
      chips.add((
        l10n.weatherVisibility,
        '${(h!.visibility! / 1000).toStringAsFixed(1)} km'
      ));
    }
    if (h?.windSpeed80m != null) {
      chips.add((l10n.weatherWind80m, fmtWind(h!.windSpeed80m!)));
    }
    if (h?.windSpeed120m != null) {
      chips.add((l10n.weatherWind120m, fmtWind(h!.windSpeed120m!)));
    }
    if (h?.cape != null) {
      chips.add((l10n.weatherCape, '${h!.cape!.round()} J/kg'));
    }
    if (h?.soilTemperature != null) {
      chips.add((l10n.weatherSoilTemp, fmtTemp(h!.soilTemperature!)));
    }
    if (h?.shortwaveRadiation != null) {
      chips.add((l10n.weatherRadiation, '${h!.shortwaveRadiation!.round()} W/m²'));
    }
    if (h?.soilMoisture != null) {
      chips.add((
        l10n.weatherSoilMoisture,
        '${(h!.soilMoisture! * 100).toStringAsFixed(1)}%'
      ));
    }
    if (h?.et0 != null) {
      chips.add((l10n.weatherEt0, _fmtAmount(h!.et0!)));
    }
    return chips;
  }

  String _fmtAmount(double v) =>
      '${v.toStringAsFixed(units.precipitation == PrecipitationUnit.inch ? 2 : 1)} '
      '${units.precipitation.symbol}';
}

// ── Small widgets ────────────────────────────────────────────────────────────

class _WindBadge extends StatelessWidget {
  const _WindBadge({
    required this.speed,
    required this.gusts,
    required this.direction,
  });

  final String speed;
  final String gusts;
  final double direction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _WindArrow(direction: direction, size: 28),
          const SizedBox(height: 4),
          Text(speed,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          Text(gusts,
              style: TextStyle(
                  color: Colors.white.withAlpha(150), fontSize: 10)),
        ],
      ),
    );
  }
}

/// An arrow pointing where the wind is blowing TO (Open-Meteo's direction is
/// the direction the wind comes FROM, so we rotate by 180°).
class _WindArrow extends StatelessWidget {
  const _WindArrow({required this.direction, required this.size});

  final double direction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (direction + 180) * math.pi / 180,
      child: Icon(
        Icons.arrow_upward,
        size: size,
        color: Colors.orangeAccent,
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(16),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
                color: Colors.white.withAlpha(140), fontSize: 10),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

/// Material icon for a [WeatherKind].
IconData kindIcon(WeatherKind kind, {bool isDay = true}) {
  switch (kind) {
    case WeatherKind.clear:
      return isDay ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined;
    case WeatherKind.mainlyClear:
      return Icons.wb_cloudy_outlined;
    case WeatherKind.partlyCloudy:
      return Icons.filter_drama;
    case WeatherKind.overcast:
      return Icons.cloud;
    case WeatherKind.fog:
      return Icons.blur_on;
    case WeatherKind.drizzle:
      return Icons.grain;
    case WeatherKind.rain:
      return Icons.water_drop;
    case WeatherKind.freezing:
      return Icons.ac_unit;
    case WeatherKind.snow:
      return Icons.snowing;
    case WeatherKind.showers:
      return Icons.umbrella;
    case WeatherKind.thunder:
      return Icons.thunderstorm;
    case WeatherKind.unknown:
      return Icons.cloud_queue;
  }
}

/// Localized description for a [WeatherKind].
String kindLabel(AppLocalizations l10n, WeatherKind kind) {
  switch (kind) {
    case WeatherKind.clear:
      return l10n.weatherConditionClear;
    case WeatherKind.mainlyClear:
      return l10n.weatherConditionMainlyClear;
    case WeatherKind.partlyCloudy:
      return l10n.weatherConditionPartlyCloudy;
    case WeatherKind.overcast:
      return l10n.weatherConditionOvercast;
    case WeatherKind.fog:
      return l10n.weatherConditionFog;
    case WeatherKind.drizzle:
      return l10n.weatherConditionDrizzle;
    case WeatherKind.rain:
      return l10n.weatherConditionRain;
    case WeatherKind.freezing:
      return l10n.weatherConditionFreezing;
    case WeatherKind.snow:
      return l10n.weatherConditionSnow;
    case WeatherKind.showers:
      return l10n.weatherConditionShowers;
    case WeatherKind.thunder:
      return l10n.weatherConditionThunder;
    case WeatherKind.unknown:
      return l10n.weatherConditionUnknown;
  }
}

/// The forecast horizon requested from Open-Meteo (its documented max), so
/// the daily glance offers the full 16-day outlook.
class OpenMeteoHorizon {
  static const int days = 16;
}
