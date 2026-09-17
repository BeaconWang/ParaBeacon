// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ParaBeacon';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get add => 'Add';

  @override
  String get preferences => 'Preferences';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get varioSoundSettings => 'Vario sound settings';

  @override
  String get varioSoundSettingsSubtitle =>
      'Sound, volume, thresholds, pitch and waveform';

  @override
  String get gridSize => 'Grid size';

  @override
  String get bluetoothSensor => 'Bluetooth Sensor';

  @override
  String get bluetoothSensorSubtitle => 'Connect an external BLE sensor';

  @override
  String get trackRecording => 'Track recording';

  @override
  String trackRecordingSubtitle(String interval, String detail) {
    return '$interval · $detail';
  }

  @override
  String get recordingIntervalEvery1s => 'Every 1 s';

  @override
  String get recordingIntervalSmart => 'Smart';

  @override
  String get recordingDetailFull => 'full data';

  @override
  String get recordingDetailXcTrack => 'XCTrack style';

  @override
  String get debug => 'Debug';

  @override
  String get simulatedFlightData => 'Simulated flight data';

  @override
  String get simulatedFlightDataSubtitle =>
      'Feed fake sensor values when no BLE device is connected';

  @override
  String get fakeGpsInChina => 'Fake GPS location in China';

  @override
  String get fakeGpsInChinaSubtitle =>
      'Start the simulated flight over China (near Chengdu)';

  @override
  String get trackRecordingSmart => 'Smart (default)';

  @override
  String get trackRecordingSmartSubtitle =>
      'At least 1 s apart, and only when moved ≥ 3 m or altitude changed ≥ 1 m';

  @override
  String get trackRecordingEverySecond => 'Every 1 second';

  @override
  String get trackRecordingEverySecondSubtitle =>
      'Store one point per second regardless of movement';

  @override
  String get trackRecordingChooseHint =>
      'Choose how often a track point is stored during flight.';

  @override
  String get recordMoreInformation => 'Record more information';

  @override
  String get recordMoreInformationFull =>
      'Full data per point: vario, wind, pressure, temperature, GPS accuracy, satellites, battery, heart rate';

  @override
  String get recordMoreInformationXcTrack =>
      'XCTrack style: position, baro/GPS altitude, heading, speed and time only';

  @override
  String get clearAllControlsTitle => 'Clear all controls?';

  @override
  String get clearAllControlsMessage =>
      'This removes every control from the dashboard. This cannot be undone.';

  @override
  String get editMode => 'Edit Mode';

  @override
  String pageOfPages(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get addControl => 'Add Control';

  @override
  String get addPage => 'Add Page';

  @override
  String get deletePage => 'Delete Page';

  @override
  String get clearAllControls => 'Clear all controls';

  @override
  String controlsPlaced(int count) {
    return '$count placed';
  }

  @override
  String get flights => 'Flights';

  @override
  String get flightsSubtitle => 'Recorded flights';

  @override
  String get tools => 'Tools';

  @override
  String get weather => 'Weather';

  @override
  String get weatherSubtitle => 'Forecast at your location';

  @override
  String get weatherRefresh => 'Refresh';

  @override
  String get weatherNow => 'Now';

  @override
  String get weatherToday => 'Today';

  @override
  String get weatherHourly => 'Next 24 hours';

  @override
  String get weatherDaily => '5-day outlook';

  @override
  String weatherFeelsLike(int temp) {
    return 'Feels like $temp°';
  }

  @override
  String get weatherWind => 'Wind';

  @override
  String weatherSpeedKmh(int speed) {
    return '$speed km/h';
  }

  @override
  String weatherGustsKmh(int speed) {
    return 'Gusts $speed km/h';
  }

  @override
  String weatherGustsShort(int speed) {
    return 'G $speed';
  }

  @override
  String weatherPrecipProbability(int percent) {
    return '$percent%';
  }

  @override
  String get weatherHumidity => 'Humidity';

  @override
  String get weatherCloudCover => 'Cloud cover';

  @override
  String get weatherPrecipitation => 'Precipitation';

  @override
  String get weatherPressure => 'Pressure';

  @override
  String get weatherNoGps =>
      'No GPS fix yet. Enable location services and try again.';

  @override
  String get weatherLoadFailed =>
      'Couldn\'t load the forecast. Check your connection and try again.';

  @override
  String get weatherRetry => 'Retry';

  @override
  String get weatherDataBy => 'Data by Open-Meteo';

  @override
  String get weatherConditionClear => 'Clear';

  @override
  String get weatherConditionMainlyClear => 'Mainly clear';

  @override
  String get weatherConditionPartlyCloudy => 'Partly cloudy';

  @override
  String get weatherConditionOvercast => 'Overcast';

  @override
  String get weatherConditionFog => 'Fog';

  @override
  String get weatherConditionDrizzle => 'Drizzle';

  @override
  String get weatherConditionRain => 'Rain';

  @override
  String get weatherConditionFreezing => 'Freezing rain';

  @override
  String get weatherConditionSnow => 'Snow';

  @override
  String get weatherConditionShowers => 'Showers';

  @override
  String get weatherConditionThunder => 'Thunderstorm';

  @override
  String get weatherConditionUnknown => 'Unknown';

  @override
  String get weatherSearchHint => 'Search city or place…';

  @override
  String get weatherSearchFailed => 'Search failed. Check your connection.';

  @override
  String get weatherNoResults => 'No matching places';

  @override
  String get weatherTabDaily => 'Daily';

  @override
  String get weatherRowHours => 'Hours';

  @override
  String get weatherRowTemperature => 'Temperature';

  @override
  String get weatherRowRain => 'Rain';

  @override
  String get weatherRowWind => 'Wind';

  @override
  String get weatherRowGusts => 'Wind gusts';

  @override
  String get weatherRowWindDir => 'Wind dir.';

  @override
  String get weatherModel => 'Model';

  @override
  String get weatherPastDays => 'Past days';

  @override
  String get weatherPastDaysOff => 'Off';

  @override
  String weatherPastDaysShort(int days) {
    return '$days d';
  }

  @override
  String get weatherPickOnMap => 'Pick on map';

  @override
  String get weatherFavorites => 'Saved locations';

  @override
  String get weatherFavoriteAdd => 'Save this location';

  @override
  String get weatherFavoriteRemove => 'Remove from saved';

  @override
  String weatherFavoriteSaved(String name) {
    return 'Saved “$name”';
  }

  @override
  String get weatherFavoriteRemoved => 'Removed from saved locations';

  @override
  String get weatherFavoritesEmpty => 'No saved locations yet';

  @override
  String get weatherFavoritesManage => 'Manage saved locations';

  @override
  String get mapPickerTitle => 'Pick a location';

  @override
  String get mapPickerHint =>
      'Drag the map to place the crosshair, then confirm.';

  @override
  String get mapPickerConfirm => 'Use this location';

  @override
  String get mapPickerMyLocation => 'My location';

  @override
  String get weatherUnits => 'Units';

  @override
  String get weatherUnitTemperature => 'Temperature';

  @override
  String get weatherUnitWindSpeed => 'Wind speed';

  @override
  String get weatherUnitPrecipitation => 'Precipitation';

  @override
  String get weatherSunrise => 'Sunrise';

  @override
  String get weatherSunset => 'Sunset';

  @override
  String get weatherVisibility => 'Visibility';

  @override
  String get weatherSoilTemp => 'Soil temp';

  @override
  String get weatherSoilMoisture => 'Soil moisture';

  @override
  String get weatherRadiation => 'Radiation';

  @override
  String get weatherEt0 => 'ET₀ evapotranspiration';

  @override
  String get weatherCape => 'CAPE';

  @override
  String get weatherSnowfall => 'Snowfall';

  @override
  String get weatherRain => 'Rain';

  @override
  String get weatherCloudLow => 'Low clouds';

  @override
  String get weatherCloudMid => 'Mid clouds';

  @override
  String get weatherCloudHigh => 'High clouds';

  @override
  String get weatherHourlyDetail => 'Hourly detail';

  @override
  String get weatherForecastDaily => 'Forecast daily';

  @override
  String weatherWindSpeedAt(String time) {
    return 'Wind speed · $time';
  }

  @override
  String get weatherUpperWinds => 'Upper winds';

  @override
  String get weatherWind80m => '80 m wind';

  @override
  String get weatherWind120m => '120 m wind';

  @override
  String weatherAltitudeMeters(int meters) {
    return '$meters m';
  }

  @override
  String weatherSourceBy(String source) {
    return 'Source: $source';
  }

  @override
  String weatherFallbackNotice(String source) {
    return '$source unavailable — served by fallback';
  }

  @override
  String get pageIcon => 'Page icon';

  @override
  String gridSizePx(int value) {
    return '$value px';
  }

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageSystemDescription => 'Follow the device language';

  @override
  String get languageEnglishDescription => 'English';

  @override
  String get languageChineseSimplifiedDescription => 'Simplified Chinese';

  @override
  String get languageApplyNote =>
      'Changes apply instantly, no restart needed. Your choice is saved on this device.';

  @override
  String get themeDarkThemes => 'Dark themes';

  @override
  String get themeLightThemes => 'Light themes';

  @override
  String get themeHighContrast => 'High contrast (WCAG AAA)';

  @override
  String get themeApplyNote =>
      'Changes apply instantly, no restart needed. Your choice is saved on this device.\nHigh-contrast themes: pure black/white backgrounds with high-saturation accents — ideal for bright sunlight, eye strain, and older users.';

  @override
  String get themeDarkCyan => 'Dark Cyan (default)';

  @override
  String get themeDarkSlate => 'Dark Slate';

  @override
  String get themeDarkAmber => 'Dark Amber (night vision)';

  @override
  String get themeDarkForest => 'Dark Forest';

  @override
  String get themeDarkOcean => 'Dark Ocean';

  @override
  String get themeLightSky => 'Light Sky';

  @override
  String get themeLightSand => 'Light Sand';

  @override
  String get themeLightMint => 'Light Mint';

  @override
  String get themeLightPaper => 'Light Paper';

  @override
  String get themeLightLavender => 'Light Lavender';

  @override
  String get themeDarkContrast => 'Dark High-Contrast';

  @override
  String get themeLightContrast => 'Light High-Contrast';

  @override
  String get themeDarkCyanDesc => 'Dark base + cyan accents (classic default)';

  @override
  String get themeDarkSlateDesc => 'Business dark grey + blue-violet accents';

  @override
  String get themeDarkAmberDesc =>
      'Cockpit amber, easy on the eyes for long night flights';

  @override
  String get themeDarkForestDesc => 'Deep forest green + golden sunlight';

  @override
  String get themeDarkOceanDesc => 'Deep ocean blue-violet + teal coral';

  @override
  String get themeLightSkyDesc =>
      'High contrast in sunlight, best for daytime flying';

  @override
  String get themeLightSandDesc =>
      'Warm sand base, comfortable for extended use';

  @override
  String get themeLightMintDesc => 'Fresh mint green, easy on the eyes';

  @override
  String get themeLightPaperDesc =>
      'Aeronautical chart paper style, nostalgic VFR';

  @override
  String get themeLightLavenderDesc =>
      'Soft lavender + deep purple, gentle on the eyes';

  @override
  String get themeDarkContrastDesc =>
      'Pure black + high-saturation yellow (WCAG AAA)';

  @override
  String get themeLightContrastDesc =>
      'Pure white + black + deep blue (WCAG AAA)';

  @override
  String get controlKindData => 'Data Control';

  @override
  String get controlKindWidget => 'Widget Control';

  @override
  String get controlAltitude => 'Altitude';

  @override
  String get controlMaxAltitude => 'Max Altitude';

  @override
  String get controlVerticalSpeed => 'Vertical Speed';

  @override
  String get controlGroundSpeed => 'Ground Speed';

  @override
  String get controlGlide => 'Glide';

  @override
  String get controlHeading => 'Heading';

  @override
  String get controlLocation => 'Location';

  @override
  String get controlWindSpeed => 'Wind Speed';

  @override
  String get controlWindDirection => 'Wind Direction';

  @override
  String get controlPressure => 'Pressure';

  @override
  String get controlTemperature => 'Temperature';

  @override
  String get controlClock => 'Clock';

  @override
  String get controlFlightTime => 'Flight Time';

  @override
  String get controlAirTime => 'Air Time';

  @override
  String get controlDistanceToTakeoff => 'Distance to Takeoff';

  @override
  String get controlSunrise => 'Sunrise';

  @override
  String get controlSunset => 'Sunset';

  @override
  String get controlStatusLine => 'Status Line';

  @override
  String get controlCompassWind => 'Compass and Wind';

  @override
  String get controlSensorBattery => 'Sensor Battery';

  @override
  String get controlHeartRate => 'Heart Rate';

  @override
  String get controlVario => 'Vario';

  @override
  String get controlDebugSensor => 'Debug Sensor';

  @override
  String get controlDataMonitor => 'Data Monitor';

  @override
  String get controlMap => 'Map';

  @override
  String get controlFlightButton => 'Flight Button';

  @override
  String get controlUnknown => 'Unknown';

  @override
  String controlSettingsTitle(String control) {
    return '$control settings';
  }

  @override
  String get searchControls => 'Search controls';

  @override
  String get noControlsAvailable => 'No controls available yet';

  @override
  String noControlsMatch(String query) {
    return 'No controls match \"$query\"';
  }

  @override
  String get noControlsInDirectory => 'No controls in this directory yet';

  @override
  String get settings => 'Settings';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get bringToFront => 'Bring to Front';

  @override
  String get sendToBack => 'Send to Back';

  @override
  String get controlNoSettings => 'This control has no settings.';

  @override
  String get controlGpsAltitude => 'GPS Altitude';

  @override
  String get controlBaroAltitude => 'Baro Altitude';

  @override
  String get controlWindDir => 'Wind Dir';

  @override
  String get locationNoFix => 'No GPS fix';

  @override
  String get flightButtonStart => 'START';

  @override
  String get flightButtonStop => 'STOP';

  @override
  String get flightButtonAuto => 'AUTO';

  @override
  String get flightButtonAutoTooltip => 'Auto-detect take-off / landing';

  @override
  String flightRecordingReadout(int points, String km) {
    return 'REC · $points pts · $km km';
  }

  @override
  String get settingShowTitle => 'Show title';

  @override
  String get settingShowBorder => 'Show border';

  @override
  String get settingBorderColor => 'Border color';

  @override
  String get settingBorderWidth => 'Border width';

  @override
  String get settingCornerRadius => 'Corner radius';

  @override
  String get settingControlOpacity => 'Control opacity';

  @override
  String get settingBackgroundColor => 'Background color';

  @override
  String get settingBackgroundOpacity => 'Background opacity';

  @override
  String get settingTextColor => 'Text color';

  @override
  String get settingScaleMax => 'Scale (max)';

  @override
  String get settingAveragingInterval => 'Averaging interval';

  @override
  String get settingCoordinateFormat => 'Coordinate format';

  @override
  String get settingCoordinateDecimal => 'Decimal degrees';

  @override
  String get settingCoordinateDms => 'Deg / min / sec';

  @override
  String get settingAltitudeSource => 'Altitude source';

  @override
  String get settingAltitudeSourceAuto => 'Auto (baro if available)';

  @override
  String get settingAltitudeSourceGps => 'GPS altitude';

  @override
  String get settingAltitudeSourceBaro => 'Barometric altitude';

  @override
  String get settingFormat => 'Format';

  @override
  String get settingFormatDegrees => 'Degrees (0-360°)';

  @override
  String get settingFormatCardinal => 'Cardinal (N, NE, …)';

  @override
  String get settingShowSeconds => 'Show seconds';

  @override
  String get settingShowAutoDetect => 'Show auto-detect checkbox';

  @override
  String get settingShowGps => 'Show GPS status';

  @override
  String get settingGpsDetailed => 'Detailed GPS status';

  @override
  String get settingShowBluetooth => 'Show Bluetooth sensor';

  @override
  String get settingShowSensorBattery => 'Show sensor battery';

  @override
  String get settingShowDeviceBattery => 'Show device battery';

  @override
  String get settingShowFlightTimer => 'Show flight timer';

  @override
  String get settingShowClock => 'Show clock';

  @override
  String get settingTimeFormat => 'Time format';

  @override
  String get settingTimeFormat24h => '24-hour';

  @override
  String get settingTimeFormat12h => '12-hour (AM/PM)';

  @override
  String get settingGlideAvg => 'Glide averaging';

  @override
  String get settingGlideAvgInstant => 'Instant';

  @override
  String settingGlideAvgSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get settingGlideLeadingOne => 'Show leading \"1:\"';

  @override
  String get settingGlideShowVario => 'Show vario in lift';

  @override
  String get settingFollowPosition => 'Follow position';

  @override
  String get settingZoom => 'Zoom';

  @override
  String get settingMapSource => 'Map source';

  @override
  String get settingMapSourceNone => 'None (no basemap)';

  @override
  String get settingMapSourceOsm => 'OpenStreetMap';

  @override
  String get settingMapSourceOsmFr => 'OSM France';

  @override
  String get settingMapSourceCartoDark => 'Carto Dark';

  @override
  String get settingMapSourceCartoVoyager => 'Carto Voyager';

  @override
  String get settingMapSourceAmap => 'AMap (AutoNavi)';

  @override
  String get settingMapSourceAmapSat => 'AMap Satellite';

  @override
  String get settingRotation => 'Rotation';

  @override
  String get settingRotationNorth => 'North at the top';

  @override
  String get settingRotationTrack => 'Track up (heading)';

  @override
  String get settingShowNorth => 'Display North direction';

  @override
  String get settingPilotArrowSize => 'Pilot arrow size';

  @override
  String get settingLineThickness => 'Thickness of lines';

  @override
  String get settingTracklogLength => 'Tracklog length (0 = all)';

  @override
  String get settingLatestThermals => 'Show N latest thermals';

  @override
  String get settingPreferOffline => 'Prefer offline maps (.mbtiles)';

  @override
  String get settingShowTrack => 'Show flight track';

  @override
  String get settingShowThermal => 'Show thermal assistant';

  @override
  String get settingWindAlgorithm => 'Include wind in computation';

  @override
  String get settingWindAlgorithmNone => 'None';

  @override
  String get settingWindAlgorithmClassic => 'Classic';

  @override
  String get settingWindAlgorithmParticle => 'Particle drift';

  @override
  String get settingShowWind => 'Show wind';

  @override
  String get settingShowSun => 'Show sun position';

  @override
  String get settingShowBearing => 'Show bearing (course) line';

  @override
  String get settingShowTakeoffLine => 'Show line to take-off';

  @override
  String get settingShowScale => 'Display map scale';

  @override
  String get settingShowAirspace => 'Show airspace';

  @override
  String get settingShowLegend => 'Show vario legend';

  @override
  String get settingShowZoomLevel => 'Show zoom level';

  @override
  String get settingShowAttribution => 'Show map attribution';

  @override
  String get settingShowStatus => 'Show HDG/ALT & GPS status';

  @override
  String get dataMonitorTitle => 'Data Monitor';

  @override
  String get dataMonitorLive => 'LIVE';

  @override
  String get dataMonitorFix => 'Fix';

  @override
  String get dataMonitorYes => 'YES';

  @override
  String get dataMonitorNo => 'NO';

  @override
  String get dataMonitorVerticalSpeed => 'Vertical speed';

  @override
  String get dataMonitorGroundSpeed => 'Ground speed';

  @override
  String get dataMonitorAltitude => 'Altitude';

  @override
  String get dataMonitorBaroAltitude => 'Baro altitude';

  @override
  String get dataMonitorGpsAltitude => 'GPS altitude';

  @override
  String get dataMonitorLatitude => 'Latitude';

  @override
  String get dataMonitorLongitude => 'Longitude';

  @override
  String get dataMonitorHeading => 'Heading';

  @override
  String get dataMonitorBearing => 'Bearing';

  @override
  String get dataMonitorGpsAccuracy => 'GPS accuracy';

  @override
  String get dataMonitorSatellites => 'Satellites';

  @override
  String get dataMonitorWindSpeed => 'Wind speed';

  @override
  String get dataMonitorWindDirection => 'Wind direction';

  @override
  String get dataMonitorPressure => 'Pressure';

  @override
  String get dataMonitorTemperature => 'Temperature';

  @override
  String get dataMonitorBattery => 'Battery';

  @override
  String get dataMonitorHeartRate => 'Heart rate';

  @override
  String get dataMonitorTimestamp => 'Timestamp';

  @override
  String get dataMonitorDerived => 'Derived';

  @override
  String get dataMonitorGlideRatio => 'Glide ratio';

  @override
  String get dataMonitorWindDir => 'Wind dir';

  @override
  String get dataMonitorBaroGpsDelta => 'Baro−GPS Δ';

  @override
  String get dataMonitorTotalEnergy => 'Total energy';

  @override
  String get flightsAddRandomDebug => 'Add random flight (debug)';

  @override
  String get flightsImportLibrary => 'Import library (.pbflights)';

  @override
  String get flightsExportLibrary => 'Export library (.pbflights)';

  @override
  String get flightsClearAll => 'Clear all';

  @override
  String get flightsPlaceNameSettings => 'Place-name lookup settings';

  @override
  String get flightsNoneRecorded => 'No flights recorded yet';

  @override
  String get flightsStartToRecord => 'Start a flight to record a track.';

  @override
  String flightsListSubtitle(String duration, String km, int points) {
    return '$duration · $km km · $points pts';
  }

  @override
  String get flightsReplay => 'Replay';

  @override
  String get flightsNoPointsToReplay => 'No track points to replay';

  @override
  String get flights3dReplay => '3D replay';

  @override
  String get flightsShareCardSaved => 'Share card saved to gallery';

  @override
  String get flightsShareCardSharedFile =>
      'Saved to a file and opened the share sheet';

  @override
  String flightsShareCardFailed(String error) {
    return 'Share card failed: $error';
  }

  @override
  String get flightsSetAmapKeyFirst =>
      'Set an AMap key in place-name settings first.';

  @override
  String get flightsNoPointsToLocate =>
      'This flight has no track points to locate.';

  @override
  String get flightsLookingUpSites => 'Looking up site names…';

  @override
  String get flightsNoPlaceNames =>
      'No place names found for these coordinates.';

  @override
  String get flightsSiteNamesUpdated => 'Site names updated.';

  @override
  String flightsLookupFailed(String error) {
    return 'Lookup failed: $error';
  }

  @override
  String get equipment => 'Equipment';

  @override
  String get equipmentGlider => 'Glider';

  @override
  String get equipmentHarness => 'Harness';

  @override
  String get equipmentHelmet => 'Helmet';

  @override
  String get equipmentEdit => 'Edit equipment';

  @override
  String get equipmentAdd => 'Add equipment';

  @override
  String get placeNameLookup => 'Place-name lookup';

  @override
  String get placeNameLookupDescription =>
      'Reverse-geocode takeoff/landing coordinates to place names using the AMap (AutoNavi) web service. Requests only ever go to restapi.amap.com.';

  @override
  String get placeNameAmapKeyLabel => 'AMap web-service key';

  @override
  String get placeNameAutoLookup => 'Auto-lookup after each flight';

  @override
  String get placeNameSettingsSaved => 'Place-name settings saved.';

  @override
  String flightsExportFailed(String label, String error) {
    return '$label export failed: $error';
  }

  @override
  String flightsLibraryExportFailed(String error) {
    return 'Library export failed: $error';
  }

  @override
  String flightsImportResult(int added, int skipped) {
    return 'Imported $added · skipped $skipped';
  }

  @override
  String flightsImportResultFailed(int added, int skipped, int failed) {
    return 'Imported $added · skipped $skipped · failed $failed';
  }

  @override
  String flightsImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get flightDetailsTitle => 'Flight details';

  @override
  String get flightDetailDeleteSamples => 'Delete samples';

  @override
  String get flightDetailStart => 'Start';

  @override
  String get flightDetailEnd => 'End';

  @override
  String get flightDetailDuration => 'Duration';

  @override
  String get flightDetailDistance => 'Distance';

  @override
  String get flightDetailMaxAltitude => 'Max altitude';

  @override
  String get flightDetailMinAltitude => 'Min altitude';

  @override
  String get flightDetailMaxClimb => 'Max climb';

  @override
  String get flightDetailMaxSink => 'Max sink';

  @override
  String get flightDetailSamples => 'Samples';

  @override
  String get flightDetailTakeoff => 'Takeoff';

  @override
  String get flightDetailLanding => 'Landing';

  @override
  String get flightDetailPerformance => 'Performance';

  @override
  String get flightDetailStraightDistance => 'Straight distance';

  @override
  String get flightDetailXcDistance => 'XC distance';

  @override
  String get flightDetailFaiTriangle => 'FAI triangle';

  @override
  String get flightDetailFaiClosed => 'closed';

  @override
  String get flightDetailMaxFromStart => 'Max from start';

  @override
  String get flightDetailAvgGroundSpeed => 'Avg ground speed';

  @override
  String get flightDetailAvgCruiseSpeed => 'Avg cruise speed';

  @override
  String get flightDetailMaxSpeed => 'Max speed';

  @override
  String get flightDetailAvgClimb => 'Avg climb';

  @override
  String get flightDetailAvgSink => 'Avg sink';

  @override
  String get flightDetailAvgGlideRatio => 'Avg glide ratio';

  @override
  String get flightDetailTrackEfficiency => 'Track efficiency';

  @override
  String get flightDetailThermals => 'Thermals';

  @override
  String get flightDetailAltGained => 'Alt gained';

  @override
  String get flightDetailAltLost => 'Alt lost';

  @override
  String get flightDetailClimbTime => 'Climb time';

  @override
  String get flightDetailGlideTime => 'Glide time';

  @override
  String get flightDetailSinkTime => 'Sink time';

  @override
  String get flightDetailMovingTime => 'Moving time';

  @override
  String get flightDetailExport => 'Export';

  @override
  String get flightDetailSiteNames => 'Site names';

  @override
  String get flightExportShareCard => 'Share card';

  @override
  String get flightsDeleteSamplesTitle => 'Delete sample data?';

  @override
  String get flightsDeleteSamplesMessage =>
      'This removes the per-point track data (position/altitude/vario) for this flight. The flight and its summary stay in the log, but it can no longer be replayed. This cannot be undone.';

  @override
  String get flightsClearAllTitle => 'Clear all flights?';

  @override
  String get flightsClearAllMessage => 'This removes every recorded flight.';

  @override
  String get replayTitle => 'Replay';

  @override
  String get replayColorBy => 'Color by';

  @override
  String get replayColorVario => 'Color: Vario';

  @override
  String get replayColorSpeed => 'Color: Speed';

  @override
  String get replayColorAltitude => 'Color: Altitude';

  @override
  String get replayNoPointsMessage =>
      'This flight has no recorded track points to replay.';

  @override
  String get replayRestart => 'Restart';

  @override
  String get replayPause => 'Pause';

  @override
  String get replayPlay => 'Play';

  @override
  String get replayVarioSoundOn => 'Vario sound on';

  @override
  String get replayVarioSoundOff => 'Vario sound off';

  @override
  String replayReadout(String heading, String altitude, String vario) {
    return 'HDG $heading°  ·  ALT ${altitude}m  ·  $vario m/s';
  }

  @override
  String get replay3dTitle => '3D Replay';

  @override
  String get replay3dResetView => 'Reset view';

  @override
  String get replay3dStatAlt => 'ALT';

  @override
  String get replay3dStatSpd => 'SPD';

  @override
  String get replay3dStatVario => 'VARIO';
}
