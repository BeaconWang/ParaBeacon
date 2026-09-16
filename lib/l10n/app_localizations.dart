import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application name.
  ///
  /// In en, this message translates to:
  /// **'ParaBeacon'**
  String get appTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @varioSoundSettings.
  ///
  /// In en, this message translates to:
  /// **'Vario sound settings'**
  String get varioSoundSettings;

  /// No description provided for @varioSoundSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sound, volume, thresholds, pitch and waveform'**
  String get varioSoundSettingsSubtitle;

  /// No description provided for @gridSize.
  ///
  /// In en, this message translates to:
  /// **'Grid size'**
  String get gridSize;

  /// No description provided for @bluetoothSensor.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Sensor'**
  String get bluetoothSensor;

  /// No description provided for @bluetoothSensorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect an external BLE sensor'**
  String get bluetoothSensorSubtitle;

  /// No description provided for @trackRecording.
  ///
  /// In en, this message translates to:
  /// **'Track recording'**
  String get trackRecording;

  /// No description provided for @trackRecordingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{interval} · {detail}'**
  String trackRecordingSubtitle(String interval, String detail);

  /// No description provided for @recordingIntervalEvery1s.
  ///
  /// In en, this message translates to:
  /// **'Every 1 s'**
  String get recordingIntervalEvery1s;

  /// No description provided for @recordingIntervalSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get recordingIntervalSmart;

  /// No description provided for @recordingDetailFull.
  ///
  /// In en, this message translates to:
  /// **'full data'**
  String get recordingDetailFull;

  /// No description provided for @recordingDetailXcTrack.
  ///
  /// In en, this message translates to:
  /// **'XCTrack style'**
  String get recordingDetailXcTrack;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @simulatedFlightData.
  ///
  /// In en, this message translates to:
  /// **'Simulated flight data'**
  String get simulatedFlightData;

  /// No description provided for @simulatedFlightDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Feed fake sensor values when no BLE device is connected'**
  String get simulatedFlightDataSubtitle;

  /// No description provided for @fakeGpsInChina.
  ///
  /// In en, this message translates to:
  /// **'Fake GPS location in China'**
  String get fakeGpsInChina;

  /// No description provided for @fakeGpsInChinaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start the simulated flight over China (near Chengdu)'**
  String get fakeGpsInChinaSubtitle;

  /// No description provided for @trackRecordingSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart (default)'**
  String get trackRecordingSmart;

  /// No description provided for @trackRecordingSmartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'At least 1 s apart, and only when moved ≥ 3 m or altitude changed ≥ 1 m'**
  String get trackRecordingSmartSubtitle;

  /// No description provided for @trackRecordingEverySecond.
  ///
  /// In en, this message translates to:
  /// **'Every 1 second'**
  String get trackRecordingEverySecond;

  /// No description provided for @trackRecordingEverySecondSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store one point per second regardless of movement'**
  String get trackRecordingEverySecondSubtitle;

  /// No description provided for @trackRecordingChooseHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how often a track point is stored during flight.'**
  String get trackRecordingChooseHint;

  /// No description provided for @recordMoreInformation.
  ///
  /// In en, this message translates to:
  /// **'Record more information'**
  String get recordMoreInformation;

  /// No description provided for @recordMoreInformationFull.
  ///
  /// In en, this message translates to:
  /// **'Full data per point: vario, wind, pressure, temperature, GPS accuracy, satellites, battery, heart rate'**
  String get recordMoreInformationFull;

  /// No description provided for @recordMoreInformationXcTrack.
  ///
  /// In en, this message translates to:
  /// **'XCTrack style: position, baro/GPS altitude, heading, speed and time only'**
  String get recordMoreInformationXcTrack;

  /// No description provided for @clearAllControlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all controls?'**
  String get clearAllControlsTitle;

  /// No description provided for @clearAllControlsMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes every control from the dashboard. This cannot be undone.'**
  String get clearAllControlsMessage;

  /// No description provided for @editMode.
  ///
  /// In en, this message translates to:
  /// **'Edit Mode'**
  String get editMode;

  /// No description provided for @pageOfPages.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageOfPages(int current, int total);

  /// No description provided for @addControl.
  ///
  /// In en, this message translates to:
  /// **'Add Control'**
  String get addControl;

  /// No description provided for @addPage.
  ///
  /// In en, this message translates to:
  /// **'Add Page'**
  String get addPage;

  /// No description provided for @deletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete Page'**
  String get deletePage;

  /// No description provided for @clearAllControls.
  ///
  /// In en, this message translates to:
  /// **'Clear all controls'**
  String get clearAllControls;

  /// No description provided for @controlsPlaced.
  ///
  /// In en, this message translates to:
  /// **'{count} placed'**
  String controlsPlaced(int count);

  /// No description provided for @flights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get flights;

  /// No description provided for @flightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recorded flights'**
  String get flightsSubtitle;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// No description provided for @weatherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Forecast at your location'**
  String get weatherSubtitle;

  /// No description provided for @weatherRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get weatherRefresh;

  /// No description provided for @weatherNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get weatherNow;

  /// No description provided for @weatherToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get weatherToday;

  /// No description provided for @weatherHourly.
  ///
  /// In en, this message translates to:
  /// **'Next 24 hours'**
  String get weatherHourly;

  /// No description provided for @weatherDaily.
  ///
  /// In en, this message translates to:
  /// **'5-day outlook'**
  String get weatherDaily;

  /// No description provided for @weatherFeelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like {temp}°'**
  String weatherFeelsLike(int temp);

  /// No description provided for @weatherWind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get weatherWind;

  /// No description provided for @weatherSpeedKmh.
  ///
  /// In en, this message translates to:
  /// **'{speed} km/h'**
  String weatherSpeedKmh(int speed);

  /// No description provided for @weatherGustsKmh.
  ///
  /// In en, this message translates to:
  /// **'Gusts {speed} km/h'**
  String weatherGustsKmh(int speed);

  /// No description provided for @weatherGustsShort.
  ///
  /// In en, this message translates to:
  /// **'G {speed}'**
  String weatherGustsShort(int speed);

  /// No description provided for @weatherPrecipProbability.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String weatherPrecipProbability(int percent);

  /// No description provided for @weatherHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get weatherHumidity;

  /// No description provided for @weatherCloudCover.
  ///
  /// In en, this message translates to:
  /// **'Cloud cover'**
  String get weatherCloudCover;

  /// No description provided for @weatherPrecipitation.
  ///
  /// In en, this message translates to:
  /// **'Precipitation'**
  String get weatherPrecipitation;

  /// No description provided for @weatherPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get weatherPressure;

  /// No description provided for @weatherNoGps.
  ///
  /// In en, this message translates to:
  /// **'No GPS fix yet. Enable location services and try again.'**
  String get weatherNoGps;

  /// No description provided for @weatherLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the forecast. Check your connection and try again.'**
  String get weatherLoadFailed;

  /// No description provided for @weatherRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get weatherRetry;

  /// No description provided for @weatherDataBy.
  ///
  /// In en, this message translates to:
  /// **'Data by Open-Meteo'**
  String get weatherDataBy;

  /// No description provided for @weatherConditionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get weatherConditionClear;

  /// No description provided for @weatherConditionMainlyClear.
  ///
  /// In en, this message translates to:
  /// **'Mainly clear'**
  String get weatherConditionMainlyClear;

  /// No description provided for @weatherConditionPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherConditionPartlyCloudy;

  /// No description provided for @weatherConditionOvercast.
  ///
  /// In en, this message translates to:
  /// **'Overcast'**
  String get weatherConditionOvercast;

  /// No description provided for @weatherConditionFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weatherConditionFog;

  /// No description provided for @weatherConditionDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get weatherConditionDrizzle;

  /// No description provided for @weatherConditionRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherConditionRain;

  /// No description provided for @weatherConditionFreezing.
  ///
  /// In en, this message translates to:
  /// **'Freezing rain'**
  String get weatherConditionFreezing;

  /// No description provided for @weatherConditionSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weatherConditionSnow;

  /// No description provided for @weatherConditionShowers.
  ///
  /// In en, this message translates to:
  /// **'Showers'**
  String get weatherConditionShowers;

  /// No description provided for @weatherConditionThunder.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherConditionThunder;

  /// No description provided for @weatherConditionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get weatherConditionUnknown;

  /// No description provided for @weatherSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search city or place…'**
  String get weatherSearchHint;

  /// No description provided for @weatherSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Check your connection.'**
  String get weatherSearchFailed;

  /// No description provided for @weatherNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching places'**
  String get weatherNoResults;

  /// No description provided for @weatherTabDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get weatherTabDaily;

  /// No description provided for @weatherRowHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get weatherRowHours;

  /// No description provided for @weatherRowTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get weatherRowTemperature;

  /// No description provided for @weatherRowRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherRowRain;

  /// No description provided for @weatherRowWind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get weatherRowWind;

  /// No description provided for @weatherRowGusts.
  ///
  /// In en, this message translates to:
  /// **'Wind gusts'**
  String get weatherRowGusts;

  /// No description provided for @weatherRowWindDir.
  ///
  /// In en, this message translates to:
  /// **'Wind dir.'**
  String get weatherRowWindDir;

  /// No description provided for @weatherModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get weatherModel;

  /// No description provided for @weatherPastDays.
  ///
  /// In en, this message translates to:
  /// **'Past days'**
  String get weatherPastDays;

  /// No description provided for @weatherPastDaysOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get weatherPastDaysOff;

  /// No description provided for @weatherPastDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{days} d'**
  String weatherPastDaysShort(int days);

  /// No description provided for @weatherUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get weatherUnits;

  /// No description provided for @weatherUnitTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get weatherUnitTemperature;

  /// No description provided for @weatherUnitWindSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind speed'**
  String get weatherUnitWindSpeed;

  /// No description provided for @weatherUnitPrecipitation.
  ///
  /// In en, this message translates to:
  /// **'Precipitation'**
  String get weatherUnitPrecipitation;

  /// No description provided for @weatherSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get weatherSunrise;

  /// No description provided for @weatherSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get weatherSunset;

  /// No description provided for @weatherVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get weatherVisibility;

  /// No description provided for @weatherSoilTemp.
  ///
  /// In en, this message translates to:
  /// **'Soil temp'**
  String get weatherSoilTemp;

  /// No description provided for @weatherSoilMoisture.
  ///
  /// In en, this message translates to:
  /// **'Soil moisture'**
  String get weatherSoilMoisture;

  /// No description provided for @weatherRadiation.
  ///
  /// In en, this message translates to:
  /// **'Radiation'**
  String get weatherRadiation;

  /// No description provided for @weatherEt0.
  ///
  /// In en, this message translates to:
  /// **'ET₀ evapotranspiration'**
  String get weatherEt0;

  /// No description provided for @weatherCape.
  ///
  /// In en, this message translates to:
  /// **'CAPE'**
  String get weatherCape;

  /// No description provided for @weatherSnowfall.
  ///
  /// In en, this message translates to:
  /// **'Snowfall'**
  String get weatherSnowfall;

  /// No description provided for @weatherRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherRain;

  /// No description provided for @weatherCloudLow.
  ///
  /// In en, this message translates to:
  /// **'Low clouds'**
  String get weatherCloudLow;

  /// No description provided for @weatherCloudMid.
  ///
  /// In en, this message translates to:
  /// **'Mid clouds'**
  String get weatherCloudMid;

  /// No description provided for @weatherCloudHigh.
  ///
  /// In en, this message translates to:
  /// **'High clouds'**
  String get weatherCloudHigh;

  /// No description provided for @weatherHourlyDetail.
  ///
  /// In en, this message translates to:
  /// **'Hourly detail'**
  String get weatherHourlyDetail;

  /// No description provided for @weatherUpperWinds.
  ///
  /// In en, this message translates to:
  /// **'Upper winds'**
  String get weatherUpperWinds;

  /// No description provided for @weatherWind80m.
  ///
  /// In en, this message translates to:
  /// **'80 m wind'**
  String get weatherWind80m;

  /// No description provided for @weatherWind120m.
  ///
  /// In en, this message translates to:
  /// **'120 m wind'**
  String get weatherWind120m;

  /// No description provided for @weatherAltitudeMeters.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String weatherAltitudeMeters(int meters);

  /// No description provided for @weatherSourceBy.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String weatherSourceBy(String source);

  /// No description provided for @weatherFallbackNotice.
  ///
  /// In en, this message translates to:
  /// **'{source} unavailable — served by fallback'**
  String weatherFallbackNotice(String source);

  /// No description provided for @pageIcon.
  ///
  /// In en, this message translates to:
  /// **'Page icon'**
  String get pageIcon;

  /// No description provided for @gridSizePx.
  ///
  /// In en, this message translates to:
  /// **'{value} px'**
  String gridSizePx(int value);

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChineseSimplified;

  /// No description provided for @languageSystemDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow the device language'**
  String get languageSystemDescription;

  /// No description provided for @languageEnglishDescription.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishDescription;

  /// No description provided for @languageChineseSimplifiedDescription.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get languageChineseSimplifiedDescription;

  /// No description provided for @languageApplyNote.
  ///
  /// In en, this message translates to:
  /// **'Changes apply instantly, no restart needed. Your choice is saved on this device.'**
  String get languageApplyNote;

  /// No description provided for @themeDarkThemes.
  ///
  /// In en, this message translates to:
  /// **'Dark themes'**
  String get themeDarkThemes;

  /// No description provided for @themeLightThemes.
  ///
  /// In en, this message translates to:
  /// **'Light themes'**
  String get themeLightThemes;

  /// No description provided for @themeHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast (WCAG AAA)'**
  String get themeHighContrast;

  /// No description provided for @themeApplyNote.
  ///
  /// In en, this message translates to:
  /// **'Changes apply instantly, no restart needed. Your choice is saved on this device.\nHigh-contrast themes: pure black/white backgrounds with high-saturation accents — ideal for bright sunlight, eye strain, and older users.'**
  String get themeApplyNote;

  /// No description provided for @themeDarkCyan.
  ///
  /// In en, this message translates to:
  /// **'Dark Cyan (default)'**
  String get themeDarkCyan;

  /// No description provided for @themeDarkSlate.
  ///
  /// In en, this message translates to:
  /// **'Dark Slate'**
  String get themeDarkSlate;

  /// No description provided for @themeDarkAmber.
  ///
  /// In en, this message translates to:
  /// **'Dark Amber (night vision)'**
  String get themeDarkAmber;

  /// No description provided for @themeDarkForest.
  ///
  /// In en, this message translates to:
  /// **'Dark Forest'**
  String get themeDarkForest;

  /// No description provided for @themeDarkOcean.
  ///
  /// In en, this message translates to:
  /// **'Dark Ocean'**
  String get themeDarkOcean;

  /// No description provided for @themeLightSky.
  ///
  /// In en, this message translates to:
  /// **'Light Sky'**
  String get themeLightSky;

  /// No description provided for @themeLightSand.
  ///
  /// In en, this message translates to:
  /// **'Light Sand'**
  String get themeLightSand;

  /// No description provided for @themeLightMint.
  ///
  /// In en, this message translates to:
  /// **'Light Mint'**
  String get themeLightMint;

  /// No description provided for @themeLightPaper.
  ///
  /// In en, this message translates to:
  /// **'Light Paper'**
  String get themeLightPaper;

  /// No description provided for @themeLightLavender.
  ///
  /// In en, this message translates to:
  /// **'Light Lavender'**
  String get themeLightLavender;

  /// No description provided for @themeDarkContrast.
  ///
  /// In en, this message translates to:
  /// **'Dark High-Contrast'**
  String get themeDarkContrast;

  /// No description provided for @themeLightContrast.
  ///
  /// In en, this message translates to:
  /// **'Light High-Contrast'**
  String get themeLightContrast;

  /// No description provided for @themeDarkCyanDesc.
  ///
  /// In en, this message translates to:
  /// **'Dark base + cyan accents (classic default)'**
  String get themeDarkCyanDesc;

  /// No description provided for @themeDarkSlateDesc.
  ///
  /// In en, this message translates to:
  /// **'Business dark grey + blue-violet accents'**
  String get themeDarkSlateDesc;

  /// No description provided for @themeDarkAmberDesc.
  ///
  /// In en, this message translates to:
  /// **'Cockpit amber, easy on the eyes for long night flights'**
  String get themeDarkAmberDesc;

  /// No description provided for @themeDarkForestDesc.
  ///
  /// In en, this message translates to:
  /// **'Deep forest green + golden sunlight'**
  String get themeDarkForestDesc;

  /// No description provided for @themeDarkOceanDesc.
  ///
  /// In en, this message translates to:
  /// **'Deep ocean blue-violet + teal coral'**
  String get themeDarkOceanDesc;

  /// No description provided for @themeLightSkyDesc.
  ///
  /// In en, this message translates to:
  /// **'High contrast in sunlight, best for daytime flying'**
  String get themeLightSkyDesc;

  /// No description provided for @themeLightSandDesc.
  ///
  /// In en, this message translates to:
  /// **'Warm sand base, comfortable for extended use'**
  String get themeLightSandDesc;

  /// No description provided for @themeLightMintDesc.
  ///
  /// In en, this message translates to:
  /// **'Fresh mint green, easy on the eyes'**
  String get themeLightMintDesc;

  /// No description provided for @themeLightPaperDesc.
  ///
  /// In en, this message translates to:
  /// **'Aeronautical chart paper style, nostalgic VFR'**
  String get themeLightPaperDesc;

  /// No description provided for @themeLightLavenderDesc.
  ///
  /// In en, this message translates to:
  /// **'Soft lavender + deep purple, gentle on the eyes'**
  String get themeLightLavenderDesc;

  /// No description provided for @themeDarkContrastDesc.
  ///
  /// In en, this message translates to:
  /// **'Pure black + high-saturation yellow (WCAG AAA)'**
  String get themeDarkContrastDesc;

  /// No description provided for @themeLightContrastDesc.
  ///
  /// In en, this message translates to:
  /// **'Pure white + black + deep blue (WCAG AAA)'**
  String get themeLightContrastDesc;

  /// No description provided for @controlKindData.
  ///
  /// In en, this message translates to:
  /// **'Data Control'**
  String get controlKindData;

  /// No description provided for @controlKindWidget.
  ///
  /// In en, this message translates to:
  /// **'Widget Control'**
  String get controlKindWidget;

  /// No description provided for @controlAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get controlAltitude;

  /// No description provided for @controlMaxAltitude.
  ///
  /// In en, this message translates to:
  /// **'Max Altitude'**
  String get controlMaxAltitude;

  /// No description provided for @controlVerticalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Vertical Speed'**
  String get controlVerticalSpeed;

  /// No description provided for @controlGroundSpeed.
  ///
  /// In en, this message translates to:
  /// **'Ground Speed'**
  String get controlGroundSpeed;

  /// No description provided for @controlGlide.
  ///
  /// In en, this message translates to:
  /// **'Glide'**
  String get controlGlide;

  /// No description provided for @controlHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get controlHeading;

  /// No description provided for @controlLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get controlLocation;

  /// No description provided for @controlWindSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind Speed'**
  String get controlWindSpeed;

  /// No description provided for @controlWindDirection.
  ///
  /// In en, this message translates to:
  /// **'Wind Direction'**
  String get controlWindDirection;

  /// No description provided for @controlPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get controlPressure;

  /// No description provided for @controlTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get controlTemperature;

  /// No description provided for @controlClock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get controlClock;

  /// No description provided for @controlFlightTime.
  ///
  /// In en, this message translates to:
  /// **'Flight Time'**
  String get controlFlightTime;

  /// No description provided for @controlAirTime.
  ///
  /// In en, this message translates to:
  /// **'Air Time'**
  String get controlAirTime;

  /// No description provided for @controlDistanceToTakeoff.
  ///
  /// In en, this message translates to:
  /// **'Distance to Takeoff'**
  String get controlDistanceToTakeoff;

  /// No description provided for @controlSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get controlSunrise;

  /// No description provided for @controlSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get controlSunset;

  /// No description provided for @controlStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Status Line'**
  String get controlStatusLine;

  /// No description provided for @controlCompassWind.
  ///
  /// In en, this message translates to:
  /// **'Compass and Wind'**
  String get controlCompassWind;

  /// No description provided for @controlSensorBattery.
  ///
  /// In en, this message translates to:
  /// **'Sensor Battery'**
  String get controlSensorBattery;

  /// No description provided for @controlHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get controlHeartRate;

  /// No description provided for @controlVario.
  ///
  /// In en, this message translates to:
  /// **'Vario'**
  String get controlVario;

  /// No description provided for @controlDebugSensor.
  ///
  /// In en, this message translates to:
  /// **'Debug Sensor'**
  String get controlDebugSensor;

  /// No description provided for @controlDataMonitor.
  ///
  /// In en, this message translates to:
  /// **'Data Monitor'**
  String get controlDataMonitor;

  /// No description provided for @controlMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get controlMap;

  /// No description provided for @controlFlightButton.
  ///
  /// In en, this message translates to:
  /// **'Flight Button'**
  String get controlFlightButton;

  /// No description provided for @controlUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get controlUnknown;

  /// No description provided for @controlSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'{control} settings'**
  String controlSettingsTitle(String control);

  /// No description provided for @searchControls.
  ///
  /// In en, this message translates to:
  /// **'Search controls'**
  String get searchControls;

  /// No description provided for @noControlsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No controls available yet'**
  String get noControlsAvailable;

  /// No description provided for @noControlsMatch.
  ///
  /// In en, this message translates to:
  /// **'No controls match \"{query}\"'**
  String noControlsMatch(String query);

  /// No description provided for @noControlsInDirectory.
  ///
  /// In en, this message translates to:
  /// **'No controls in this directory yet'**
  String get noControlsInDirectory;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @bringToFront.
  ///
  /// In en, this message translates to:
  /// **'Bring to Front'**
  String get bringToFront;

  /// No description provided for @sendToBack.
  ///
  /// In en, this message translates to:
  /// **'Send to Back'**
  String get sendToBack;

  /// No description provided for @controlNoSettings.
  ///
  /// In en, this message translates to:
  /// **'This control has no settings.'**
  String get controlNoSettings;

  /// No description provided for @controlGpsAltitude.
  ///
  /// In en, this message translates to:
  /// **'GPS Altitude'**
  String get controlGpsAltitude;

  /// No description provided for @controlBaroAltitude.
  ///
  /// In en, this message translates to:
  /// **'Baro Altitude'**
  String get controlBaroAltitude;

  /// No description provided for @controlWindDir.
  ///
  /// In en, this message translates to:
  /// **'Wind Dir'**
  String get controlWindDir;

  /// No description provided for @locationNoFix.
  ///
  /// In en, this message translates to:
  /// **'No GPS fix'**
  String get locationNoFix;

  /// No description provided for @flightButtonStart.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get flightButtonStart;

  /// No description provided for @flightButtonStop.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get flightButtonStop;

  /// No description provided for @flightButtonAuto.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get flightButtonAuto;

  /// No description provided for @flightButtonAutoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect take-off / landing'**
  String get flightButtonAutoTooltip;

  /// No description provided for @flightRecordingReadout.
  ///
  /// In en, this message translates to:
  /// **'REC · {points} pts · {km} km'**
  String flightRecordingReadout(int points, String km);

  /// No description provided for @settingShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Show title'**
  String get settingShowTitle;

  /// No description provided for @settingShowBorder.
  ///
  /// In en, this message translates to:
  /// **'Show border'**
  String get settingShowBorder;

  /// No description provided for @settingBorderColor.
  ///
  /// In en, this message translates to:
  /// **'Border color'**
  String get settingBorderColor;

  /// No description provided for @settingBorderWidth.
  ///
  /// In en, this message translates to:
  /// **'Border width'**
  String get settingBorderWidth;

  /// No description provided for @settingCornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get settingCornerRadius;

  /// No description provided for @settingControlOpacity.
  ///
  /// In en, this message translates to:
  /// **'Control opacity'**
  String get settingControlOpacity;

  /// No description provided for @settingBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get settingBackgroundColor;

  /// No description provided for @settingBackgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background opacity'**
  String get settingBackgroundOpacity;

  /// No description provided for @settingTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get settingTextColor;

  /// No description provided for @settingScaleMax.
  ///
  /// In en, this message translates to:
  /// **'Scale (max)'**
  String get settingScaleMax;

  /// No description provided for @settingAveragingInterval.
  ///
  /// In en, this message translates to:
  /// **'Averaging interval'**
  String get settingAveragingInterval;

  /// No description provided for @settingCoordinateFormat.
  ///
  /// In en, this message translates to:
  /// **'Coordinate format'**
  String get settingCoordinateFormat;

  /// No description provided for @settingCoordinateDecimal.
  ///
  /// In en, this message translates to:
  /// **'Decimal degrees'**
  String get settingCoordinateDecimal;

  /// No description provided for @settingCoordinateDms.
  ///
  /// In en, this message translates to:
  /// **'Deg / min / sec'**
  String get settingCoordinateDms;

  /// No description provided for @settingAltitudeSource.
  ///
  /// In en, this message translates to:
  /// **'Altitude source'**
  String get settingAltitudeSource;

  /// No description provided for @settingAltitudeSourceAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (baro if available)'**
  String get settingAltitudeSourceAuto;

  /// No description provided for @settingAltitudeSourceGps.
  ///
  /// In en, this message translates to:
  /// **'GPS altitude'**
  String get settingAltitudeSourceGps;

  /// No description provided for @settingAltitudeSourceBaro.
  ///
  /// In en, this message translates to:
  /// **'Barometric altitude'**
  String get settingAltitudeSourceBaro;

  /// No description provided for @settingFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get settingFormat;

  /// No description provided for @settingFormatDegrees.
  ///
  /// In en, this message translates to:
  /// **'Degrees (0-360°)'**
  String get settingFormatDegrees;

  /// No description provided for @settingFormatCardinal.
  ///
  /// In en, this message translates to:
  /// **'Cardinal (N, NE, …)'**
  String get settingFormatCardinal;

  /// No description provided for @settingShowSeconds.
  ///
  /// In en, this message translates to:
  /// **'Show seconds'**
  String get settingShowSeconds;

  /// No description provided for @settingShowAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Show auto-detect checkbox'**
  String get settingShowAutoDetect;

  /// No description provided for @settingShowGps.
  ///
  /// In en, this message translates to:
  /// **'Show GPS status'**
  String get settingShowGps;

  /// No description provided for @settingGpsDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed GPS status'**
  String get settingGpsDetailed;

  /// No description provided for @settingShowBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Show Bluetooth sensor'**
  String get settingShowBluetooth;

  /// No description provided for @settingShowSensorBattery.
  ///
  /// In en, this message translates to:
  /// **'Show sensor battery'**
  String get settingShowSensorBattery;

  /// No description provided for @settingShowDeviceBattery.
  ///
  /// In en, this message translates to:
  /// **'Show device battery'**
  String get settingShowDeviceBattery;

  /// No description provided for @settingShowFlightTimer.
  ///
  /// In en, this message translates to:
  /// **'Show flight timer'**
  String get settingShowFlightTimer;

  /// No description provided for @settingShowClock.
  ///
  /// In en, this message translates to:
  /// **'Show clock'**
  String get settingShowClock;

  /// No description provided for @settingTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get settingTimeFormat;

  /// No description provided for @settingTimeFormat24h.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get settingTimeFormat24h;

  /// No description provided for @settingTimeFormat12h.
  ///
  /// In en, this message translates to:
  /// **'12-hour (AM/PM)'**
  String get settingTimeFormat12h;

  /// No description provided for @settingGlideAvg.
  ///
  /// In en, this message translates to:
  /// **'Glide averaging'**
  String get settingGlideAvg;

  /// No description provided for @settingGlideAvgInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get settingGlideAvgInstant;

  /// No description provided for @settingGlideAvgSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String settingGlideAvgSeconds(String seconds);

  /// No description provided for @settingGlideLeadingOne.
  ///
  /// In en, this message translates to:
  /// **'Show leading \"1:\"'**
  String get settingGlideLeadingOne;

  /// No description provided for @settingGlideShowVario.
  ///
  /// In en, this message translates to:
  /// **'Show vario in lift'**
  String get settingGlideShowVario;

  /// No description provided for @settingFollowPosition.
  ///
  /// In en, this message translates to:
  /// **'Follow position'**
  String get settingFollowPosition;

  /// No description provided for @settingZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get settingZoom;

  /// No description provided for @settingMapSource.
  ///
  /// In en, this message translates to:
  /// **'Map source'**
  String get settingMapSource;

  /// No description provided for @settingMapSourceNone.
  ///
  /// In en, this message translates to:
  /// **'None (no basemap)'**
  String get settingMapSourceNone;

  /// No description provided for @settingMapSourceOsm.
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap'**
  String get settingMapSourceOsm;

  /// No description provided for @settingMapSourceOsmFr.
  ///
  /// In en, this message translates to:
  /// **'OSM France'**
  String get settingMapSourceOsmFr;

  /// No description provided for @settingMapSourceCartoDark.
  ///
  /// In en, this message translates to:
  /// **'Carto Dark'**
  String get settingMapSourceCartoDark;

  /// No description provided for @settingMapSourceCartoVoyager.
  ///
  /// In en, this message translates to:
  /// **'Carto Voyager'**
  String get settingMapSourceCartoVoyager;

  /// No description provided for @settingMapSourceAmap.
  ///
  /// In en, this message translates to:
  /// **'AMap (AutoNavi)'**
  String get settingMapSourceAmap;

  /// No description provided for @settingMapSourceAmapSat.
  ///
  /// In en, this message translates to:
  /// **'AMap Satellite'**
  String get settingMapSourceAmapSat;

  /// No description provided for @settingRotation.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get settingRotation;

  /// No description provided for @settingRotationNorth.
  ///
  /// In en, this message translates to:
  /// **'North at the top'**
  String get settingRotationNorth;

  /// No description provided for @settingRotationTrack.
  ///
  /// In en, this message translates to:
  /// **'Track up (heading)'**
  String get settingRotationTrack;

  /// No description provided for @settingShowNorth.
  ///
  /// In en, this message translates to:
  /// **'Display North direction'**
  String get settingShowNorth;

  /// No description provided for @settingPilotArrowSize.
  ///
  /// In en, this message translates to:
  /// **'Pilot arrow size'**
  String get settingPilotArrowSize;

  /// No description provided for @settingLineThickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness of lines'**
  String get settingLineThickness;

  /// No description provided for @settingTracklogLength.
  ///
  /// In en, this message translates to:
  /// **'Tracklog length (0 = all)'**
  String get settingTracklogLength;

  /// No description provided for @settingLatestThermals.
  ///
  /// In en, this message translates to:
  /// **'Show N latest thermals'**
  String get settingLatestThermals;

  /// No description provided for @settingPreferOffline.
  ///
  /// In en, this message translates to:
  /// **'Prefer offline maps (.mbtiles)'**
  String get settingPreferOffline;

  /// No description provided for @settingShowTrack.
  ///
  /// In en, this message translates to:
  /// **'Show flight track'**
  String get settingShowTrack;

  /// No description provided for @settingShowThermal.
  ///
  /// In en, this message translates to:
  /// **'Show thermal assistant'**
  String get settingShowThermal;

  /// No description provided for @settingWindAlgorithm.
  ///
  /// In en, this message translates to:
  /// **'Include wind in computation'**
  String get settingWindAlgorithm;

  /// No description provided for @settingWindAlgorithmNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingWindAlgorithmNone;

  /// No description provided for @settingWindAlgorithmClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get settingWindAlgorithmClassic;

  /// No description provided for @settingWindAlgorithmParticle.
  ///
  /// In en, this message translates to:
  /// **'Particle drift'**
  String get settingWindAlgorithmParticle;

  /// No description provided for @settingShowWind.
  ///
  /// In en, this message translates to:
  /// **'Show wind'**
  String get settingShowWind;

  /// No description provided for @settingShowSun.
  ///
  /// In en, this message translates to:
  /// **'Show sun position'**
  String get settingShowSun;

  /// No description provided for @settingShowBearing.
  ///
  /// In en, this message translates to:
  /// **'Show bearing (course) line'**
  String get settingShowBearing;

  /// No description provided for @settingShowTakeoffLine.
  ///
  /// In en, this message translates to:
  /// **'Show line to take-off'**
  String get settingShowTakeoffLine;

  /// No description provided for @settingShowScale.
  ///
  /// In en, this message translates to:
  /// **'Display map scale'**
  String get settingShowScale;

  /// No description provided for @settingShowAirspace.
  ///
  /// In en, this message translates to:
  /// **'Show airspace'**
  String get settingShowAirspace;

  /// No description provided for @settingShowLegend.
  ///
  /// In en, this message translates to:
  /// **'Show vario legend'**
  String get settingShowLegend;

  /// No description provided for @settingShowZoomLevel.
  ///
  /// In en, this message translates to:
  /// **'Show zoom level'**
  String get settingShowZoomLevel;

  /// No description provided for @settingShowAttribution.
  ///
  /// In en, this message translates to:
  /// **'Show map attribution'**
  String get settingShowAttribution;

  /// No description provided for @settingShowStatus.
  ///
  /// In en, this message translates to:
  /// **'Show HDG/ALT & GPS status'**
  String get settingShowStatus;

  /// No description provided for @dataMonitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Monitor'**
  String get dataMonitorTitle;

  /// No description provided for @dataMonitorLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get dataMonitorLive;

  /// No description provided for @dataMonitorFix.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get dataMonitorFix;

  /// No description provided for @dataMonitorYes.
  ///
  /// In en, this message translates to:
  /// **'YES'**
  String get dataMonitorYes;

  /// No description provided for @dataMonitorNo.
  ///
  /// In en, this message translates to:
  /// **'NO'**
  String get dataMonitorNo;

  /// No description provided for @dataMonitorVerticalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Vertical speed'**
  String get dataMonitorVerticalSpeed;

  /// No description provided for @dataMonitorGroundSpeed.
  ///
  /// In en, this message translates to:
  /// **'Ground speed'**
  String get dataMonitorGroundSpeed;

  /// No description provided for @dataMonitorAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get dataMonitorAltitude;

  /// No description provided for @dataMonitorBaroAltitude.
  ///
  /// In en, this message translates to:
  /// **'Baro altitude'**
  String get dataMonitorBaroAltitude;

  /// No description provided for @dataMonitorGpsAltitude.
  ///
  /// In en, this message translates to:
  /// **'GPS altitude'**
  String get dataMonitorGpsAltitude;

  /// No description provided for @dataMonitorLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get dataMonitorLatitude;

  /// No description provided for @dataMonitorLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get dataMonitorLongitude;

  /// No description provided for @dataMonitorHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get dataMonitorHeading;

  /// No description provided for @dataMonitorBearing.
  ///
  /// In en, this message translates to:
  /// **'Bearing'**
  String get dataMonitorBearing;

  /// No description provided for @dataMonitorGpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy'**
  String get dataMonitorGpsAccuracy;

  /// No description provided for @dataMonitorSatellites.
  ///
  /// In en, this message translates to:
  /// **'Satellites'**
  String get dataMonitorSatellites;

  /// No description provided for @dataMonitorWindSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind speed'**
  String get dataMonitorWindSpeed;

  /// No description provided for @dataMonitorWindDirection.
  ///
  /// In en, this message translates to:
  /// **'Wind direction'**
  String get dataMonitorWindDirection;

  /// No description provided for @dataMonitorPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get dataMonitorPressure;

  /// No description provided for @dataMonitorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get dataMonitorTemperature;

  /// No description provided for @dataMonitorBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get dataMonitorBattery;

  /// No description provided for @dataMonitorHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get dataMonitorHeartRate;

  /// No description provided for @dataMonitorTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get dataMonitorTimestamp;

  /// No description provided for @dataMonitorDerived.
  ///
  /// In en, this message translates to:
  /// **'Derived'**
  String get dataMonitorDerived;

  /// No description provided for @dataMonitorGlideRatio.
  ///
  /// In en, this message translates to:
  /// **'Glide ratio'**
  String get dataMonitorGlideRatio;

  /// No description provided for @dataMonitorWindDir.
  ///
  /// In en, this message translates to:
  /// **'Wind dir'**
  String get dataMonitorWindDir;

  /// No description provided for @dataMonitorBaroGpsDelta.
  ///
  /// In en, this message translates to:
  /// **'Baro−GPS Δ'**
  String get dataMonitorBaroGpsDelta;

  /// No description provided for @dataMonitorTotalEnergy.
  ///
  /// In en, this message translates to:
  /// **'Total energy'**
  String get dataMonitorTotalEnergy;

  /// No description provided for @flightsAddRandomDebug.
  ///
  /// In en, this message translates to:
  /// **'Add random flight (debug)'**
  String get flightsAddRandomDebug;

  /// No description provided for @flightsImportLibrary.
  ///
  /// In en, this message translates to:
  /// **'Import library (.pbflights)'**
  String get flightsImportLibrary;

  /// No description provided for @flightsExportLibrary.
  ///
  /// In en, this message translates to:
  /// **'Export library (.pbflights)'**
  String get flightsExportLibrary;

  /// No description provided for @flightsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get flightsClearAll;

  /// No description provided for @flightsPlaceNameSettings.
  ///
  /// In en, this message translates to:
  /// **'Place-name lookup settings'**
  String get flightsPlaceNameSettings;

  /// No description provided for @flightsNoneRecorded.
  ///
  /// In en, this message translates to:
  /// **'No flights recorded yet'**
  String get flightsNoneRecorded;

  /// No description provided for @flightsStartToRecord.
  ///
  /// In en, this message translates to:
  /// **'Start a flight to record a track.'**
  String get flightsStartToRecord;

  /// No description provided for @flightsListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{duration} · {km} km · {points} pts'**
  String flightsListSubtitle(String duration, String km, int points);

  /// No description provided for @flightsReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get flightsReplay;

  /// No description provided for @flightsNoPointsToReplay.
  ///
  /// In en, this message translates to:
  /// **'No track points to replay'**
  String get flightsNoPointsToReplay;

  /// No description provided for @flights3dReplay.
  ///
  /// In en, this message translates to:
  /// **'3D replay'**
  String get flights3dReplay;

  /// No description provided for @flightsShareCardSaved.
  ///
  /// In en, this message translates to:
  /// **'Share card saved to gallery'**
  String get flightsShareCardSaved;

  /// No description provided for @flightsShareCardSharedFile.
  ///
  /// In en, this message translates to:
  /// **'Saved to a file and opened the share sheet'**
  String get flightsShareCardSharedFile;

  /// No description provided for @flightsShareCardFailed.
  ///
  /// In en, this message translates to:
  /// **'Share card failed: {error}'**
  String flightsShareCardFailed(String error);

  /// No description provided for @flightsSetAmapKeyFirst.
  ///
  /// In en, this message translates to:
  /// **'Set an AMap key in place-name settings first.'**
  String get flightsSetAmapKeyFirst;

  /// No description provided for @flightsNoPointsToLocate.
  ///
  /// In en, this message translates to:
  /// **'This flight has no track points to locate.'**
  String get flightsNoPointsToLocate;

  /// No description provided for @flightsLookingUpSites.
  ///
  /// In en, this message translates to:
  /// **'Looking up site names…'**
  String get flightsLookingUpSites;

  /// No description provided for @flightsNoPlaceNames.
  ///
  /// In en, this message translates to:
  /// **'No place names found for these coordinates.'**
  String get flightsNoPlaceNames;

  /// No description provided for @flightsSiteNamesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Site names updated.'**
  String get flightsSiteNamesUpdated;

  /// No description provided for @flightsLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Lookup failed: {error}'**
  String flightsLookupFailed(String error);

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @equipmentGlider.
  ///
  /// In en, this message translates to:
  /// **'Glider'**
  String get equipmentGlider;

  /// No description provided for @equipmentHarness.
  ///
  /// In en, this message translates to:
  /// **'Harness'**
  String get equipmentHarness;

  /// No description provided for @equipmentHelmet.
  ///
  /// In en, this message translates to:
  /// **'Helmet'**
  String get equipmentHelmet;

  /// No description provided for @equipmentEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit equipment'**
  String get equipmentEdit;

  /// No description provided for @equipmentAdd.
  ///
  /// In en, this message translates to:
  /// **'Add equipment'**
  String get equipmentAdd;

  /// No description provided for @placeNameLookup.
  ///
  /// In en, this message translates to:
  /// **'Place-name lookup'**
  String get placeNameLookup;

  /// No description provided for @placeNameLookupDescription.
  ///
  /// In en, this message translates to:
  /// **'Reverse-geocode takeoff/landing coordinates to place names using the AMap (AutoNavi) web service. Requests only ever go to restapi.amap.com.'**
  String get placeNameLookupDescription;

  /// No description provided for @placeNameAmapKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'AMap web-service key'**
  String get placeNameAmapKeyLabel;

  /// No description provided for @placeNameAutoLookup.
  ///
  /// In en, this message translates to:
  /// **'Auto-lookup after each flight'**
  String get placeNameAutoLookup;

  /// No description provided for @placeNameSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Place-name settings saved.'**
  String get placeNameSettingsSaved;

  /// No description provided for @flightsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'{label} export failed: {error}'**
  String flightsExportFailed(String label, String error);

  /// No description provided for @flightsLibraryExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Library export failed: {error}'**
  String flightsLibraryExportFailed(String error);

  /// No description provided for @flightsImportResult.
  ///
  /// In en, this message translates to:
  /// **'Imported {added} · skipped {skipped}'**
  String flightsImportResult(int added, int skipped);

  /// No description provided for @flightsImportResultFailed.
  ///
  /// In en, this message translates to:
  /// **'Imported {added} · skipped {skipped} · failed {failed}'**
  String flightsImportResultFailed(int added, int skipped, int failed);

  /// No description provided for @flightsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String flightsImportFailed(String error);

  /// No description provided for @flightDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Flight details'**
  String get flightDetailsTitle;

  /// No description provided for @flightDetailDeleteSamples.
  ///
  /// In en, this message translates to:
  /// **'Delete samples'**
  String get flightDetailDeleteSamples;

  /// No description provided for @flightDetailStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get flightDetailStart;

  /// No description provided for @flightDetailEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get flightDetailEnd;

  /// No description provided for @flightDetailDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get flightDetailDuration;

  /// No description provided for @flightDetailDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get flightDetailDistance;

  /// No description provided for @flightDetailMaxAltitude.
  ///
  /// In en, this message translates to:
  /// **'Max altitude'**
  String get flightDetailMaxAltitude;

  /// No description provided for @flightDetailMinAltitude.
  ///
  /// In en, this message translates to:
  /// **'Min altitude'**
  String get flightDetailMinAltitude;

  /// No description provided for @flightDetailMaxClimb.
  ///
  /// In en, this message translates to:
  /// **'Max climb'**
  String get flightDetailMaxClimb;

  /// No description provided for @flightDetailMaxSink.
  ///
  /// In en, this message translates to:
  /// **'Max sink'**
  String get flightDetailMaxSink;

  /// No description provided for @flightDetailSamples.
  ///
  /// In en, this message translates to:
  /// **'Samples'**
  String get flightDetailSamples;

  /// No description provided for @flightDetailTakeoff.
  ///
  /// In en, this message translates to:
  /// **'Takeoff'**
  String get flightDetailTakeoff;

  /// No description provided for @flightDetailLanding.
  ///
  /// In en, this message translates to:
  /// **'Landing'**
  String get flightDetailLanding;

  /// No description provided for @flightDetailPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get flightDetailPerformance;

  /// No description provided for @flightDetailStraightDistance.
  ///
  /// In en, this message translates to:
  /// **'Straight distance'**
  String get flightDetailStraightDistance;

  /// No description provided for @flightDetailXcDistance.
  ///
  /// In en, this message translates to:
  /// **'XC distance'**
  String get flightDetailXcDistance;

  /// No description provided for @flightDetailFaiTriangle.
  ///
  /// In en, this message translates to:
  /// **'FAI triangle'**
  String get flightDetailFaiTriangle;

  /// No description provided for @flightDetailFaiClosed.
  ///
  /// In en, this message translates to:
  /// **'closed'**
  String get flightDetailFaiClosed;

  /// No description provided for @flightDetailMaxFromStart.
  ///
  /// In en, this message translates to:
  /// **'Max from start'**
  String get flightDetailMaxFromStart;

  /// No description provided for @flightDetailAvgGroundSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg ground speed'**
  String get flightDetailAvgGroundSpeed;

  /// No description provided for @flightDetailAvgCruiseSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg cruise speed'**
  String get flightDetailAvgCruiseSpeed;

  /// No description provided for @flightDetailMaxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Max speed'**
  String get flightDetailMaxSpeed;

  /// No description provided for @flightDetailAvgClimb.
  ///
  /// In en, this message translates to:
  /// **'Avg climb'**
  String get flightDetailAvgClimb;

  /// No description provided for @flightDetailAvgSink.
  ///
  /// In en, this message translates to:
  /// **'Avg sink'**
  String get flightDetailAvgSink;

  /// No description provided for @flightDetailAvgGlideRatio.
  ///
  /// In en, this message translates to:
  /// **'Avg glide ratio'**
  String get flightDetailAvgGlideRatio;

  /// No description provided for @flightDetailTrackEfficiency.
  ///
  /// In en, this message translates to:
  /// **'Track efficiency'**
  String get flightDetailTrackEfficiency;

  /// No description provided for @flightDetailThermals.
  ///
  /// In en, this message translates to:
  /// **'Thermals'**
  String get flightDetailThermals;

  /// No description provided for @flightDetailAltGained.
  ///
  /// In en, this message translates to:
  /// **'Alt gained'**
  String get flightDetailAltGained;

  /// No description provided for @flightDetailAltLost.
  ///
  /// In en, this message translates to:
  /// **'Alt lost'**
  String get flightDetailAltLost;

  /// No description provided for @flightDetailClimbTime.
  ///
  /// In en, this message translates to:
  /// **'Climb time'**
  String get flightDetailClimbTime;

  /// No description provided for @flightDetailGlideTime.
  ///
  /// In en, this message translates to:
  /// **'Glide time'**
  String get flightDetailGlideTime;

  /// No description provided for @flightDetailSinkTime.
  ///
  /// In en, this message translates to:
  /// **'Sink time'**
  String get flightDetailSinkTime;

  /// No description provided for @flightDetailMovingTime.
  ///
  /// In en, this message translates to:
  /// **'Moving time'**
  String get flightDetailMovingTime;

  /// No description provided for @flightDetailExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get flightDetailExport;

  /// No description provided for @flightDetailSiteNames.
  ///
  /// In en, this message translates to:
  /// **'Site names'**
  String get flightDetailSiteNames;

  /// No description provided for @flightExportShareCard.
  ///
  /// In en, this message translates to:
  /// **'Share card'**
  String get flightExportShareCard;

  /// No description provided for @flightsDeleteSamplesTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete sample data?'**
  String get flightsDeleteSamplesTitle;

  /// No description provided for @flightsDeleteSamplesMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the per-point track data (position/altitude/vario) for this flight. The flight and its summary stay in the log, but it can no longer be replayed. This cannot be undone.'**
  String get flightsDeleteSamplesMessage;

  /// No description provided for @flightsClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all flights?'**
  String get flightsClearAllTitle;

  /// No description provided for @flightsClearAllMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes every recorded flight.'**
  String get flightsClearAllMessage;

  /// No description provided for @replayTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replayTitle;

  /// No description provided for @replayColorBy.
  ///
  /// In en, this message translates to:
  /// **'Color by'**
  String get replayColorBy;

  /// No description provided for @replayColorVario.
  ///
  /// In en, this message translates to:
  /// **'Color: Vario'**
  String get replayColorVario;

  /// No description provided for @replayColorSpeed.
  ///
  /// In en, this message translates to:
  /// **'Color: Speed'**
  String get replayColorSpeed;

  /// No description provided for @replayColorAltitude.
  ///
  /// In en, this message translates to:
  /// **'Color: Altitude'**
  String get replayColorAltitude;

  /// No description provided for @replayNoPointsMessage.
  ///
  /// In en, this message translates to:
  /// **'This flight has no recorded track points to replay.'**
  String get replayNoPointsMessage;

  /// No description provided for @replayRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get replayRestart;

  /// No description provided for @replayPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get replayPause;

  /// No description provided for @replayPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get replayPlay;

  /// No description provided for @replayVarioSoundOn.
  ///
  /// In en, this message translates to:
  /// **'Vario sound on'**
  String get replayVarioSoundOn;

  /// No description provided for @replayVarioSoundOff.
  ///
  /// In en, this message translates to:
  /// **'Vario sound off'**
  String get replayVarioSoundOff;

  /// No description provided for @replayReadout.
  ///
  /// In en, this message translates to:
  /// **'HDG {heading}°  ·  ALT {altitude}m  ·  {vario} m/s'**
  String replayReadout(String heading, String altitude, String vario);

  /// No description provided for @replay3dTitle.
  ///
  /// In en, this message translates to:
  /// **'3D Replay'**
  String get replay3dTitle;

  /// No description provided for @replay3dResetView.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get replay3dResetView;

  /// No description provided for @replay3dStatAlt.
  ///
  /// In en, this message translates to:
  /// **'ALT'**
  String get replay3dStatAlt;

  /// No description provided for @replay3dStatSpd.
  ///
  /// In en, this message translates to:
  /// **'SPD'**
  String get replay3dStatSpd;

  /// No description provided for @replay3dStatVario.
  ///
  /// In en, this message translates to:
  /// **'VARIO'**
  String get replay3dStatVario;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
