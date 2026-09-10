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
