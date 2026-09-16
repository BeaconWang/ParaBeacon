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
import 'desktop_scrolling.dart';

/// Opens the Weather screen as a full-screen sheet: a nowcast panel, a
/// synchronized hourly detail table, a 16-day glance strip and a location
/// search bar (OpenStreetMap Nominatim).
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

enum _BottomTab { hourly, daily }

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
  _BottomTab _bottomTab = _BottomTab.hourly;
  WeatherModel _model = WeatherModel.bestMatch;
  int _pastDays = 0;

  // Controller of the daily-glance strip, exposed to the mouse-wheel
  // horizontal scrolling helper (see MouseWheelHScroll).
  final ScrollController _dailyGlanceScroll = ScrollController();

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
    _dailyGlanceScroll.dispose();
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

  String _fmtAmount(double v) =>
      '${v.toStringAsFixed(_units.precipitation == PrecipitationUnit.inch ? 2 : 1)} '
      '${_units.precipitation.symbol}';

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
    final slot = _selectedSlot ?? _nowSlot;
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
          if (data.daily.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ForecastSection(
              days: data.daily,
              hours: data.hourly,
              anchorIndex: _hourlySelection,
              nowIndex: _nowIndex,
              timeLabel: _selectedSlot == null
                  ? l10n.weatherNow
                  : _fmtHour(context, _selectedSlot!.time),
              units: _units,
              locale: Localizations.localeOf(context).toString(),
              fmtWind: _fmtWind,
              fmtTemp: _fmtTemp,
              fmtAmount: _fmtAmount,
              elevation: data.elevation,
              currentTime: data.currentTime,
              selectedDate: slot?.time ?? data.daily.first.date,
              onSelectDay: _selectDay,
              onSelectHour: (i) => setState(() => _selectedHour = i),
            ),
          ],
        ],
      ),
    );
  }

  /// The hourly sample covering "now": the first one not before the
  /// provider's current time.
  WeatherHour? get _nowSlot {
    final data = _data;
    final now = data?.currentTime;
    if (data == null || now == null) return null;
    for (final hour in data.hourly) {
      if (!hour.time.isBefore(now)) return hour;
    }
    return data.hourly.isEmpty ? null : data.hourly.last;
  }

  /// Index of [_nowSlot] in the hourly series, or -1 when unknown (the wind
  /// grid dims the columns before it).
  int get _nowIndex {
    final data = _data;
    final now = data?.currentTime;
    if (data == null || now == null) return -1;
    return data.hourly.indexWhere((h) => !h.time.isBefore(now));
  }

  /// Points the panel at [day], keeping the hour of day currently in view so
  /// the wind profile stays comparable from one day to the next.
  void _selectDay(DateTime day) {
    final data = _data;
    if (data == null) return;
    final reference = (_selectedSlot ?? _nowSlot)?.time ?? data.currentTime;
    final targetHour = reference?.hour ?? 12;
    var best = -1;
    var bestDelta = 1 << 30;
    for (var i = 0; i < data.hourly.length; i++) {
      final t = data.hourly[i].time;
      if (t.year != day.year || t.month != day.month || t.day != day.day) {
        continue;
      }
      final delta = (t.hour - targetHour).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    if (best >= 0) setState(() => _selectedHour = best);
  }

  // ── Bottom overlay panel (hourly detail / daily glance) ──────────────────

  Widget _buildBottomPanel(AppLocalizations l10n) {
    final data = _data;

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
                l10n.weatherHourlyDetail,
                selected: _bottomTab == _BottomTab.hourly,
                onTap: () => setState(() => _bottomTab = _BottomTab.hourly),
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
              height: _bottomTab == _BottomTab.hourly
                  ? _HourlyDetailTable.tableHeight
                  : 118,
              child: _bottomTab == _BottomTab.hourly
                  ? _HourlyDetailTable(
                      hours: data.hourly,
                      currentTime: data.currentTime,
                      selectedIndex: _hourlySelection,
                      onSelect: (i) => setState(() => _selectedHour = i),
                    )
                  : MouseWheelHScroll(
                      controller: _dailyGlanceScroll,
                      child: ScrollConfiguration(
                        behavior: const MouseDragScrollBehavior(),
                        child: _buildDailyGlance(data, l10n),
                      ),
                    ),
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

  /// Index the hourly detail selection points at: the scrubbed hour, or "now".
  int get _hourlySelection {
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
      controller: _dailyGlanceScroll,
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

// ── Forecast panels (daily forecast / wind speed) ──────────────────────────

/// The two swipeable forecast panels of the weather sheet:
///
/// * *Forecast daily* — one row per forecast day (day1 … dayN), each with its
///   condition, precipitation, gusts, wind direction and sun times. Tapping a
///   day moves the panel to that date while keeping the hour of day in view.
/// * *Wind speed (time)* — a wind-aloft grid: one row per altitude (highest
///   on top, surface gusts and wind direction at the bottom) and one column
///   per hour, starting at the hour the sheet points at ("now", or the
///   scrubbed hour). Tapping a column scrubs the whole sheet to that hour.
///
/// Swipe left/right — or tap either title — to switch panel. Both pages live
/// in a fixed-height [PageView], so the sheet keeps a stable layout and the
/// panel itself stays the only vertical scrollable.
class _ForecastSection extends StatefulWidget {
  const _ForecastSection({
    required this.days,
    required this.hours,
    required this.anchorIndex,
    required this.timeLabel,
    required this.units,
    required this.locale,
    required this.fmtWind,
    required this.fmtTemp,
    required this.fmtAmount,
    required this.selectedDate,
    required this.onSelectDay,
    required this.onSelectHour,
    this.nowIndex = -1,
    this.elevation,
    this.currentTime,
  });

  /// The forecast horizon, oldest first (day1 … dayN).
  final List<WeatherDay> days;

  /// The full hourly series the wind grid reads its columns from (may include
  /// `past_days` history).
  final List<WeatherHour> hours;

  /// Index in [hours] of the leftmost wind-grid column: the scrubbed hour, or
  /// the hour covering "now". Also the highlighted column.
  final int anchorIndex;

  /// Index in [hours] of the hour covering "now", or -1 when unknown; earlier
  /// columns are dimmed.
  final int nowIndex;

  /// "Now", or the time of the anchor hour when the panel is scrubbed.
  final String timeLabel;

  final WeatherUnits units;

  /// Tag of the active locale, used for the day names.
  final String locale;

  final String Function(double) fmtWind;
  final String Function(double) fmtTemp;

  /// Precipitation amounts, unit-aware (mm or inch).
  final String Function(double) fmtAmount;

  /// Site elevation (m): pressure levels buried in the terrain are dropped.
  final double? elevation;

  /// Location-local "now", used to label the current day.
  final DateTime? currentTime;

  /// Date the panel points at; that day's row is highlighted.
  final DateTime selectedDate;

  /// Jumps the panel to that date, at the hour of day currently in view.
  final ValueChanged<DateTime> onSelectDay;

  /// Scrubs the sheet to the hour of the tapped wind-grid column.
  final ValueChanged<int> onSelectHour;

  @override
  State<_ForecastSection> createState() => _ForecastSectionState();
}

class _ForecastSectionState extends State<_ForecastSection> {
  static const double _dayRowHeight = 40;
  static const double _tabHeight = 26;
  static const double _indicatorHeight = 12;

  static const TextStyle _dimStyle =
      TextStyle(color: Colors.white54, fontSize: 11);
  static const TextStyle _brightStyle = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle _detailStyle =
      TextStyle(color: Colors.white54, fontSize: 10);

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levels = windAloftLevels(elevationMeters: widget.elevation);
    final titles = <String>[
      l10n.weatherForecastDaily,
      l10n.weatherWindSpeedAt(widget.timeLabel),
    ];
    // Height of the tallest page: the sheet then keeps the same layout
    // whichever panel is on screen.
    final height = math.max(
      widget.days.length * _dayRowHeight,
      _WindAloftGrid.heightFor(levels.length),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _tabHeight,
          child: Row(
            children: [
              for (var i = 0; i < titles.length; i++)
                Expanded(child: _buildTab(titles[i], i)),
            ],
          ),
        ),
        _buildIndicator(),
        SizedBox(
          height: height,
          // Mouse drag swipes the panels on desktop too (touch always could);
          // wrapped via ScrollConfiguration so the PageView's own scrollbar
          // suppression keeps applying.
          child: ScrollConfiguration(
            behavior: const MouseDragScrollBehavior(),
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.days.length; i++)
                      _buildDayRow(context, i),
                  ],
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: _WindAloftGrid(
                    levels: levels,
                    hours: widget.hours,
                    anchorIndex: widget.anchorIndex,
                    nowIndex: widget.nowIndex,
                    units: widget.units,
                    locale: widget.locale,
                    onSelectHour: widget.onSelectHour,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Title of one panel; tapping it slides the [PageView] to that panel.
  Widget _buildTab(String title, int index) {
    final selected = _page == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _controller.animateToPage(
          index,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
        child: Align(
          alignment: index == 0 ? Alignment.centerLeft : Alignment.centerRight,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  /// Two-dot pager under the titles.
  Widget _buildIndicator() {
    return SizedBox(
      height: _indicatorHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 2; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _page == i ? 14 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: _page == i ? Colors.orangeAccent : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context);
    final day = widget.days[index];
    final selected = _sameDay(day.date, widget.selectedDate);
    final label = _isToday(index, day)
        ? l10n.weatherToday
        : DateFormat('EEE d', widget.locale).format(day.date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelectDay(day.date),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: _dayRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withAlpha(22) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? Colors.orangeAccent.withAlpha(140)
                  : Colors.white10,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  Icon(kindIcon(day.kind), size: 14, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  Text(widget.fmtTemp(day.tMin), style: _dimStyle),
                  const Text(' / ', style: _dimStyle),
                  Text(widget.fmtTemp(day.tMax), style: _brightStyle),
                  const Spacer(),
                  if (day.precipProbability > 0)
                    Text(
                      l10n.weatherPrecipProbability(
                          day.precipProbability.round()),
                      style: const TextStyle(
                          color: Colors.lightBlueAccent, fontSize: 10),
                    ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Text(
                      widget.fmtWind(day.windMax),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _gustHeatColor(WeatherUnits.windToKmh(
                            day.windMax, widget.units.wind)),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              _buildDetailLine(l10n, day),
            ],
          ),
        ),
      ),
    );
  }

  /// Second line of a day row: condition, precipitation amount, gusts,
  /// dominant wind direction and the sun times.
  Widget _buildDetailLine(AppLocalizations l10n, WeatherDay day) {
    final parts = <String>[
      kindLabel(l10n, day.kind),
      widget.fmtAmount(day.precipSum),
      l10n.weatherGustsShort(day.windGustsMax.round()),
    ];
    final snowfall = day.snowfallSum;
    if (snowfall != null && snowfall > 0) {
      parts.add('${l10n.weatherSnowfall} ${widget.fmtAmount(snowfall)}');
    }
    return Row(
      children: [
        Flexible(
          child: Text(
            parts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _detailStyle,
          ),
        ),
        const SizedBox(width: 6),
        _WindArrow(direction: day.windDirectionDominant, size: 10),
        const SizedBox(width: 2),
        Text('${day.windDirectionDominant.round()}°', style: _detailStyle),
        if (day.sunrise != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.wb_twilight, size: 10, color: Colors.amberAccent),
          Text(_sunTime.format(day.sunrise!), style: _detailStyle),
        ],
        if (day.sunset != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.nightlight_outlined,
              size: 10, color: Colors.indigoAccent),
          Text(_sunTime.format(day.sunset!), style: _detailStyle),
        ],
      ],
    );
  }

  DateFormat get _sunTime => DateFormat('HH:mm', widget.locale);

  bool _isToday(int index, WeatherDay day) {
    final now = widget.currentTime;
    if (now == null) return index == 0;
    return _sameDay(day.date, now);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Wind-aloft grid (centre panel) ───────────────────────────────────────────

/// The detailed wind-speed panel: a compact wind-aloft grid reading the next
/// few hours of the forecast, starting at the hour the sheet points at.
///
/// Layout — a fixed altitude gutter plus one column per hour, every altitude
/// cell carrying an arrow that points where the wind at that level blows TO:
///
/// ```
///  km/h   14   15   16   17   18   19   20   ← hours from the anchor
///  5600m ↗35  ↗36  →38  →41  →43  ↘44  ↘45
///  3000m ↗22  ↗23  →25  →28  →30  →31  ↘30  ← one row per wind-aloft level,
///  1450m ↑14  ↗15  ↗17  →19  →21  →20  →18    highest on top
///   120m  ↑9  ↑10  ↗11  ↗13  ↗14  →13  →12
///    80m  ↑8   ↑9  ↑10  ↗12  ↗13  ↗12  →11
///    10m  ↑5   ↑6   ↑7   ↑8   ↑9   ↑8   ↗7  ← surface
///  Gusts  11   13   15   18   21   19   16
/// ```
///
/// Every cell is tinted by the same Beaufort-like heat scale used elsewhere in
/// the sheet, with the tint strength scaled against the fastest value on
/// screen, so a glance shows both *how strong* and *when* the wind builds —
/// and the arrow column shows how the wind veers with height and with time
/// (a strong shear between two rows is what a pilot is looking for).
/// Tapping a column scrubs the whole sheet to that hour.
class _WindAloftGrid extends StatelessWidget {
  const _WindAloftGrid({
    required this.levels,
    required this.hours,
    required this.anchorIndex,
    required this.units,
    required this.locale,
    required this.onSelectHour,
    this.nowIndex = -1,
  });

  /// Wind-aloft levels, lowest first (as [windAloftLevels] returns them); the
  /// grid renders them top-down highest-first.
  final List<WindAloftLevel> levels;

  /// The full hourly series.
  final List<WeatherHour> hours;

  /// Index in [hours] of the leftmost column; also the highlighted column.
  final int anchorIndex;

  /// Index in [hours] of "now" (-1 when unknown); earlier columns are dimmed.
  final int nowIndex;

  final WeatherUnits units;
  final String locale;

  /// Reports the hour index of the tapped column.
  final ValueChanged<int> onSelectHour;

  static const double _headerHeight = 18;
  static const double _rowHeight = 22;
  static const double _gutterWidth = 62;

  /// Narrowest a readable hour column gets (arrow + value); the count of
  /// visible hours is derived from the available width.
  static const double _minColumnWidth = 42;
  static const int _maxColumns = 10;

  /// Rows below the altitudes: the surface gust row.
  static const int _surfaceRows = 1;

  /// Fixed height of the panel for [levelCount] altitude rows.
  static double heightFor(int levelCount) =>
      _headerHeight + (levelCount + _surfaceRows) * _rowHeight;

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty || levels.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    // Highest altitude on top, surface at the bottom, right above the
    // surface gust row.
    final rows = levels.reversed.toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(0.0, constraints.maxWidth - _gutterWidth);
        final fits = (available / _minColumnWidth).floor();
        final columns =
            math.min(math.min(math.max(1, fits), _maxColumns), hours.length);
        // Keep the anchor hour leftmost, unless that would run past the end
        // of the series (then show the last full window).
        final start =
            math.min(math.max(0, anchorIndex), hours.length - columns);
        final columnWidth = available / columns;
        final scaleMax = _scaleMax(start, columns, rows);

        return SizedBox(
          height: heightFor(rows.length),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGutter(l10n, rows),
              for (var i = start; i < start + columns; i++)
                SizedBox(
                  width: columnWidth,
                  child: _buildColumn(i, rows, scaleMax),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Gutter (altitude labels) ───────────────────────────────────────────────

  Widget _buildGutter(AppLocalizations l10n, List<WindAloftLevel> rows) {
    return SizedBox(
      width: _gutterWidth,
      child: Column(
        children: [
          SizedBox(
            height: _headerHeight,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Text(
                  units.wind.symbol,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
            ),
          ),
          for (final level in rows)
            _gutterLabel(
              '${level.metersAgl} m',
              // The three levels Open-Meteo reports directly (10/80/120 m) are
              // the ones a pilot launches into: keep them brighter.
              bright: level.pressureHPa == null,
            ),
          _gutterLabel(l10n.weatherRowGusts, small: true),
        ],
      ),
    );
  }

  Widget _gutterLabel(String label, {bool bright = false, bool small = false}) {
    return SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            label,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: bright ? Colors.white70 : Colors.white38,
              fontSize: small ? 9 : 10,
            ),
          ),
        ),
      ),
    );
  }

  // ── Hour columns ───────────────────────────────────────────────────────────

  Widget _buildColumn(
    int index,
    List<WindAloftLevel> rows,
    double? scaleMax,
  ) {
    final hour = hours[index];
    final selected = index == anchorIndex;
    final past = nowIndex >= 0 && index < nowIndex;
    final dayStart =
        index > 0 && hours[index - 1].time.day != hour.time.day;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelectHour(index),
      child: Opacity(
        opacity: past ? 0.45 : 1,
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: _headerHeight,
                  child: Center(
                    child: Text(
                      DateFormat('HH', locale).format(hour.time),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? Colors.orangeAccent
                            : (dayStart ? Colors.white : Colors.white54),
                      ),
                    ),
                  ),
                ),
                for (final level in rows)
                  _valueCell(
                    level.read(hour),
                    scaleMax,
                    direction: level.readDirection(hour),
                  ),
                _valueCell(hour.windGusts, scaleMax, gust: true),
              ],
            ),
            // Day boundary, so a column reading "01" is not mistaken for the
            // same afternoon.
            if (dayStart)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 1,
                child: ColoredBox(color: Color(0x2EFFFFFF)),
              ),
            if (selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                        side: BorderSide(
                          color: Colors.orangeAccent.withAlpha(170),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One wind cell: an arrow pointing where the wind blows TO, followed by the
  /// rounded speed; tinted by the heat scale and shaded in proportion to the
  /// fastest value currently on screen.
  ///
  /// [direction] is the degrees the wind comes FROM (null when the level or
  /// the model carries no direction — the value is then shown on its own).
  /// The gust row has no direction of its own and reuses the surface arrow's
  /// absence, standing out through its outline instead.
  Widget _valueCell(
    double? value,
    double? scaleMax, {
    double? direction,
    bool gust = false,
  }) {
    if (value == null) {
      return const SizedBox(
        height: _rowHeight,
        child: Center(
          child: Text('–', style: TextStyle(color: Colors.white24, fontSize: 10)),
        ),
      );
    }
    final frac = scaleMax == null || scaleMax <= 0
        ? 0.0
        : (value / scaleMax).clamp(0.0, 1.0);
    final heat = _gustHeatColor(WeatherUnits.windToKmh(value, units.wind));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1),
      child: Container(
        height: _rowHeight - 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: heat.withAlpha((55 + frac * 165).round()),
          borderRadius: BorderRadius.circular(4),
          border: gust
              ? Border.all(color: heat.withAlpha(190), width: 0.8)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (direction != null) ...[
              // White, not the usual accent: the cell tint underneath already
              // carries the colour information.
              _WindArrow(direction: direction, size: 11, color: Colors.white),
              const SizedBox(width: 1),
            ],
            Text(
              '${value.round()}',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: gust ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tint scale of the visible window: the fastest value across the shown
  /// hours (all altitudes plus gusts), rounded up to a whole 5 units. Using
  /// the window — not the whole series — keeps a calm evening readable.
  double? _scaleMax(int start, int columns, List<WindAloftLevel> rows) {
    double? max;
    void consider(double? value) {
      if (value == null) return;
      if (max == null || value > max!) max = value;
    }

    for (var i = start; i < start + columns; i++) {
      final hour = hours[i];
      for (final level in rows) {
        consider(level.read(hour));
      }
      consider(hour.windGusts);
    }
    final peak = max;
    if (peak == null) return null;
    return math.max(5.0, ((peak / 5).ceil() * 5).toDouble());
  }
}

// ── Hourly detail table ──────────────────────────────────────────────────────

/// Windy-style hourly detail table for the bottom panel: a fixed label
/// gutter plus one scrollable column per hour (hourly interval). Rows are
/// the day header, hour + condition icon, temperature (tinted by the
/// temperature palette), rain amount, wind speed, wind gusts (tinted by a
/// Beaufort-like heat scale) and wind-direction arrows. Tapping a column
/// selects that hour; the selected column gets the rounded selection box.
class _HourlyDetailTable extends StatefulWidget {
  const _HourlyDetailTable({
    required this.hours,
    required this.selectedIndex,
    required this.onSelect,
    this.currentTime,
  });

  /// The full hourly series (may include `past_days` history, rendered
  /// dimmed before [currentTime]).
  final List<WeatherHour> hours;

  /// The provider's current time (location-local): the table auto-scrolls
  /// here and dims earlier hours.
  final DateTime? currentTime;

  /// Selected hour index.
  final int selectedIndex;

  /// Reports the tapped hour index.
  final ValueChanged<int> onSelect;

  // Row heights (mirrored by the gutter).
  static const double _headerH = 20;
  static const double _hourH = 18;
  static const double _iconH = 32;
  static const double _tempH = 30;
  static const double _rainH = 26;
  static const double _windH = 26;
  static const double _gustH = 26;
  static const double _dirH = 26;

  /// Total table height (gutter and columns share the same rows).
  static const double tableHeight =
      _headerH + _hourH + _iconH + _tempH + _rainH + _windH + _gustH + _dirH;

  static const double _colWidth = 56;

  @override
  State<_HourlyDetailTable> createState() => _HourlyDetailTableState();
}

class _HourlyDetailTableState extends State<_HourlyDetailTable> {
  final ScrollController _scroll = ScrollController();
  bool _autoScrolled = false;

  /// Index of the first hour at-or-after the provider's current time.
  int get _nowIndex {
    final t = widget.currentTime;
    if (t == null) return -1;
    return widget.hours.indexWhere((h) => !h.time.isBefore(t));
  }

  @override
  void initState() {
    super.initState();
    _scheduleAutoScroll();
  }

  @override
  void didUpdateWidget(_HourlyDetailTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hours != widget.hours) {
      _autoScrolled = false;
      _scheduleAutoScroll();
    }
  }

  /// Centers "now" in the viewport on first layout (and after a reload).
  void _scheduleAutoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoScrolled || !_scroll.hasClients) return;
      final now = _nowIndex;
      if (now < 0) return;
      final target =
          (now * _HourlyDetailTable._colWidth - _scroll.position.viewportDimension / 2)
              .clamp(0.0, math.max(0, _scroll.position.maxScrollExtent).toDouble());
      _scroll.jumpTo(target);
      _autoScrolled = true;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hours.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final units = WeatherUnitSettings.instance.units;
    final now = _nowIndex;

    return MouseWheelHScroll(
      controller: _scroll,
      child: ScrollConfiguration(
        behavior: const MouseDragScrollBehavior(),
        child: SizedBox(
          height: _HourlyDetailTable.tableHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGutter(l10n, units),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  itemExtent: _HourlyDetailTable._colWidth,
                  itemCount: widget.hours.length,
                  itemBuilder: (context, i) => _buildColumn(i, locale, units, now),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gutter (fixed row labels) ─────────────────────────────────────────────

  Widget _gutterLabel(double height, String label, String? unit) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 4),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(unit,
                  style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGutter(AppLocalizations l10n, WeatherUnits units) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _HourlyDetailTable._headerH),
          // "Hours" spans the hour-label + icon rows.
          SizedBox(
            height: _HourlyDetailTable._hourH + _HourlyDetailTable._iconH,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: Colors.white54),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      l10n.weatherRowHours,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _gutterLabel(_HourlyDetailTable._tempH, l10n.weatherRowTemperature,
              units.temperature.symbol),
          _gutterLabel(_HourlyDetailTable._rainH, l10n.weatherRowRain,
              units.precipitation.symbol),
          _gutterLabel(
              _HourlyDetailTable._windH, l10n.weatherRowWind, units.wind.symbol),
          _gutterLabel(
              _HourlyDetailTable._gustH, l10n.weatherRowGusts, units.wind.symbol),
          _gutterLabel(_HourlyDetailTable._dirH, l10n.weatherRowWindDir, null),
        ],
      ),
    );
  }

  // ── Hour columns ──────────────────────────────────────────────────────────

  Widget _buildColumn(int i, String locale, WeatherUnits units, int now) {
    final h = widget.hours[i];
    final sel = i == widget.selectedIndex;
    final dayStart = i == 0 || widget.hours[i - 1].time.day != h.time.day;
    final past = now >= 0 && i < now;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelect(i),
      child: SizedBox(
        width: _HourlyDetailTable._colWidth,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                _headerCell(i, dayStart, locale),
                _cell(
                  _HourlyDetailTable._hourH,
                  dayStart: dayStart,
                  past: past,
                  child: Text(
                    DateFormat('HH:mm', locale).format(h.time),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      color: sel ? Colors.orangeAccent : Colors.white70,
                    ),
                  ),
                ),
                _cell(
                  _HourlyDetailTable._iconH,
                  dayStart: dayStart,
                  past: past,
                  child: Icon(
                    kindIcon(h.kind, isDay: h.isDay ?? true),
                    size: 18,
                    color: Colors.orangeAccent,
                  ),
                ),
                _cell(
                  _HourlyDetailTable._tempH,
                  dayStart: dayStart,
                  past: past,
                  band: _tempPaletteColor(WeatherUnits.temperatureToCelsius(
                          h.temperature, units.temperature))
                      .withAlpha(44),
                  child: Text(
                    '${h.temperature.round()}°',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                _buildRainCell(h, units, dayStart, past),
                _cell(
                  _HourlyDetailTable._windH,
                  dayStart: dayStart,
                  past: past,
                  child: Text(
                    '${h.windSpeed.round()}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                _cell(
                  _HourlyDetailTable._gustH,
                  dayStart: dayStart,
                  past: past,
                  band: _gustHeatColor(
                          WeatherUnits.windToKmh(h.windGusts, units.wind))
                      .withAlpha(190),
                  child: Text(
                    '${h.windGusts.round()}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                _cell(
                  _HourlyDetailTable._dirH,
                  dayStart: dayStart,
                  past: past,
                  child: _WindArrow(direction: h.windDirection, size: 13),
                ),
              ],
            ),
            // Rounded selection box around the column body (below the day
            // header), like Windy's hour cursor.
            if (sel)
              Positioned(
                top: _HourlyDetailTable._headerH,
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Colors.white.withAlpha(22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                        side: BorderSide(
                          color: Colors.orangeAccent.withAlpha(180),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRainCell(WeatherHour h, WeatherUnits units, bool dayStart,
      bool past) {
    final v = h.precipitation;
    final hasRain = v >= 0.05;
    return _cell(
      _HourlyDetailTable._rainH,
      dayStart: dayStart,
      past: past,
      child: hasRain
          ? Text(
              v.toStringAsFixed(
                  units.precipitation == PrecipitationUnit.inch ? 2 : 1),
              style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600),
            )
          : null,
      rainBar: hasRain
          ? Colors.lightBlueAccent
              .withAlpha(((v / 4).clamp(0.12, 1.0) * 255).round())
          : null,
    );
  }

  Widget _headerCell(int i, bool dayStart, String locale) {
    if (!dayStart) return const SizedBox(height: _HourlyDetailTable._headerH);
    final t = widget.hours[i].time;
    return SizedBox(
      height: _HourlyDetailTable._headerH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 1,
            child: ColoredBox(color: Color(0x2EFFFFFF)),
          ),
          Positioned(
            left: 5,
            top: 0,
            bottom: 0,
            // Clip.none lets the label span the whole day's columns.
            child: Center(
              child: Text(
                DateFormat('EEEE d', locale).format(t).toUpperCase(),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    double height, {
    Widget? child,
    Color? band,
    Color? rainBar,
    required bool dayStart,
    required bool past,
  }) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (band != null) Positioned.fill(child: ColoredBox(color: band)),
          if (rainBar != null)
            Positioned(
              left: 5,
              right: 5,
              bottom: 2,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: rainBar,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          if (dayStart)
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 1,
              child: ColoredBox(color: Color(0x2EFFFFFF)),
            ),
          if (child != null)
            Center(
              child: Opacity(opacity: past ? 0.45 : 1, child: child),
            ),
        ],
      ),
    );
  }
}

/// Maps a °C value onto the classic weather-map temperature ramp; tints the
/// temperature row of the hourly detail table.
Color _tempPaletteColor(double celsius) {
  // Non-const: double map keys have no primitive equality.
  final stops = <double, Color>{
    -25: const Color(0xFF6A3DE8),
    -12: const Color(0xFF3D5AFE),
    -2: const Color(0xFF00BCD4),
    6: const Color(0xFF4CAF50),
    14: const Color(0xFFFFC107),
    22: const Color(0xFFFF9800),
    30: const Color(0xFFF4511E),
    40: const Color(0xFFD50000),
  };
  if (celsius <= stops.keys.first) return stops.values.first;
  double? prevT;
  Color? prevC;
  for (final entry in stops.entries) {
    if (celsius <= entry.key) {
      final t = (celsius - prevT!) / (entry.key - prevT);
      return Color.lerp(prevC, entry.value, t.clamp(0.0, 1.0))!;
    }
    prevT = entry.key;
    prevC = entry.value;
  }
  return stops.values.last;
}

/// Beaufort-like heat scale for the gust row (green → cyan → yellow →
/// orange → red as gusts strengthen). Values are in canonical km/h.
Color _gustHeatColor(double kmh) {
  if (kmh < 15) return const Color(0xFF43A047);
  if (kmh < 30) return const Color(0xFF26C6DA);
  if (kmh < 45) return const Color(0xFFFFCA28);
  if (kmh < 60) return const Color(0xFFFF9800);
  return const Color(0xFFEF5350);
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
  const _WindArrow({
    required this.direction,
    required this.size,
    this.color = Colors.orangeAccent,
  });

  final double direction;
  final double size;

  /// Arrow colour; the wind-aloft grid overrides it to white because its
  /// cells already carry a coloured tint.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (direction + 180) * math.pi / 180,
      child: Icon(
        Icons.arrow_upward,
        size: size,
        color: color,
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
