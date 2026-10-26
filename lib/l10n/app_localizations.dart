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

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App details, version, and licenses'**
  String get aboutSubtitle;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'A cross-platform paraglider flight assistant with live vario audio, BLE sensors, mapping, and flight logging.'**
  String get aboutDescription;

  /// No description provided for @aboutApplicationDetails.
  ///
  /// In en, this message translates to:
  /// **'Application details'**
  String get aboutApplicationDetails;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @aboutBuildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build number'**
  String get aboutBuildNumber;

  /// No description provided for @aboutPackageId.
  ///
  /// In en, this message translates to:
  /// **'Package ID'**
  String get aboutPackageId;

  /// No description provided for @aboutPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get aboutPlatform;

  /// No description provided for @aboutAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get aboutAuthor;

  /// No description provided for @aboutPlatformWeb.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get aboutPlatformWeb;

  /// No description provided for @aboutPlatformAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get aboutPlatformAndroid;

  /// No description provided for @aboutPlatformIos.
  ///
  /// In en, this message translates to:
  /// **'iOS'**
  String get aboutPlatformIos;

  /// No description provided for @aboutPlatformLinux.
  ///
  /// In en, this message translates to:
  /// **'Linux'**
  String get aboutPlatformLinux;

  /// No description provided for @aboutPlatformMacos.
  ///
  /// In en, this message translates to:
  /// **'macOS'**
  String get aboutPlatformMacos;

  /// No description provided for @aboutPlatformWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get aboutPlatformWindows;

  /// No description provided for @aboutPlatformFuchsia.
  ///
  /// In en, this message translates to:
  /// **'Fuchsia'**
  String get aboutPlatformFuchsia;

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutOpenSourceLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View licenses for this app and its dependencies'**
  String get aboutOpenSourceLicensesSubtitle;

  /// No description provided for @aboutLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading app details…'**
  String get aboutLoading;

  /// No description provided for @aboutSphereTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributor'**
  String get aboutSphereTitle;

  /// No description provided for @aboutSphereHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to rotate · it spins slowly on its own'**
  String get aboutSphereHint;

  /// No description provided for @aboutSphereSemantics.
  ///
  /// In en, this message translates to:
  /// **'Interactive 3D sphere displaying information.'**
  String get aboutSphereSemantics;

  /// No description provided for @preferencesSectionAccountFlight.
  ///
  /// In en, this message translates to:
  /// **'Accounts & flight'**
  String get preferencesSectionAccountFlight;

  /// No description provided for @preferencesSectionMapDisplay.
  ///
  /// In en, this message translates to:
  /// **'Map & display'**
  String get preferencesSectionMapDisplay;

  /// No description provided for @preferencesSectionSensorsRecording.
  ///
  /// In en, this message translates to:
  /// **'Sensors & recording'**
  String get preferencesSectionSensorsRecording;

  /// No description provided for @preferencesSectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio & announcements'**
  String get preferencesSectionAudio;

  /// No description provided for @interfaceConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Dashboard layout'**
  String get interfaceConfiguration;

  /// No description provided for @interfaceConfigurationImport.
  ///
  /// In en, this message translates to:
  /// **'Import dashboard layout'**
  String get interfaceConfigurationImport;

  /// No description provided for @interfaceConfigurationExport.
  ///
  /// In en, this message translates to:
  /// **'Export dashboard layout'**
  String get interfaceConfigurationExport;

  /// No description provided for @interfaceConfigurationImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace dashboard layout?'**
  String get interfaceConfigurationImportTitle;

  /// No description provided for @interfaceConfigurationImportConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This replaces all dashboard pages and controls with the imported layout. Theme, language, account settings and flight records are not changed.'**
  String get interfaceConfigurationImportConfirmation;

  /// No description provided for @interfaceConfigurationImported.
  ///
  /// In en, this message translates to:
  /// **'Dashboard layout imported.'**
  String get interfaceConfigurationImported;

  /// No description provided for @interfaceConfigurationImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to import this dashboard layout. Check that the file is valid and compatible.'**
  String get interfaceConfigurationImportFailed;

  /// No description provided for @interfaceConfigurationExported.
  ///
  /// In en, this message translates to:
  /// **'Dashboard layout is ready to share.'**
  String get interfaceConfigurationExported;

  /// No description provided for @interfaceConfigurationExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to export the dashboard layout.'**
  String get interfaceConfigurationExportFailed;

  /// No description provided for @units.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get units;

  /// No description provided for @unitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose default units for dashboard controls'**
  String get unitsSubtitle;

  /// No description provided for @displaySettings.
  ///
  /// In en, this message translates to:
  /// **'Display settings'**
  String get displaySettings;

  /// No description provided for @displaySettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure default numeric precision'**
  String get displaySettingsSubtitle;

  /// No description provided for @defaultPrecision.
  ///
  /// In en, this message translates to:
  /// **'Default precision'**
  String get defaultPrecision;

  /// No description provided for @defaultPrecisionDescription.
  ///
  /// In en, this message translates to:
  /// **'When on, GPS accuracy, altitude, speed, climb rate and wind speed use one decimal place by default. When off, they use whole numbers. Custom precision settings are unchanged.'**
  String get defaultPrecisionDescription;

  /// No description provided for @largerFont.
  ///
  /// In en, this message translates to:
  /// **'Larger font'**
  String get largerFont;

  /// No description provided for @largerFontDescription.
  ///
  /// In en, this message translates to:
  /// **'Enlarge numeric readouts and tighten the spacing within dashboard controls.'**
  String get largerFontDescription;

  /// No description provided for @otherSettings.
  ///
  /// In en, this message translates to:
  /// **'Other settings'**
  String get otherSettings;

  /// No description provided for @otherSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Additional preferences'**
  String get otherSettingsSubtitle;

  /// No description provided for @shareCardFlatDesign.
  ///
  /// In en, this message translates to:
  /// **'Flat share cards'**
  String get shareCardFlatDesign;

  /// No description provided for @shareCardFlatDesignSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a flat design instead of the glass style'**
  String get shareCardFlatDesignSubtitle;

  /// No description provided for @unitAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get unitAltitude;

  /// No description provided for @unitSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get unitSpeed;

  /// No description provided for @unitVerticalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Vertical speed'**
  String get unitVerticalSpeed;

  /// No description provided for @unitDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get unitDistance;

  /// No description provided for @unitPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get unitPressure;

  /// No description provided for @unitTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get unitTemperature;

  /// No description provided for @settingDisplayUnit.
  ///
  /// In en, this message translates to:
  /// **'Display unit'**
  String get settingDisplayUnit;

  /// No description provided for @settingUnitDefault.
  ///
  /// In en, this message translates to:
  /// **'Use Preferences default'**
  String get settingUnitDefault;

  /// No description provided for @unitMeters.
  ///
  /// In en, this message translates to:
  /// **'Meters (m)'**
  String get unitMeters;

  /// No description provided for @unitFeet.
  ///
  /// In en, this message translates to:
  /// **'Feet (ft)'**
  String get unitFeet;

  /// No description provided for @unitKilometersPerHour.
  ///
  /// In en, this message translates to:
  /// **'Kilometers per hour (km/h)'**
  String get unitKilometersPerHour;

  /// No description provided for @unitMetersPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Meters per second (m/s)'**
  String get unitMetersPerSecond;

  /// No description provided for @unitMilesPerHour.
  ///
  /// In en, this message translates to:
  /// **'Miles per hour (mph)'**
  String get unitMilesPerHour;

  /// No description provided for @unitKnots.
  ///
  /// In en, this message translates to:
  /// **'Knots (kn)'**
  String get unitKnots;

  /// No description provided for @unitFeetPerMinute.
  ///
  /// In en, this message translates to:
  /// **'Feet per minute (ft/min)'**
  String get unitFeetPerMinute;

  /// No description provided for @unitAutomaticDistance.
  ///
  /// In en, this message translates to:
  /// **'Automatic (m/km)'**
  String get unitAutomaticDistance;

  /// No description provided for @unitKilometers.
  ///
  /// In en, this message translates to:
  /// **'Kilometers (km)'**
  String get unitKilometers;

  /// No description provided for @unitMiles.
  ///
  /// In en, this message translates to:
  /// **'Miles (mi)'**
  String get unitMiles;

  /// No description provided for @unitHectopascals.
  ///
  /// In en, this message translates to:
  /// **'Hectopascals (hPa)'**
  String get unitHectopascals;

  /// No description provided for @unitInchesOfMercury.
  ///
  /// In en, this message translates to:
  /// **'Inches of mercury (inHg)'**
  String get unitInchesOfMercury;

  /// No description provided for @unitCelsius.
  ///
  /// In en, this message translates to:
  /// **'Celsius (°C)'**
  String get unitCelsius;

  /// No description provided for @unitFahrenheit.
  ///
  /// In en, this message translates to:
  /// **'Fahrenheit (°F)'**
  String get unitFahrenheit;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @accountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your ASFC and XContest accounts'**
  String get accountsSubtitle;

  /// No description provided for @aircraft.
  ///
  /// In en, this message translates to:
  /// **'Aircraft'**
  String get aircraft;

  /// No description provided for @aircraftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure aircraft type, model and flight performance'**
  String get aircraftSubtitle;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'LiveTracking'**
  String get liveTracking;

  /// No description provided for @liveTrackingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your live flight with XContest'**
  String get liveTrackingSubtitle;

  /// No description provided for @liveTrackingEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable LiveTracking'**
  String get liveTrackingEnabled;

  /// No description provided for @liveTrackingEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send your active flight to XContest'**
  String get liveTrackingEnabledSubtitle;

  /// No description provided for @liveTrackingRequiresXContest.
  ///
  /// In en, this message translates to:
  /// **'Sign in to XContest to enable LiveTracking.'**
  String get liveTrackingRequiresXContest;

  /// No description provided for @liveTrackingClaimContest.
  ///
  /// In en, this message translates to:
  /// **'Claim contest flight'**
  String get liveTrackingClaimContest;

  /// No description provided for @liveTrackingClaimContestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Claim the flight for an XContest competition'**
  String get liveTrackingClaimContestSubtitle;

  /// No description provided for @liveTrackingShowPublic.
  ///
  /// In en, this message translates to:
  /// **'Show public tracking'**
  String get liveTrackingShowPublic;

  /// No description provided for @liveTrackingShowPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow your live position to be visible publicly'**
  String get liveTrackingShowPublicSubtitle;

  /// No description provided for @liveTrackingFlightPublic.
  ///
  /// In en, this message translates to:
  /// **'Make flight public'**
  String get liveTrackingFlightPublic;

  /// No description provided for @liveTrackingFlightPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Publish the completed flight on XContest'**
  String get liveTrackingFlightPublicSubtitle;

  /// No description provided for @liveTrackingTemporaryDisable.
  ///
  /// In en, this message translates to:
  /// **'Temporarily stop sharing'**
  String get liveTrackingTemporaryDisable;

  /// No description provided for @liveTrackingTemporaryDisableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pause LiveTracking without changing the main setting'**
  String get liveTrackingTemporaryDisableSubtitle;

  /// No description provided for @liveTrackingTemporarilyDisabled.
  ///
  /// In en, this message translates to:
  /// **'LiveTracking is temporarily paused.'**
  String get liveTrackingTemporarilyDisabled;

  /// No description provided for @liveTrackingReady.
  ///
  /// In en, this message translates to:
  /// **'LiveTracking is configured and ready.'**
  String get liveTrackingReady;

  /// No description provided for @aircraftFaiClass.
  ///
  /// In en, this message translates to:
  /// **'FAI class'**
  String get aircraftFaiClass;

  /// No description provided for @aircraftFaiParaglider.
  ///
  /// In en, this message translates to:
  /// **'Paraglider (FAI-3)'**
  String get aircraftFaiParaglider;

  /// No description provided for @aircraftFaiHangGlider.
  ///
  /// In en, this message translates to:
  /// **'Hangglider (FAI-1)'**
  String get aircraftFaiHangGlider;

  /// No description provided for @aircraftFaiRigidWing.
  ///
  /// In en, this message translates to:
  /// **'Rigid Wing (FAI-5)'**
  String get aircraftFaiRigidWing;

  /// No description provided for @aircraftFaiRigidWingFai2.
  ///
  /// In en, this message translates to:
  /// **'Rigid Wing (FAI-2)'**
  String get aircraftFaiRigidWingFai2;

  /// No description provided for @aircraftFaiPoweredParagliderFoot.
  ///
  /// In en, this message translates to:
  /// **'RPF (Paramotor - foot launched)'**
  String get aircraftFaiPoweredParagliderFoot;

  /// No description provided for @aircraftFaiPoweredParagliderTrike.
  ///
  /// In en, this message translates to:
  /// **'RPL (Paramotor - landplane/trike)'**
  String get aircraftFaiPoweredParagliderTrike;

  /// No description provided for @aircraftFaiPoweredAircraft.
  ///
  /// In en, this message translates to:
  /// **'RAL (Landplane/Movable aerodynamic control)'**
  String get aircraftFaiPoweredAircraft;

  /// No description provided for @aircraftFaiRigidWingPowered.
  ///
  /// In en, this message translates to:
  /// **'RWL (Landplane/Weight-shift control)'**
  String get aircraftFaiRigidWingPowered;

  /// No description provided for @aircraftFaiRigidWingFootLaunched.
  ///
  /// In en, this message translates to:
  /// **'RWF (Foot-launched/Weight-shift control)'**
  String get aircraftFaiRigidWingFootLaunched;

  /// No description provided for @aircraftFaiRigidGlider.
  ///
  /// In en, this message translates to:
  /// **'RGL (Landplane/autogyro)'**
  String get aircraftFaiRigidGlider;

  /// No description provided for @aircraftCategoryStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get aircraftCategoryStandard;

  /// No description provided for @aircraftCategoryPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get aircraftCategoryPerformance;

  /// No description provided for @aircraftCategoryCompetition.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get aircraftCategoryCompetition;

  /// No description provided for @aircraftCategoryFlexWing.
  ///
  /// In en, this message translates to:
  /// **'Flex wing'**
  String get aircraftCategoryFlexWing;

  /// No description provided for @aircraftCategoryRigidWing.
  ///
  /// In en, this message translates to:
  /// **'Rigid wing'**
  String get aircraftCategoryRigidWing;

  /// No description provided for @aircraftCategoryClass1.
  ///
  /// In en, this message translates to:
  /// **'Class 1'**
  String get aircraftCategoryClass1;

  /// No description provided for @aircraftCategoryClass5.
  ///
  /// In en, this message translates to:
  /// **'Class 5'**
  String get aircraftCategoryClass5;

  /// No description provided for @aircraftManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get aircraftManufacturer;

  /// No description provided for @aircraftSelectManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Select a manufacturer'**
  String get aircraftSelectManufacturer;

  /// No description provided for @aircraftModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get aircraftModel;

  /// No description provided for @aircraftSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select a model'**
  String get aircraftSelectModel;

  /// No description provided for @aircraftName.
  ///
  /// In en, this message translates to:
  /// **'Aircraft name'**
  String get aircraftName;

  /// No description provided for @aircraftParagliderCategory.
  ///
  /// In en, this message translates to:
  /// **'Paraglider category'**
  String get aircraftParagliderCategory;

  /// No description provided for @aircraftHangGliderCategory.
  ///
  /// In en, this message translates to:
  /// **'Hang glider category'**
  String get aircraftHangGliderCategory;

  /// No description provided for @aircraftTandem.
  ///
  /// In en, this message translates to:
  /// **'Tandem / biplace'**
  String get aircraftTandem;

  /// No description provided for @aircraftTandemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This aircraft carries two people'**
  String get aircraftTandemSubtitle;

  /// No description provided for @aircraftEngineType.
  ///
  /// In en, this message translates to:
  /// **'Engine type'**
  String get aircraftEngineType;

  /// No description provided for @aircraftEngineNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get aircraftEngineNone;

  /// No description provided for @aircraftEngineElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get aircraftEngineElectric;

  /// No description provided for @aircraftEngineInternalCombustion.
  ///
  /// In en, this message translates to:
  /// **'Internal combustion'**
  String get aircraftEngineInternalCombustion;

  /// No description provided for @aircraftTrimSpeed.
  ///
  /// In en, this message translates to:
  /// **'Trim speed (km/h)'**
  String get aircraftTrimSpeed;

  /// No description provided for @aircraftGoalGlideRatio.
  ///
  /// In en, this message translates to:
  /// **'Goal glide ratio'**
  String get aircraftGoalGlideRatio;

  /// No description provided for @aircraftPositiveNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number.'**
  String get aircraftPositiveNumberRequired;

  /// No description provided for @aircraftSave.
  ///
  /// In en, this message translates to:
  /// **'Save aircraft'**
  String get aircraftSave;

  /// No description provided for @flightDetailAircraft.
  ///
  /// In en, this message translates to:
  /// **'Aircraft'**
  String get flightDetailAircraft;

  /// No description provided for @flightDetailAircraftEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Aircraft'**
  String get flightDetailAircraftEdit;

  /// No description provided for @flightDetailAircraftClass.
  ///
  /// In en, this message translates to:
  /// **'FAI class'**
  String get flightDetailAircraftClass;

  /// No description provided for @flightDetailAircraftManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get flightDetailAircraftManufacturer;

  /// No description provided for @flightDetailAircraftModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get flightDetailAircraftModel;

  /// No description provided for @flightDetailAircraftName.
  ///
  /// In en, this message translates to:
  /// **'Aircraft name'**
  String get flightDetailAircraftName;

  /// No description provided for @flightDetailAircraftCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get flightDetailAircraftCategory;

  /// No description provided for @flightDetailAircraftTandem.
  ///
  /// In en, this message translates to:
  /// **'Tandem'**
  String get flightDetailAircraftTandem;

  /// No description provided for @flightDetailAircraftEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get flightDetailAircraftEngine;

  /// No description provided for @flightDetailAircraftTrimSpeed.
  ///
  /// In en, this message translates to:
  /// **'Trim speed'**
  String get flightDetailAircraftTrimSpeed;

  /// No description provided for @flightDetailAircraftGlideRatio.
  ///
  /// In en, this message translates to:
  /// **'Goal glide ratio'**
  String get flightDetailAircraftGlideRatio;

  /// No description provided for @aircraftTandemYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get aircraftTandemYes;

  /// No description provided for @aircraftTandemNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get aircraftTandemNo;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @asfcAccount.
  ///
  /// In en, this message translates to:
  /// **'ASFC account'**
  String get asfcAccount;

  /// No description provided for @asfcAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your ASFC / GoFly account'**
  String get asfcAccountSubtitle;

  /// No description provided for @xcontestAccount.
  ///
  /// In en, this message translates to:
  /// **'XContest account'**
  String get xcontestAccount;

  /// No description provided for @xcontestAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your XContest account'**
  String get xcontestAccountSubtitle;

  /// No description provided for @xcontestUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get xcontestUsername;

  /// No description provided for @xcontestPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get xcontestPassword;

  /// No description provided for @xcontestUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get xcontestUserId;

  /// No description provided for @xcontestFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get xcontestFullName;

  /// No description provided for @xcontestProfileInformation.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get xcontestProfileInformation;

  /// No description provided for @xcontestSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in to XContest'**
  String get xcontestSignedIn;

  /// No description provided for @xcontestCredentialsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your XContest username and password.'**
  String get xcontestCredentialsRequired;

  /// No description provided for @xcontestInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'The XContest username or password is incorrect.'**
  String get xcontestInvalidCredentials;

  /// No description provided for @xcontestConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to XContest. Check your network and try again.'**
  String get xcontestConnectionFailed;

  /// No description provided for @xcontestLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'XContest login failed. Try again.'**
  String get xcontestLoginFailed;

  /// No description provided for @asfcUsername.
  ///
  /// In en, this message translates to:
  /// **'Username or mobile'**
  String get asfcUsername;

  /// No description provided for @asfcPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get asfcPassword;

  /// No description provided for @asfcPasswordLogin.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get asfcPasswordLogin;

  /// No description provided for @asfcSmsLogin.
  ///
  /// In en, this message translates to:
  /// **'SMS code'**
  String get asfcSmsLogin;

  /// No description provided for @asfcMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get asfcMobile;

  /// No description provided for @asfcSmsCode.
  ///
  /// In en, this message translates to:
  /// **'SMS code'**
  String get asfcSmsCode;

  /// No description provided for @asfcCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Image code'**
  String get asfcCaptcha;

  /// No description provided for @asfcRefreshCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Refresh image code'**
  String get asfcRefreshCaptcha;

  /// No description provided for @asfcSendSmsCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get asfcSendSmsCode;

  /// No description provided for @asfcSmsCountdown.
  ///
  /// In en, this message translates to:
  /// **'Retry {seconds}s'**
  String asfcSmsCountdown(int seconds);

  /// No description provided for @asfcMobileRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number.'**
  String get asfcMobileRequired;

  /// No description provided for @asfcCaptchaRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the image code.'**
  String get asfcCaptchaRequired;

  /// No description provided for @asfcSmsCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the SMS code.'**
  String get asfcSmsCodeRequired;

  /// No description provided for @asfcSmsCredentialsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number and SMS code.'**
  String get asfcSmsCredentialsRequired;

  /// No description provided for @asfcCaptchaLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load the image code.'**
  String get asfcCaptchaLoadFailed;

  /// No description provided for @asfcSmsCodeSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to send the SMS code.'**
  String get asfcSmsCodeSendFailed;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @loggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging in…'**
  String get loggingIn;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @asfcSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get asfcSignedIn;

  /// No description provided for @asfcProfileInformation.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get asfcProfileInformation;

  /// No description provided for @asfcRefreshProfile.
  ///
  /// In en, this message translates to:
  /// **'Refresh account information'**
  String get asfcRefreshProfile;

  /// No description provided for @asfcProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load account information.'**
  String get asfcProfileLoadFailed;

  /// No description provided for @asfcNoProfileInformation.
  ///
  /// In en, this message translates to:
  /// **'No account information is available.'**
  String get asfcNoProfileInformation;

  /// No description provided for @asfcInformationAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get asfcInformationAvailable;

  /// No description provided for @applyForCertificate.
  ///
  /// In en, this message translates to:
  /// **'Apply for certificate'**
  String get applyForCertificate;

  /// No description provided for @certificateDetails.
  ///
  /// In en, this message translates to:
  /// **'Certificate details'**
  String get certificateDetails;

  /// No description provided for @certificateDetailsView.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get certificateDetailsView;

  /// No description provided for @certificateCardView.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get certificateCardView;

  /// No description provided for @certificateSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left or right to switch views'**
  String get certificateSwipeHint;

  /// No description provided for @certificateCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Aviation Sports Pilot Certificate'**
  String get certificateCardTitle;

  /// No description provided for @certificateIssued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get certificateIssued;

  /// No description provided for @certificatePendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get certificatePendingApproval;

  /// No description provided for @certificatePendingApprovalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your certificate application is being reviewed.'**
  String get certificatePendingApprovalSubtitle;

  /// No description provided for @certificateNumber.
  ///
  /// In en, this message translates to:
  /// **'Certificate number'**
  String get certificateNumber;

  /// No description provided for @certificateLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get certificateLevel;

  /// No description provided for @certificateSportCode.
  ///
  /// In en, this message translates to:
  /// **'Sport code'**
  String get certificateSportCode;

  /// No description provided for @certificateValidityStatus.
  ///
  /// In en, this message translates to:
  /// **'Validity status'**
  String get certificateValidityStatus;

  /// No description provided for @certificateValidity.
  ///
  /// In en, this message translates to:
  /// **'Validity period'**
  String get certificateValidity;

  /// No description provided for @certificateIssueDate.
  ///
  /// In en, this message translates to:
  /// **'Issue date'**
  String get certificateIssueDate;

  /// No description provided for @certificatePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get certificatePhoto;

  /// No description provided for @certificateUpgrade.
  ///
  /// In en, this message translates to:
  /// **'License upgrade'**
  String get certificateUpgrade;

  /// No description provided for @certificateSignInList.
  ///
  /// In en, this message translates to:
  /// **'Sign-in list'**
  String get certificateSignInList;

  /// No description provided for @certificateSignInDate.
  ///
  /// In en, this message translates to:
  /// **'Sign-in date'**
  String get certificateSignInDate;

  /// No description provided for @certificateReviewUnit.
  ///
  /// In en, this message translates to:
  /// **'Reviewer'**
  String get certificateReviewUnit;

  /// No description provided for @certificateNoSignIns.
  ///
  /// In en, this message translates to:
  /// **'No sign-in records'**
  String get certificateNoSignIns;

  /// No description provided for @asfcFlightRecords.
  ///
  /// In en, this message translates to:
  /// **'ASFC flight records'**
  String get asfcFlightRecords;

  /// No description provided for @asfcFlightSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit flight record'**
  String get asfcFlightSubmit;

  /// No description provided for @asfcFlightEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit flight record'**
  String get asfcFlightEdit;

  /// No description provided for @asfcFlightDetails.
  ///
  /// In en, this message translates to:
  /// **'Flight record details'**
  String get asfcFlightDetails;

  /// No description provided for @asfcFlightNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No ASFC flight records'**
  String get asfcFlightNoRecords;

  /// No description provided for @asfcFlightDate.
  ///
  /// In en, this message translates to:
  /// **'Training date'**
  String get asfcFlightDate;

  /// No description provided for @asfcFlightAddress.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get asfcFlightAddress;

  /// No description provided for @asfcFlightModel.
  ///
  /// In en, this message translates to:
  /// **'Aircraft model'**
  String get asfcFlightModel;

  /// No description provided for @asfcFlightTask.
  ///
  /// In en, this message translates to:
  /// **'Flight task'**
  String get asfcFlightTask;

  /// No description provided for @asfcFlightStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get asfcFlightStartTime;

  /// No description provided for @asfcFlightEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get asfcFlightEndTime;

  /// No description provided for @asfcFlightTime.
  ///
  /// In en, this message translates to:
  /// **'Flight time'**
  String get asfcFlightTime;

  /// No description provided for @asfcFlightSeatType.
  ///
  /// In en, this message translates to:
  /// **'Seat type'**
  String get asfcFlightSeatType;

  /// No description provided for @asfcFlightFrontSeat.
  ///
  /// In en, this message translates to:
  /// **'Front seat'**
  String get asfcFlightFrontSeat;

  /// No description provided for @asfcFlightBackSeat.
  ///
  /// In en, this message translates to:
  /// **'Back seat'**
  String get asfcFlightBackSeat;

  /// No description provided for @asfcFlightTakeoffMode.
  ///
  /// In en, this message translates to:
  /// **'Takeoff mode'**
  String get asfcFlightTakeoffMode;

  /// No description provided for @asfcFlightSortie.
  ///
  /// In en, this message translates to:
  /// **'Sorties'**
  String get asfcFlightSortie;

  /// No description provided for @asfcFlightAgency.
  ///
  /// In en, this message translates to:
  /// **'Training agency'**
  String get asfcFlightAgency;

  /// No description provided for @asfcFlightCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get asfcFlightCoach;

  /// No description provided for @asfcFlightSignin.
  ///
  /// In en, this message translates to:
  /// **'Coach sign-in note'**
  String get asfcFlightSignin;

  /// No description provided for @asfcFlightSelectAgency.
  ///
  /// In en, this message translates to:
  /// **'Select an agency'**
  String get asfcFlightSelectAgency;

  /// No description provided for @asfcFlightSelectCoach.
  ///
  /// In en, this message translates to:
  /// **'Select a coach'**
  String get asfcFlightSelectCoach;

  /// No description provided for @asfcFlightLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get asfcFlightLoading;

  /// No description provided for @asfcFlightRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get asfcFlightRequired;

  /// No description provided for @asfcFlightSelectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Select an agency, coach and takeoff mode.'**
  String get asfcFlightSelectionRequired;

  /// No description provided for @asfcFlightSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the flight record.'**
  String get asfcFlightSaveFailed;

  /// No description provided for @asfcFlightDeleted.
  ///
  /// In en, this message translates to:
  /// **'Flight record deleted.'**
  String get asfcFlightDeleted;

  /// No description provided for @asfcFlightDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete the flight record.'**
  String get asfcFlightDeleteFailed;

  /// No description provided for @asfcFlightDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete flight record?'**
  String get asfcFlightDeleteTitle;

  /// No description provided for @asfcFlightDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This flight record will be permanently deleted.'**
  String get asfcFlightDeleteConfirmation;

  /// No description provided for @certificateApplication.
  ///
  /// In en, this message translates to:
  /// **'ASFC certificate application'**
  String get certificateApplication;

  /// No description provided for @certificateApplicationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit a paragliding license application through your ASFC account.'**
  String get certificateApplicationSubtitle;

  /// No description provided for @certificateFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get certificateFullName;

  /// No description provided for @certificateGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get certificateGender;

  /// No description provided for @certificateMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get certificateMale;

  /// No description provided for @certificateFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get certificateFemale;

  /// No description provided for @certificateBirthday.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get certificateBirthday;

  /// No description provided for @certificateCountry.
  ///
  /// In en, this message translates to:
  /// **'Nationality'**
  String get certificateCountry;

  /// No description provided for @certificateEthnicity.
  ///
  /// In en, this message translates to:
  /// **'Ethnicity'**
  String get certificateEthnicity;

  /// No description provided for @certificateIdNumber.
  ///
  /// In en, this message translates to:
  /// **'ID card number'**
  String get certificateIdNumber;

  /// No description provided for @certificateMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get certificateMobile;

  /// No description provided for @certificateEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get certificateEmail;

  /// No description provided for @certificateAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get certificateAddress;

  /// No description provided for @certificateArea.
  ///
  /// In en, this message translates to:
  /// **'Permanent residence'**
  String get certificateArea;

  /// No description provided for @certificateAgency.
  ///
  /// In en, this message translates to:
  /// **'Training agency'**
  String get certificateAgency;

  /// No description provided for @certificateCoachId.
  ///
  /// In en, this message translates to:
  /// **'Coach ID (optional)'**
  String get certificateCoachId;

  /// No description provided for @certificateCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get certificateCoach;

  /// No description provided for @certificateCoachSelect.
  ///
  /// In en, this message translates to:
  /// **'Select a coach (optional)'**
  String get certificateCoachSelect;

  /// No description provided for @certificateCoachesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading coaches…'**
  String get certificateCoachesLoading;

  /// No description provided for @certificateDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get certificateDocuments;

  /// No description provided for @licensePhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload license photo'**
  String get licensePhoto;

  /// No description provided for @groupPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload training group photo'**
  String get groupPhoto;

  /// No description provided for @licensePhotoUploaded.
  ///
  /// In en, this message translates to:
  /// **'License photo uploaded'**
  String get licensePhotoUploaded;

  /// No description provided for @groupPhotoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Group photo uploaded'**
  String get groupPhotoUploaded;

  /// No description provided for @certificateEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get certificateEmergencyContact;

  /// No description provided for @certificateContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact name'**
  String get certificateContactName;

  /// No description provided for @certificateContactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get certificateContactPhone;

  /// No description provided for @certificateBloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood type'**
  String get certificateBloodType;

  /// No description provided for @certificateRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get certificateRequired;

  /// No description provided for @certificatePhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Upload both certificate photos before submitting.'**
  String get certificatePhotoRequired;

  /// No description provided for @certificateNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your ASFC account first.'**
  String get certificateNotSignedIn;

  /// No description provided for @certificateImageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose an image smaller than 10 MB.'**
  String get certificateImageInvalid;

  /// No description provided for @certificateImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to upload the image.'**
  String get certificateImageUploadFailed;

  /// No description provided for @certificateApplicationFailed.
  ///
  /// In en, this message translates to:
  /// **'The certificate application failed.'**
  String get certificateApplicationFailed;

  /// No description provided for @certificateApplicationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Certificate application submitted.'**
  String get certificateApplicationSuccess;

  /// No description provided for @submitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit application'**
  String get submitApplication;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get submitting;

  /// No description provided for @asfcLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Check your account details.'**
  String get asfcLoginFailed;

  /// No description provided for @asfcLoginFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {reason}'**
  String asfcLoginFailedWithReason(String reason);

  /// No description provided for @asfcConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Check your network and try again.'**
  String get asfcConnectionFailed;

  /// No description provided for @asfcCredentialsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your username and password.'**
  String get asfcCredentialsRequired;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

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
  /// **'Sensor'**
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

  /// No description provided for @autoDeleteShortFlights.
  ///
  /// In en, this message translates to:
  /// **'Automatically delete short flights'**
  String get autoDeleteShortFlights;

  /// No description provided for @autoDeleteShortFlightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove completed flight records shorter than the selected duration'**
  String get autoDeleteShortFlightsSubtitle;

  /// No description provided for @shortFlightThreshold.
  ///
  /// In en, this message translates to:
  /// **'Minimum duration to keep'**
  String get shortFlightThreshold;

  /// No description provided for @shortFlightThreshold30Seconds.
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get shortFlightThreshold30Seconds;

  /// No description provided for @shortFlightThreshold1Minute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get shortFlightThreshold1Minute;

  /// No description provided for @shortFlightThreshold2Minutes.
  ///
  /// In en, this message translates to:
  /// **'2 minutes'**
  String get shortFlightThreshold2Minutes;

  /// No description provided for @shortFlightThreshold5Minutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get shortFlightThreshold5Minutes;

  /// No description provided for @deleteExistingShortFlightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete short flights?'**
  String get deleteExistingShortFlightsTitle;

  /// No description provided for @deleteExistingShortFlightsMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 existing flight record is} other{{count} existing flight records are}} shorter than {duration}. Delete {count, plural, =1{it} other{them}} now? This cannot be undone.'**
  String deleteExistingShortFlightsMessage(int count, String duration);

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

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

  /// No description provided for @weatherPickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get weatherPickOnMap;

  /// No description provided for @weatherFavorites.
  ///
  /// In en, this message translates to:
  /// **'Saved locations'**
  String get weatherFavorites;

  /// No description provided for @weatherFavoriteAdd.
  ///
  /// In en, this message translates to:
  /// **'Save this location'**
  String get weatherFavoriteAdd;

  /// No description provided for @weatherFavoriteRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get weatherFavoriteRemove;

  /// No description provided for @weatherFavoriteRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get weatherFavoriteRename;

  /// No description provided for @weatherFavoriteName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get weatherFavoriteName;

  /// No description provided for @weatherFavoriteSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved “{name}”'**
  String weatherFavoriteSaved(String name);

  /// No description provided for @weatherFavoriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved locations'**
  String get weatherFavoriteRemoved;

  /// No description provided for @weatherFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved locations yet'**
  String get weatherFavoritesEmpty;

  /// No description provided for @weatherFavoritesManage.
  ///
  /// In en, this message translates to:
  /// **'Manage saved locations'**
  String get weatherFavoritesManage;

  /// No description provided for @mapPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a location'**
  String get mapPickerTitle;

  /// No description provided for @mapPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the map to place the crosshair, then confirm.'**
  String get mapPickerHint;

  /// No description provided for @mapPickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get mapPickerConfirm;

  /// No description provided for @mapPickerMyLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get mapPickerMyLocation;

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

  /// No description provided for @weatherForecastDaily.
  ///
  /// In en, this message translates to:
  /// **'Forecast daily'**
  String get weatherForecastDaily;

  /// Title of the wind-vs-altitude list; {time} is the hour every row is read at.
  ///
  /// In en, this message translates to:
  /// **'Wind speed · {time}'**
  String weatherWindSpeedAt(String time);

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

  /// No description provided for @controlClimbAverage.
  ///
  /// In en, this message translates to:
  /// **'Climb Average'**
  String get controlClimbAverage;

  /// No description provided for @controlTakeoffWaypoint.
  ///
  /// In en, this message translates to:
  /// **'Takeoff Waypoint'**
  String get controlTakeoffWaypoint;

  /// No description provided for @controlDefaultLandingWaypoint.
  ///
  /// In en, this message translates to:
  /// **'Default Landing Point'**
  String get controlDefaultLandingWaypoint;

  /// No description provided for @controlLastLandingWaypoint.
  ///
  /// In en, this message translates to:
  /// **'Last Landing Point'**
  String get controlLastLandingWaypoint;

  /// No description provided for @takeoffPointLabel.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get takeoffPointLabel;

  /// No description provided for @takeoffDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'DIST'**
  String get takeoffDistanceLabel;

  /// No description provided for @takeoffAltitudeDifferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'ALT DIFF'**
  String get takeoffAltitudeDifferenceLabel;

  /// No description provided for @waypointBearingLabel.
  ///
  /// In en, this message translates to:
  /// **'BRG'**
  String get waypointBearingLabel;

  /// No description provided for @waypointGlideLabel.
  ///
  /// In en, this message translates to:
  /// **'GLIDE'**
  String get waypointGlideLabel;

  /// No description provided for @waypointEtaLabel.
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get waypointEtaLabel;

  /// No description provided for @climbAverageLabel.
  ///
  /// In en, this message translates to:
  /// **'CLIMB AVG'**
  String get climbAverageLabel;

  /// No description provided for @peakLabel.
  ///
  /// In en, this message translates to:
  /// **'PEAK'**
  String get peakLabel;

  /// No description provided for @controlVerticalGraph.
  ///
  /// In en, this message translates to:
  /// **'Vertical Graph'**
  String get controlVerticalGraph;

  /// No description provided for @controlAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get controlAltitude;

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

  /// No description provided for @controlAltitudeAboveTakeoff.
  ///
  /// In en, this message translates to:
  /// **'Altitude Above Takeoff'**
  String get controlAltitudeAboveTakeoff;

  /// No description provided for @controlMaxAltitude.
  ///
  /// In en, this message translates to:
  /// **'Max Altitude'**
  String get controlMaxAltitude;

  /// No description provided for @controlThermalGain.
  ///
  /// In en, this message translates to:
  /// **'Thermal Gain'**
  String get controlThermalGain;

  /// No description provided for @controlLastThermalGain.
  ///
  /// In en, this message translates to:
  /// **'Last Thermal Gain'**
  String get controlLastThermalGain;

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

  /// No description provided for @controlGpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'GPS Accuracy'**
  String get controlGpsAccuracy;

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

  /// No description provided for @controlDistanceToNearestLanding.
  ///
  /// In en, this message translates to:
  /// **'Distance to Nearest Landing'**
  String get controlDistanceToNearestLanding;

  /// No description provided for @controlDistanceToDefaultLanding.
  ///
  /// In en, this message translates to:
  /// **'Distance to Default Landing'**
  String get controlDistanceToDefaultLanding;

  /// No description provided for @controlBearingToNearestLanding.
  ///
  /// In en, this message translates to:
  /// **'Bearing to Nearest Landing'**
  String get controlBearingToNearestLanding;

  /// No description provided for @controlBearingToDefaultLanding.
  ///
  /// In en, this message translates to:
  /// **'Bearing to Default Landing'**
  String get controlBearingToDefaultLanding;

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

  /// No description provided for @controlPhoneBattery.
  ///
  /// In en, this message translates to:
  /// **'Phone Battery'**
  String get controlPhoneBattery;

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

  /// No description provided for @mapNoBasemap.
  ///
  /// In en, this message translates to:
  /// **'No basemap'**
  String get mapNoBasemap;

  /// No description provided for @mapOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline · {filename}'**
  String mapOffline(String filename);

  /// No description provided for @mapOfflineNoFilename.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get mapOfflineNoFilename;

  /// No description provided for @mapRecenterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Re-center'**
  String get mapRecenterTooltip;

  /// No description provided for @mapZoomInTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get mapZoomInTooltip;

  /// No description provided for @mapZoomOutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get mapZoomOutTooltip;

  /// No description provided for @mapCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Map cache data'**
  String get mapCacheTitle;

  /// No description provided for @mapCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached map blocks by source, with a combined summary.'**
  String get mapCacheSubtitle;

  /// No description provided for @mapCacheSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get mapCacheSummary;

  /// No description provided for @mapCacheLegacySource.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized older cache'**
  String get mapCacheLegacySource;

  /// No description provided for @mapCacheClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear map cache?'**
  String get mapCacheClearTitle;

  /// No description provided for @mapCacheClearConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Downloaded online map tiles will be removed; offline .mbtiles maps are not affected.'**
  String get mapCacheClearConfirmation;

  /// No description provided for @mapCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Map cache cleared.'**
  String get mapCacheCleared;

  /// No description provided for @mapCacheClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to clear the map cache.'**
  String get mapCacheClearFailed;

  /// No description provided for @mapCacheSizeLoading.
  ///
  /// In en, this message translates to:
  /// **'Calculating map cache data…'**
  String get mapCacheSizeLoading;

  /// No description provided for @mapCacheSizeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map cache data unavailable'**
  String get mapCacheSizeUnavailable;

  /// No description provided for @mapCacheSizeDetails.
  ///
  /// In en, this message translates to:
  /// **'{size} · {tiles} blocks · {bytes} bytes'**
  String mapCacheSizeDetails(String size, int tiles, int bytes);

  /// No description provided for @mapHeading.
  ///
  /// In en, this message translates to:
  /// **'HDG'**
  String get mapHeading;

  /// No description provided for @mapAltitude.
  ///
  /// In en, this message translates to:
  /// **'ALT'**
  String get mapAltitude;

  /// No description provided for @mapRequiredGlideRatio.
  ///
  /// In en, this message translates to:
  /// **'L/D REQ'**
  String get mapRequiredGlideRatio;

  /// No description provided for @varioLegendSink.
  ///
  /// In en, this message translates to:
  /// **'SINK'**
  String get varioLegendSink;

  /// No description provided for @varioLegendNeutral.
  ///
  /// In en, this message translates to:
  /// **'NEUTRAL'**
  String get varioLegendNeutral;

  /// No description provided for @varioLegendLift.
  ///
  /// In en, this message translates to:
  /// **'LIFT'**
  String get varioLegendLift;

  /// No description provided for @gpsNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'ParaBeacon — recording flight'**
  String get gpsNotificationTitle;

  /// No description provided for @gpsNotificationText.
  ///
  /// In en, this message translates to:
  /// **'Logging your track with the screen off. Tap to return.'**
  String get gpsNotificationText;

  /// No description provided for @gpsNotificationChannel.
  ///
  /// In en, this message translates to:
  /// **'Flight recording'**
  String get gpsNotificationChannel;

  /// No description provided for @debugSensorTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug Sensor'**
  String get debugSensorTitle;

  /// No description provided for @debugSensorReset.
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get debugSensorReset;

  /// No description provided for @debugSensorVerticalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Vertical speed'**
  String get debugSensorVerticalSpeed;

  /// No description provided for @debugSensorAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get debugSensorAltitude;

  /// No description provided for @debugSensorGroundSpeed.
  ///
  /// In en, this message translates to:
  /// **'Ground speed'**
  String get debugSensorGroundSpeed;

  /// No description provided for @debugSensorHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get debugSensorHeading;

  /// No description provided for @debugSensorWindSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind speed'**
  String get debugSensorWindSpeed;

  /// No description provided for @debugSensorWindDirection.
  ///
  /// In en, this message translates to:
  /// **'Wind direction'**
  String get debugSensorWindDirection;

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
  /// **'Tap to toggle auto-detection; long-press for settings'**
  String get flightButtonAutoTooltip;

  /// No description provided for @flightAutoSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto take-off / landing'**
  String get flightAutoSettingsTitle;

  /// No description provided for @flightAutoSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust shared take-off and landing detection settings'**
  String get flightAutoSettingsSubtitle;

  /// No description provided for @resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetToDefaults;

  /// No description provided for @flightAutoTakeoffSpeed.
  ///
  /// In en, this message translates to:
  /// **'Take-off speed threshold'**
  String get flightAutoTakeoffSpeed;

  /// No description provided for @flightAutoLandingMinimumFlight.
  ///
  /// In en, this message translates to:
  /// **'Minimum flight before landing detection'**
  String get flightAutoLandingMinimumFlight;

  /// No description provided for @flightAutoLandingSpeedSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Landing speed threshold'**
  String get flightAutoLandingSpeedSensitivity;

  /// No description provided for @flightLandingAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic landing'**
  String get flightLandingAutomatic;

  /// No description provided for @flightLandingAutomaticDescription.
  ///
  /// In en, this message translates to:
  /// **'End the flight automatically when landing is detected'**
  String get flightLandingAutomaticDescription;

  /// No description provided for @flightLandingManual.
  ///
  /// In en, this message translates to:
  /// **'Manual confirmation'**
  String get flightLandingManual;

  /// No description provided for @flightLandingManualDescription.
  ///
  /// In en, this message translates to:
  /// **'Ask before ending the flight after landing is detected'**
  String get flightLandingManualDescription;

  /// No description provided for @flightLandingNoDetection.
  ///
  /// In en, this message translates to:
  /// **'Do not detect landing'**
  String get flightLandingNoDetection;

  /// No description provided for @flightLandingNoDetectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Take-off detection stays on; stop the flight manually'**
  String get flightLandingNoDetectionDescription;

  /// No description provided for @flightLandingDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Landing detected'**
  String get flightLandingDetectedTitle;

  /// No description provided for @flightLandingDetectedBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm landing and finish this flight recording?'**
  String get flightLandingDetectedBody;

  /// No description provided for @flightLandingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Just landed'**
  String get flightLandingConfirm;

  /// No description provided for @flightLandingStillFlying.
  ///
  /// In en, this message translates to:
  /// **'Still flying'**
  String get flightLandingStillFlying;

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

  /// No description provided for @settingShowVerticalAcceleration.
  ///
  /// In en, this message translates to:
  /// **'Show vertical acceleration'**
  String get settingShowVerticalAcceleration;

  /// No description provided for @settingVerticalAccelerationFillOpacity.
  ///
  /// In en, this message translates to:
  /// **'Acceleration fill opacity'**
  String get settingVerticalAccelerationFillOpacity;

  /// No description provided for @settingVerticalGraphInterval.
  ///
  /// In en, this message translates to:
  /// **'Shown interval'**
  String get settingVerticalGraphInterval;

  /// No description provided for @settingVerticalGraphStep.
  ///
  /// In en, this message translates to:
  /// **'Vertical step'**
  String get settingVerticalGraphStep;

  /// No description provided for @settingVerticalGraphDotSize.
  ///
  /// In en, this message translates to:
  /// **'Dot size'**
  String get settingVerticalGraphDotSize;

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

  /// No description provided for @settingDecimalPlaces.
  ///
  /// In en, this message translates to:
  /// **'Decimal places'**
  String get settingDecimalPlaces;

  /// No description provided for @settingDecimalPlacesAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingDecimalPlacesAuto;

  /// No description provided for @settingDecimalPlacesDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingDecimalPlacesDefault;

  /// No description provided for @settingLatitudeDecimals.
  ///
  /// In en, this message translates to:
  /// **'Latitude decimal places'**
  String get settingLatitudeDecimals;

  /// No description provided for @settingLongitudeDecimals.
  ///
  /// In en, this message translates to:
  /// **'Longitude decimal places'**
  String get settingLongitudeDecimals;

  /// No description provided for @settingDmsSecondsDecimals.
  ///
  /// In en, this message translates to:
  /// **'DMS seconds decimal places'**
  String get settingDmsSecondsDecimals;

  /// No description provided for @settingAverageDecimals.
  ///
  /// In en, this message translates to:
  /// **'Average decimal places'**
  String get settingAverageDecimals;

  /// No description provided for @settingPeakDecimals.
  ///
  /// In en, this message translates to:
  /// **'Peak decimal places'**
  String get settingPeakDecimals;

  /// No description provided for @settingRatioDecimals.
  ///
  /// In en, this message translates to:
  /// **'Glide ratio decimal places'**
  String get settingRatioDecimals;

  /// No description provided for @settingVarioDecimals.
  ///
  /// In en, this message translates to:
  /// **'Vario decimal places'**
  String get settingVarioDecimals;

  /// No description provided for @settingHeadingDecimals.
  ///
  /// In en, this message translates to:
  /// **'Heading decimal places'**
  String get settingHeadingDecimals;

  /// No description provided for @settingWindSpeedDecimals.
  ///
  /// In en, this message translates to:
  /// **'Wind speed decimal places'**
  String get settingWindSpeedDecimals;

  /// No description provided for @settingGroundSpeedDecimals.
  ///
  /// In en, this message translates to:
  /// **'Ground speed decimal places'**
  String get settingGroundSpeedDecimals;

  /// No description provided for @settingWindDirectionDecimals.
  ///
  /// In en, this message translates to:
  /// **'Wind direction decimal places'**
  String get settingWindDirectionDecimals;

  /// No description provided for @settingZoomLevelDecimals.
  ///
  /// In en, this message translates to:
  /// **'Zoom level decimal places'**
  String get settingZoomLevelDecimals;

  /// No description provided for @settingGridDistanceDecimals.
  ///
  /// In en, this message translates to:
  /// **'Grid distance decimal places'**
  String get settingGridDistanceDecimals;

  /// No description provided for @settingMapScaleDistanceDecimals.
  ///
  /// In en, this message translates to:
  /// **'Map scale distance decimal places'**
  String get settingMapScaleDistanceDecimals;

  /// No description provided for @settingVarioMinimumDecimals.
  ///
  /// In en, this message translates to:
  /// **'Vario scale minimum decimal places'**
  String get settingVarioMinimumDecimals;

  /// No description provided for @settingSinkThresholdDecimals.
  ///
  /// In en, this message translates to:
  /// **'Sink threshold decimal places'**
  String get settingSinkThresholdDecimals;

  /// No description provided for @settingLiftThresholdDecimals.
  ///
  /// In en, this message translates to:
  /// **'Lift threshold decimal places'**
  String get settingLiftThresholdDecimals;

  /// No description provided for @settingVarioMaximumDecimals.
  ///
  /// In en, this message translates to:
  /// **'Vario scale maximum decimal places'**
  String get settingVarioMaximumDecimals;

  /// No description provided for @settingAltitudeDecimals.
  ///
  /// In en, this message translates to:
  /// **'Altitude decimal places'**
  String get settingAltitudeDecimals;

  /// No description provided for @settingAccelerationDecimals.
  ///
  /// In en, this message translates to:
  /// **'Acceleration decimal places'**
  String get settingAccelerationDecimals;

  /// No description provided for @settingDistanceDecimals.
  ///
  /// In en, this message translates to:
  /// **'Distance decimal places'**
  String get settingDistanceDecimals;

  /// No description provided for @settingAltitudeDifferenceDecimals.
  ///
  /// In en, this message translates to:
  /// **'Altitude difference decimal places'**
  String get settingAltitudeDifferenceDecimals;

  /// No description provided for @settingBearingDecimals.
  ///
  /// In en, this message translates to:
  /// **'Bearing decimal places'**
  String get settingBearingDecimals;

  /// No description provided for @settingAccuracyDecimals.
  ///
  /// In en, this message translates to:
  /// **'Accuracy decimal places'**
  String get settingAccuracyDecimals;

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

  /// No description provided for @settingShowSourceIcon.
  ///
  /// In en, this message translates to:
  /// **'Show source icon'**
  String get settingShowSourceIcon;

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

  /// No description provided for @settingBearingReference.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get settingBearingReference;

  /// No description provided for @settingBearingAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Absolute (compass)'**
  String get settingBearingAbsolute;

  /// No description provided for @settingBearingRelative.
  ///
  /// In en, this message translates to:
  /// **'Relative (to heading)'**
  String get settingBearingRelative;

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

  /// No description provided for @settingShowDistance.
  ///
  /// In en, this message translates to:
  /// **'Show distance'**
  String get settingShowDistance;

  /// No description provided for @settingShowBearingMetric.
  ///
  /// In en, this message translates to:
  /// **'Show bearing'**
  String get settingShowBearingMetric;

  /// No description provided for @settingShowElevation.
  ///
  /// In en, this message translates to:
  /// **'Show elevation change'**
  String get settingShowElevation;

  /// No description provided for @settingShowGlide.
  ///
  /// In en, this message translates to:
  /// **'Show glide ratio'**
  String get settingShowGlide;

  /// No description provided for @settingShowEta.
  ///
  /// In en, this message translates to:
  /// **'Show ETA'**
  String get settingShowEta;

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

  /// No description provided for @settingAirspaceCount.
  ///
  /// In en, this message translates to:
  /// **'Nearest airspaces to plot'**
  String get settingAirspaceCount;

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

  /// No description provided for @settingShowTakeoffPoint.
  ///
  /// In en, this message translates to:
  /// **'Show take-off point'**
  String get settingShowTakeoffPoint;

  /// No description provided for @settingShowDefaultLandingPoint.
  ///
  /// In en, this message translates to:
  /// **'Show default landing point'**
  String get settingShowDefaultLandingPoint;

  /// No description provided for @settingShowNearestLandingPoint.
  ///
  /// In en, this message translates to:
  /// **'Show nearest landing point'**
  String get settingShowNearestLandingPoint;

  /// No description provided for @settingShowDefaultLandingLine.
  ///
  /// In en, this message translates to:
  /// **'Show line to default landing point'**
  String get settingShowDefaultLandingLine;

  /// No description provided for @settingShowLastLandingLine.
  ///
  /// In en, this message translates to:
  /// **'Show line to nearest landing point'**
  String get settingShowLastLandingLine;

  /// No description provided for @settingTakeoffPointColor.
  ///
  /// In en, this message translates to:
  /// **'Take-off marker color'**
  String get settingTakeoffPointColor;

  /// No description provided for @settingDefaultLandingPointColor.
  ///
  /// In en, this message translates to:
  /// **'Default landing marker color'**
  String get settingDefaultLandingPointColor;

  /// No description provided for @settingLastLandingPointColor.
  ///
  /// In en, this message translates to:
  /// **'Nearest landing marker color'**
  String get settingLastLandingPointColor;

  /// No description provided for @settingTakeoffLineColor.
  ///
  /// In en, this message translates to:
  /// **'Take-off line color'**
  String get settingTakeoffLineColor;

  /// No description provided for @settingDefaultLandingLineColor.
  ///
  /// In en, this message translates to:
  /// **'Default landing line color'**
  String get settingDefaultLandingLineColor;

  /// No description provided for @settingLastLandingLineColor.
  ///
  /// In en, this message translates to:
  /// **'Nearest landing line color'**
  String get settingLastLandingLineColor;

  /// No description provided for @colorPalettePreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Color picker palette'**
  String get colorPalettePreferencesTitle;

  /// No description provided for @colorPalettePreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} preset colors in every picker'**
  String colorPalettePreferencesSubtitle(int count);

  /// No description provided for @colorPaletteSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 20 preset colors. High Saturation adds dark and bright high-saturation colors; when enabled, black, white and gray are appended at the end.'**
  String get colorPaletteSettingsDescription;

  /// No description provided for @colorPaletteIncludeNeutralColors.
  ///
  /// In en, this message translates to:
  /// **'Include black, white and gray'**
  String get colorPaletteIncludeNeutralColors;

  /// No description provided for @colorPaletteIncludeNeutralColorsDescription.
  ///
  /// In en, this message translates to:
  /// **'Append black, white and gray to the end of each palette.'**
  String get colorPaletteIncludeNeutralColorsDescription;

  /// No description provided for @colorPaletteSchemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get colorPaletteSchemeLabel;

  /// No description provided for @colorPaletteSchemeHighSaturation.
  ///
  /// In en, this message translates to:
  /// **'High Saturation'**
  String get colorPaletteSchemeHighSaturation;

  /// No description provided for @colorPaletteSchemeMacaron.
  ///
  /// In en, this message translates to:
  /// **'Macaron'**
  String get colorPaletteSchemeMacaron;

  /// No description provided for @colorPaletteSchemeMorandi.
  ///
  /// In en, this message translates to:
  /// **'Morandi'**
  String get colorPaletteSchemeMorandi;

  /// No description provided for @colorPaletteSchemeEarth.
  ///
  /// In en, this message translates to:
  /// **'Earth'**
  String get colorPaletteSchemeEarth;

  /// No description provided for @colorPaletteSchemeDarkTech.
  ///
  /// In en, this message translates to:
  /// **'Dark Tech'**
  String get colorPaletteSchemeDarkTech;

  /// No description provided for @colorPaletteSchemeMaldivesOcean.
  ///
  /// In en, this message translates to:
  /// **'Maldives Ocean'**
  String get colorPaletteSchemeMaldivesOcean;

  /// No description provided for @colorPaletteSchemeForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get colorPaletteSchemeForest;

  /// No description provided for @colorPaletteSchemeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get colorPaletteSchemeSunset;

  /// No description provided for @colorPaletteSchemeLavender.
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get colorPaletteSchemeLavender;

  /// No description provided for @colorPaletteSchemeNordic.
  ///
  /// In en, this message translates to:
  /// **'Nordic'**
  String get colorPaletteSchemeNordic;

  /// No description provided for @colorPaletteSchemeDesert.
  ///
  /// In en, this message translates to:
  /// **'Desert'**
  String get colorPaletteSchemeDesert;

  /// No description provided for @colorPaletteSchemeSakura.
  ///
  /// In en, this message translates to:
  /// **'Sakura'**
  String get colorPaletteSchemeSakura;

  /// No description provided for @colorPaletteSchemeGlacier.
  ///
  /// In en, this message translates to:
  /// **'Glacier'**
  String get colorPaletteSchemeGlacier;

  /// No description provided for @colorPaletteCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of preset colors'**
  String get colorPaletteCountLabel;

  /// No description provided for @colorPaletteSettingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} colors'**
  String colorPaletteSettingsCount(int count);

  /// No description provided for @landingPointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Landing points'**
  String get landingPointsTitle;

  /// No description provided for @landingPointsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage saved landing destinations and the default target.'**
  String get landingPointsSubtitle;

  /// No description provided for @landingPointsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No landing points saved yet. Add your current location or pick a point on the map.'**
  String get landingPointsEmpty;

  /// No description provided for @landingPointAddCurrent.
  ///
  /// In en, this message translates to:
  /// **'Add current location'**
  String get landingPointAddCurrent;

  /// No description provided for @landingPointNoGpsFix.
  ///
  /// In en, this message translates to:
  /// **'A valid GPS fix is required to save the current location.'**
  String get landingPointNoGpsFix;

  /// No description provided for @landingPointAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add landing point'**
  String get landingPointAddTitle;

  /// No description provided for @landingPointName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get landingPointName;

  /// No description provided for @landingPointCoordinates.
  ///
  /// In en, this message translates to:
  /// **'GPS coordinates'**
  String get landingPointCoordinates;

  /// No description provided for @landingPointAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get landingPointAltitude;

  /// No description provided for @landingPointNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this landing point.'**
  String get landingPointNameRequired;

  /// No description provided for @landingPointAltitudeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid altitude between -12,000 and 100,000 m.'**
  String get landingPointAltitudeInvalid;

  /// No description provided for @landingPointGpsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'GPS accuracy'**
  String get landingPointGpsAccuracy;

  /// No description provided for @landingPointCapturedAt.
  ///
  /// In en, this message translates to:
  /// **'Location captured'**
  String get landingPointCapturedAt;

  /// No description provided for @landingPointNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get landingPointNotes;

  /// No description provided for @landingPointSave.
  ///
  /// In en, this message translates to:
  /// **'Save landing point'**
  String get landingPointSave;

  /// No description provided for @landingPointDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get landingPointDefault;

  /// No description provided for @landingPointLast.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get landingPointLast;

  /// No description provided for @landingPointActions.
  ///
  /// In en, this message translates to:
  /// **'Landing point actions'**
  String get landingPointActions;

  /// No description provided for @landingPointClearDefault.
  ///
  /// In en, this message translates to:
  /// **'Clear default landing point'**
  String get landingPointClearDefault;

  /// No description provided for @landingPointSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default landing point'**
  String get landingPointSetDefault;

  /// No description provided for @landingPointDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete landing point'**
  String get landingPointDelete;

  /// No description provided for @landingPointPickMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose location on map'**
  String get landingPointPickMapTitle;

  /// No description provided for @landingPointPickPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to choose a landing point location.'**
  String get landingPointPickPrompt;

  /// No description provided for @landingPointSaved.
  ///
  /// In en, this message translates to:
  /// **'Landing point saved'**
  String get landingPointSaved;

  /// No description provided for @mapTakeoffLabel.
  ///
  /// In en, this message translates to:
  /// **'Take-off'**
  String get mapTakeoffLabel;

  /// No description provided for @dataMonitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Monitor'**
  String get dataMonitorTitle;

  /// No description provided for @dataMonitorMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize data monitor'**
  String get dataMonitorMinimize;

  /// No description provided for @dataMonitorRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore data monitor'**
  String get dataMonitorRestore;

  /// No description provided for @dataMonitorResize.
  ///
  /// In en, this message translates to:
  /// **'Resize data monitor'**
  String get dataMonitorResize;

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

  /// No description provided for @flightsImport.
  ///
  /// In en, this message translates to:
  /// **'Import flights'**
  String get flightsImport;

  /// No description provided for @flightsImportLibrary.
  ///
  /// In en, this message translates to:
  /// **'Import library (.pbflights.zip)'**
  String get flightsImportLibrary;

  /// No description provided for @flightsImportXcTrack.
  ///
  /// In en, this message translates to:
  /// **'Import XCTrack flights (.igc)'**
  String get flightsImportXcTrack;

  /// No description provided for @flightsImportFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the selected file.'**
  String get flightsImportFileUnreadable;

  /// No description provided for @flightsExportDestinationTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should the export go?'**
  String get flightsExportDestinationTitle;

  /// No description provided for @flightsExportDestinationDownloads.
  ///
  /// In en, this message translates to:
  /// **'Save to Downloads'**
  String get flightsExportDestinationDownloads;

  /// No description provided for @flightsExportDestinationShare.
  ///
  /// In en, this message translates to:
  /// **'Share directly'**
  String get flightsExportDestinationShare;

  /// No description provided for @flightsExportSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Export saved to Downloads/ParaBeacon.'**
  String get flightsExportSavedToDownloads;

  /// No description provided for @flightsImportXcTrackPickMode.
  ///
  /// In en, this message translates to:
  /// **'How do you want to select the tracklogs?'**
  String get flightsImportXcTrackPickMode;

  /// No description provided for @flightsImportModeFolder.
  ///
  /// In en, this message translates to:
  /// **'Select a folder'**
  String get flightsImportModeFolder;

  /// No description provided for @flightsImportModeFolderNote.
  ///
  /// In en, this message translates to:
  /// **'Import every .igc in a folder — no file limit'**
  String get flightsImportModeFolderNote;

  /// No description provided for @flightsImportModeFiles.
  ///
  /// In en, this message translates to:
  /// **'Select files'**
  String get flightsImportModeFiles;

  /// No description provided for @flightsImportModeFilesNote.
  ///
  /// In en, this message translates to:
  /// **'Pick individual .igc files (up to 100)'**
  String get flightsImportModeFilesNote;

  /// No description provided for @flightsImportXcTrackNote.
  ///
  /// In en, this message translates to:
  /// **'XCTrack stores tracklogs at:\n/storage/emulated/0/Android/data/org.xcontest.XCTrack/files/Tracklogs\n\nThat folder can\'t be opened directly on most phones. Copy it (or its .igc files) to Download first, then import from there.'**
  String get flightsImportXcTrackNote;

  /// No description provided for @flightsImportingXcTrack.
  ///
  /// In en, this message translates to:
  /// **'Importing XCTrack flights…'**
  String get flightsImportingXcTrack;

  /// No description provided for @flightsImportNoIgc.
  ///
  /// In en, this message translates to:
  /// **'No .igc files were found in that folder.'**
  String get flightsImportNoIgc;

  /// No description provided for @flightsExportLibrary.
  ///
  /// In en, this message translates to:
  /// **'Export library (.pbflights.zip)'**
  String get flightsExportLibrary;

  /// No description provided for @flightsSelectRecords.
  ///
  /// In en, this message translates to:
  /// **'Select flights to export'**
  String get flightsSelectRecords;

  /// No description provided for @flightsExportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export selected flights (.pbflights.zip)'**
  String get flightsExportSelected;

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

  /// No description provided for @flightsLibraryExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Flight bundle saved on the device.'**
  String get flightsLibraryExportSaved;

  /// No description provided for @flightsExportDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Export complete'**
  String get flightsExportDoneTitle;

  /// No description provided for @flightsExportDoneSaved.
  ///
  /// In en, this message translates to:
  /// **'The flight bundle was saved to your device.'**
  String get flightsExportDoneSaved;

  /// No description provided for @flightsExportDoneShared.
  ///
  /// In en, this message translates to:
  /// **'The flight bundle is ready to share.'**
  String get flightsExportDoneShared;

  /// No description provided for @flightsExportDetailFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get flightsExportDetailFlights;

  /// No description provided for @flightsExportDetailFileName.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get flightsExportDetailFileName;

  /// No description provided for @flightsExportDetailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get flightsExportDetailSize;

  /// No description provided for @flightsExportDetailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get flightsExportDetailLocation;

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

  /// No description provided for @flightDetailTrimLog.
  ///
  /// In en, this message translates to:
  /// **'Trim flight log'**
  String get flightDetailTrimLog;

  /// No description provided for @flightDetailTrimDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the first and last samples to keep. Keep at least two points; removed samples cannot be restored.'**
  String get flightDetailTrimDescription;

  /// No description provided for @flightDetailTrimFrom.
  ///
  /// In en, this message translates to:
  /// **'Keep from {time}'**
  String flightDetailTrimFrom(String time);

  /// No description provided for @flightDetailTrimThrough.
  ///
  /// In en, this message translates to:
  /// **'Keep through {time}'**
  String flightDetailTrimThrough(String time);

  /// No description provided for @flightDetailTrimCounts.
  ///
  /// In en, this message translates to:
  /// **'Keep {kept} samples · remove {removed}'**
  String flightDetailTrimCounts(int kept, int removed);

  /// No description provided for @flightDetailTrimApply.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get flightDetailTrimApply;

  /// No description provided for @flightDetailTrimApplied.
  ///
  /// In en, this message translates to:
  /// **'Flight log trimmed.'**
  String get flightDetailTrimApplied;

  /// No description provided for @replayTrimUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This flight log changed or is no longer available. Close and reopen replay before trimming.'**
  String get replayTrimUnavailable;

  /// No description provided for @flightDetailFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get flightDetailFlight;

  /// No description provided for @flightDetailRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get flightDetailRoute;

  /// No description provided for @flightDetailAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get flightDetailAltitude;

  /// No description provided for @flightDetailRouteMetrics.
  ///
  /// In en, this message translates to:
  /// **'Route metrics'**
  String get flightDetailRouteMetrics;

  /// No description provided for @flightDetailSpeedGlide.
  ///
  /// In en, this message translates to:
  /// **'Speed & glide'**
  String get flightDetailSpeedGlide;

  /// No description provided for @flightDetailClimbAltitude.
  ///
  /// In en, this message translates to:
  /// **'Climb & altitude'**
  String get flightDetailClimbAltitude;

  /// No description provided for @flightDetailTimeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Time breakdown'**
  String get flightDetailTimeBreakdown;

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

  /// No description provided for @flightDetailPilot.
  ///
  /// In en, this message translates to:
  /// **'Pilot'**
  String get flightDetailPilot;

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

  /// No description provided for @flightDetailFlatTriangle.
  ///
  /// In en, this message translates to:
  /// **'Flat triangle'**
  String get flightDetailFlatTriangle;

  /// No description provided for @flightDetailThreeTurnpoints.
  ///
  /// In en, this message translates to:
  /// **'3-turnpoint distance'**
  String get flightDetailThreeTurnpoints;

  /// No description provided for @flightDetailClosing.
  ///
  /// In en, this message translates to:
  /// **'closing'**
  String get flightDetailClosing;

  /// No description provided for @flightDetailMaxAltGain.
  ///
  /// In en, this message translates to:
  /// **'Max. alt. gain'**
  String get flightDetailMaxAltGain;

  /// No description provided for @flightDetailElevationDrop.
  ///
  /// In en, this message translates to:
  /// **'Elevation drop'**
  String get flightDetailElevationDrop;

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

  /// No description provided for @flightShareCardNoTrack.
  ///
  /// In en, this message translates to:
  /// **'No track'**
  String get flightShareCardNoTrack;

  /// No description provided for @flightShareCardNoAltitude.
  ///
  /// In en, this message translates to:
  /// **'No altitude data'**
  String get flightShareCardNoAltitude;

  /// No description provided for @flightShareCardFooter.
  ///
  /// In en, this message translates to:
  /// **'Recorded with ParaBeacon · {points} points'**
  String flightShareCardFooter(int points);

  /// No description provided for @flightReportTitle.
  ///
  /// In en, this message translates to:
  /// **'ParaBeacon Flight Report'**
  String get flightReportTitle;

  /// No description provided for @flightReportDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get flightReportDate;

  /// No description provided for @flightReportTrackMap.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get flightReportTrackMap;

  /// No description provided for @flightReportAltitudeProfile.
  ///
  /// In en, this message translates to:
  /// **'Altitude profile'**
  String get flightReportAltitudeProfile;

  /// No description provided for @flightReportSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get flightReportSummary;

  /// No description provided for @flightReportDistanceAltitude.
  ///
  /// In en, this message translates to:
  /// **'Distance & altitude'**
  String get flightReportDistanceAltitude;

  /// No description provided for @flightReportGeneratedBy.
  ///
  /// In en, this message translates to:
  /// **'Generated by ParaBeacon'**
  String get flightReportGeneratedBy;

  /// No description provided for @flightReportPage.
  ///
  /// In en, this message translates to:
  /// **'Page {current} / {total}'**
  String flightReportPage(int current, int total);

  /// No description provided for @flightsStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get flightsStatistics;

  /// No description provided for @flightsStatisticsAll.
  ///
  /// In en, this message translates to:
  /// **'Statistics (all flights)'**
  String get flightsStatisticsAll;

  /// No description provided for @flightsStatisticsSelected.
  ///
  /// In en, this message translates to:
  /// **'Statistics (selected flights)'**
  String get flightsStatisticsSelected;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Flight statistics'**
  String get statsTitle;

  /// No description provided for @statsScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All flights · {count}'**
  String statsScopeAll(int count);

  /// No description provided for @statsScopeSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected · {count}'**
  String statsScopeSelected(int count);

  /// No description provided for @statsNoData.
  ///
  /// In en, this message translates to:
  /// **'No flights to analyze'**
  String get statsNoData;

  /// No description provided for @statsNoDataHint.
  ///
  /// In en, this message translates to:
  /// **'Record or select flights to see statistics.'**
  String get statsNoDataHint;

  /// No description provided for @statsPrioritySummary.
  ///
  /// In en, this message translates to:
  /// **'Summary first'**
  String get statsPrioritySummary;

  /// No description provided for @statsPriorityDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed stats'**
  String get statsPriorityDetailed;

  /// No description provided for @statsComputingDetailed.
  ///
  /// In en, this message translates to:
  /// **'Calculating detailed stats · {completed} / {total} flights'**
  String statsComputingDetailed(int completed, int total);

  /// No description provided for @statsNoDetailedTracks.
  ///
  /// In en, this message translates to:
  /// **'No recorded track details are available.'**
  String get statsNoDetailedTracks;

  /// No description provided for @statsCalculationFailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed statistics could not be calculated. Your summary is still available.'**
  String get statsCalculationFailed;

  /// No description provided for @statsNotEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data'**
  String get statsNotEnoughData;

  /// No description provided for @statsRecordOn.
  ///
  /// In en, this message translates to:
  /// **'on {date}'**
  String statsRecordOn(String date);

  /// No description provided for @statsFlightsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No flights} =1{1 flight} other{{count} flights}}'**
  String statsFlightsCount(int count);

  /// No description provided for @statsSectionOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statsSectionOverview;

  /// No description provided for @statsSectionRecords.
  ///
  /// In en, this message translates to:
  /// **'Personal records'**
  String get statsSectionRecords;

  /// No description provided for @statsSectionAverages.
  ///
  /// In en, this message translates to:
  /// **'Averages'**
  String get statsSectionAverages;

  /// No description provided for @statsSectionTotals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get statsSectionTotals;

  /// No description provided for @statsSectionByYear.
  ///
  /// In en, this message translates to:
  /// **'Flights by year'**
  String get statsSectionByYear;

  /// No description provided for @statsSectionByMonth.
  ///
  /// In en, this message translates to:
  /// **'Seasonality (by month)'**
  String get statsSectionByMonth;

  /// No description provided for @statsSectionByAircraft.
  ///
  /// In en, this message translates to:
  /// **'By glider / aircraft'**
  String get statsSectionByAircraft;

  /// No description provided for @statsUnknownType.
  ///
  /// In en, this message translates to:
  /// **'Unknown type'**
  String get statsUnknownType;

  /// No description provided for @statsSectionBySite.
  ///
  /// In en, this message translates to:
  /// **'By takeoff site'**
  String get statsSectionBySite;

  /// No description provided for @statsFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get statsFlights;

  /// No description provided for @statsTotalAirtime.
  ///
  /// In en, this message translates to:
  /// **'Total airtime'**
  String get statsTotalAirtime;

  /// No description provided for @statsTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get statsTotalDistance;

  /// No description provided for @statsTotalXcDistance.
  ///
  /// In en, this message translates to:
  /// **'Total XC distance'**
  String get statsTotalXcDistance;

  /// No description provided for @statsDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get statsDateRange;

  /// No description provided for @statsActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get statsActiveDays;

  /// No description provided for @statsFlightsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Flights / active day'**
  String get statsFlightsPerDay;

  /// No description provided for @statsFirstFlight.
  ///
  /// In en, this message translates to:
  /// **'First flight'**
  String get statsFirstFlight;

  /// No description provided for @statsLastFlight.
  ///
  /// In en, this message translates to:
  /// **'Last flight'**
  String get statsLastFlight;

  /// No description provided for @statsSampledFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights with track data'**
  String get statsSampledFlights;

  /// No description provided for @statsLongestFlight.
  ///
  /// In en, this message translates to:
  /// **'Longest flight'**
  String get statsLongestFlight;

  /// No description provided for @statsLongestDistance.
  ///
  /// In en, this message translates to:
  /// **'Longest track distance'**
  String get statsLongestDistance;

  /// No description provided for @statsLongestXc.
  ///
  /// In en, this message translates to:
  /// **'Longest straight distance'**
  String get statsLongestXc;

  /// No description provided for @statsMaxDistanceFromStart.
  ///
  /// In en, this message translates to:
  /// **'Farthest from launch'**
  String get statsMaxDistanceFromStart;

  /// No description provided for @statsHighestAltitude.
  ///
  /// In en, this message translates to:
  /// **'Highest altitude'**
  String get statsHighestAltitude;

  /// No description provided for @statsLowestAltitude.
  ///
  /// In en, this message translates to:
  /// **'Lowest altitude'**
  String get statsLowestAltitude;

  /// No description provided for @statsMaxClimb.
  ///
  /// In en, this message translates to:
  /// **'Strongest climb'**
  String get statsMaxClimb;

  /// No description provided for @statsMaxSink.
  ///
  /// In en, this message translates to:
  /// **'Strongest sink'**
  String get statsMaxSink;

  /// No description provided for @statsMaxSpeed.
  ///
  /// In en, this message translates to:
  /// **'Top speed'**
  String get statsMaxSpeed;

  /// No description provided for @statsBestGlide.
  ///
  /// In en, this message translates to:
  /// **'Best glide ratio'**
  String get statsBestGlide;

  /// No description provided for @statsBestFaiTriangle.
  ///
  /// In en, this message translates to:
  /// **'Best FAI triangle'**
  String get statsBestFaiTriangle;

  /// No description provided for @statsAvgDuration.
  ///
  /// In en, this message translates to:
  /// **'Avg flight time'**
  String get statsAvgDuration;

  /// No description provided for @statsAvgDistance.
  ///
  /// In en, this message translates to:
  /// **'Avg track distance'**
  String get statsAvgDistance;

  /// No description provided for @statsAvgXcDistance.
  ///
  /// In en, this message translates to:
  /// **'Avg straight distance'**
  String get statsAvgXcDistance;

  /// No description provided for @statsAvgMaxAltitude.
  ///
  /// In en, this message translates to:
  /// **'Avg max altitude'**
  String get statsAvgMaxAltitude;

  /// No description provided for @statsAvgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg ground speed'**
  String get statsAvgSpeed;

  /// No description provided for @statsAvgGlide.
  ///
  /// In en, this message translates to:
  /// **'Avg glide ratio'**
  String get statsAvgGlide;

  /// No description provided for @statsTotalAltGained.
  ///
  /// In en, this message translates to:
  /// **'Total altitude gained'**
  String get statsTotalAltGained;

  /// No description provided for @statsTotalAltLost.
  ///
  /// In en, this message translates to:
  /// **'Total altitude lost'**
  String get statsTotalAltLost;

  /// No description provided for @statsTotalThermals.
  ///
  /// In en, this message translates to:
  /// **'Thermals climbed'**
  String get statsTotalThermals;

  /// No description provided for @statsTotalMovingTime.
  ///
  /// In en, this message translates to:
  /// **'Total moving time'**
  String get statsTotalMovingTime;

  /// No description provided for @statsTotalSamples.
  ///
  /// In en, this message translates to:
  /// **'Track points'**
  String get statsTotalSamples;

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

  /// No description provided for @flightsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete flight?'**
  String get flightsDeleteTitle;

  /// No description provided for @flightsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This flight record will be permanently deleted. This cannot be undone.'**
  String get flightsDeleteMessage;

  /// Confirmation title for deleting selected flight records.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected flight records?'**
  String flightsDeleteSelectedTitle(int count);

  /// No description provided for @flightsDeleteSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected flight records will be permanently deleted. This cannot be undone.'**
  String get flightsDeleteSelectedMessage;

  /// No description provided for @flightsMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge flights'**
  String get flightsMerge;

  /// No description provided for @flightsMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge {count} flights?'**
  String flightsMergeTitle(int count);

  /// No description provided for @flightsMergeMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected flights will be combined into one record from {start} to {end}. The time between flights is kept as missing data and is marked in replay and 3D replay. The original records will be replaced. This cannot be undone.'**
  String flightsMergeMessage(String start, String end);

  /// No description provided for @flightsMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get flightsMergeConfirm;

  /// No description provided for @flightsMergeDone.
  ///
  /// In en, this message translates to:
  /// **'Flights merged into one record.'**
  String get flightsMergeDone;

  /// No description provided for @flightsMergeNotPossibleTitle.
  ///
  /// In en, this message translates to:
  /// **'These flights can\'t be merged'**
  String get flightsMergeNotPossibleTitle;

  /// No description provided for @flightsMergeConditions.
  ///
  /// In en, this message translates to:
  /// **'Requirements: consecutive flights, at most {minutes} min and {km} km from landing to the next takeoff, the same wing and the same pilot.'**
  String flightsMergeConditions(int minutes, String km);

  /// No description provided for @flightsMergeIssueTooFew.
  ///
  /// In en, this message translates to:
  /// **'Select at least 2 flights to merge.'**
  String get flightsMergeIssueTooFew;

  /// No description provided for @flightsMergeIssueRecording.
  ///
  /// In en, this message translates to:
  /// **'Flight {flight} is still being recorded.'**
  String flightsMergeIssueRecording(String flight);

  /// No description provided for @flightsMergeIssueNotInLog.
  ///
  /// In en, this message translates to:
  /// **'Flight {flight} is no longer in the flight log.'**
  String flightsMergeIssueNotInLog(String flight);

  /// No description provided for @flightsMergeIssueNoSamples.
  ///
  /// In en, this message translates to:
  /// **'Flight {flight} has no GPS track data.'**
  String flightsMergeIssueNoSamples(String flight);

  /// No description provided for @flightsMergeIssueNoFix.
  ///
  /// In en, this message translates to:
  /// **'Flight {flight} has no valid GPS fix.'**
  String flightsMergeIssueNoFix(String flight);

  /// No description provided for @flightsMergeIssueOverlap.
  ///
  /// In en, this message translates to:
  /// **'{first} → {second}: the flights overlap by {duration}.'**
  String flightsMergeIssueOverlap(String first, String second, String duration);

  /// No description provided for @flightsMergeIssueGap.
  ///
  /// In en, this message translates to:
  /// **'{first} → {second}: {duration} between landing and the next takeoff (max {max}).'**
  String flightsMergeIssueGap(
    String first,
    String second,
    String duration,
    String max,
  );

  /// No description provided for @flightsMergeIssueDistance.
  ///
  /// In en, this message translates to:
  /// **'{first} → {second}: the landing point is {distance} km from the next takeoff (max {max} km).'**
  String flightsMergeIssueDistance(
    String first,
    String second,
    String distance,
    String max,
  );

  /// No description provided for @flightsMergeIssueAircraft.
  ///
  /// In en, this message translates to:
  /// **'{first} → {second}: different wings ({previous} / {next}).'**
  String flightsMergeIssueAircraft(
    String first,
    String second,
    String previous,
    String next,
  );

  /// No description provided for @flightsMergeIssuePilot.
  ///
  /// In en, this message translates to:
  /// **'{first} → {second}: different pilots ({previous} / {next}).'**
  String flightsMergeIssuePilot(
    String first,
    String second,
    String previous,
    String next,
  );

  /// No description provided for @replayDataGapBanner.
  ///
  /// In en, this message translates to:
  /// **'No data {start} – {end} ({duration})'**
  String replayDataGapBanner(String start, String end, String duration);

  /// No description provided for @replayDataGapSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 missing-data period} other{{count} missing-data periods}} · {total}'**
  String replayDataGapSummary(int count, String total);

  /// No description provided for @replayDataGapNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get replayDataGapNoData;

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

  /// No description provided for @sensorTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensor'**
  String get sensorTitle;

  /// No description provided for @sensorOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get sensorOptions;

  /// No description provided for @sensorEnableBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Enable Bluetooth sensor'**
  String get sensorEnableBluetooth;

  /// No description provided for @sensorEnableBluetoothSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan and connect to external sensors'**
  String get sensorEnableBluetoothSubtitle;

  /// No description provided for @sensorPreferInternal.
  ///
  /// In en, this message translates to:
  /// **'Prefer internal sensor'**
  String get sensorPreferInternal;

  /// No description provided for @sensorPreferInternalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this device’s built-in barometer first'**
  String get sensorPreferInternalSubtitle;

  /// No description provided for @sensorNoInternalBarometer.
  ///
  /// In en, this message translates to:
  /// **'No built-in barometer detected on this device'**
  String get sensorNoInternalBarometer;

  /// No description provided for @sensorInternalSection.
  ///
  /// In en, this message translates to:
  /// **'Internal sensor'**
  String get sensorInternalSection;

  /// No description provided for @sensorStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get sensorStatus;

  /// No description provided for @sensorBarometerNotDetected.
  ///
  /// In en, this message translates to:
  /// **'No barometer detected'**
  String get sensorBarometerNotDetected;

  /// No description provided for @sensorBarometerConnected.
  ///
  /// In en, this message translates to:
  /// **'Barometer connected'**
  String get sensorBarometerConnected;

  /// No description provided for @sensorBarometerNotPreferred.
  ///
  /// In en, this message translates to:
  /// **'Barometer detected (not preferred)'**
  String get sensorBarometerNotPreferred;

  /// No description provided for @sensorConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get sensorConnection;

  /// No description provided for @sensorBluetoothState.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth: {state}'**
  String sensorBluetoothState(String state);

  /// No description provided for @sensorLiveDataFields.
  ///
  /// In en, this message translates to:
  /// **'Live data fields'**
  String get sensorLiveDataFields;

  /// No description provided for @sensorNearbyDevices.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get sensorNearbyDevices;

  /// No description provided for @sensorFieldAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get sensorFieldAltitude;

  /// No description provided for @sensorFieldVerticalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Vertical speed'**
  String get sensorFieldVerticalSpeed;

  /// No description provided for @sensorFieldPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get sensorFieldPressure;

  /// No description provided for @sensorFieldTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get sensorFieldTemperature;

  /// No description provided for @sensorFieldHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get sensorFieldHeartRate;

  /// No description provided for @sensorFieldBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get sensorFieldBattery;

  /// No description provided for @sensorFieldQnh.
  ///
  /// In en, this message translates to:
  /// **'QNH (reference)'**
  String get sensorFieldQnh;

  /// No description provided for @sensorCalibrate.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get sensorCalibrate;

  /// No description provided for @sensorCalibrationReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get sensorCalibrationReset;

  /// No description provided for @sensorCalibrationStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard reference (1013.25 hPa)'**
  String get sensorCalibrationStandard;

  /// No description provided for @sensorCalibrationCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Calibrated to a known altitude'**
  String get sensorCalibrationCalibrated;

  /// No description provided for @sensorCalibrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibrate altitude'**
  String get sensorCalibrateTitle;

  /// No description provided for @sensorCalibrateDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the current known altitude. The reference pressure (QNH) is adjusted so the barometric altitude matches.'**
  String get sensorCalibrateDescription;

  /// No description provided for @sensorCalibrateAltitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Current altitude'**
  String get sensorCalibrateAltitudeLabel;

  /// No description provided for @sensorCalibrateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid altitude'**
  String get sensorCalibrateInvalid;

  /// No description provided for @sensorCalibrateFailed.
  ///
  /// In en, this message translates to:
  /// **'Calibration failed — no barometer reading or value out of range'**
  String get sensorCalibrateFailed;

  /// No description provided for @sensorExtCalibrationSection.
  ///
  /// In en, this message translates to:
  /// **'External sensor altitude'**
  String get sensorExtCalibrationSection;

  /// No description provided for @sensorExtCalibrationCurrent.
  ///
  /// In en, this message translates to:
  /// **'Calibrated altitude'**
  String get sensorExtCalibrationCurrent;

  /// No description provided for @sensorFieldAltitudeOffset.
  ///
  /// In en, this message translates to:
  /// **'Altitude offset'**
  String get sensorFieldAltitudeOffset;

  /// No description provided for @sensorExtCalibrationNone.
  ///
  /// In en, this message translates to:
  /// **'No offset applied (raw sensor altitude)'**
  String get sensorExtCalibrationNone;

  /// No description provided for @sensorExtCalibrationApplied.
  ///
  /// In en, this message translates to:
  /// **'Calibrated to a known altitude'**
  String get sensorExtCalibrationApplied;

  /// No description provided for @sensorNoDeviceSelected.
  ///
  /// In en, this message translates to:
  /// **'No device selected'**
  String get sensorNoDeviceSelected;

  /// No description provided for @sensorDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get sensorDevice;

  /// No description provided for @sensorConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get sensorConnected;

  /// No description provided for @sensorConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get sensorConnecting;

  /// No description provided for @sensorDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get sensorDisconnected;

  /// No description provided for @sensorConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get sensorConnect;

  /// No description provided for @sensorDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get sensorDisconnect;

  /// No description provided for @sensorForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get sensorForget;

  /// No description provided for @sensorScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get sensorScan;

  /// No description provided for @sensorStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get sensorStop;

  /// No description provided for @sensorDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get sensorDevices;

  /// No description provided for @sensorTapScan.
  ///
  /// In en, this message translates to:
  /// **'Tap Scan'**
  String get sensorTapScan;

  /// No description provided for @sensorEnableFirst.
  ///
  /// In en, this message translates to:
  /// **'Enable first'**
  String get sensorEnableFirst;

  /// No description provided for @sensorUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'(unknown)'**
  String get sensorUnknownDevice;

  /// No description provided for @sensorRssiDbm.
  ///
  /// In en, this message translates to:
  /// **'{rssi} dBm'**
  String sensorRssiDbm(int rssi);

  /// No description provided for @sensorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth sensors are only available on iOS and Android.'**
  String get sensorUnsupported;

  /// No description provided for @altitudeAnnouncementTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice announcements'**
  String get altitudeAnnouncementTitle;

  /// No description provided for @altitudeAnnouncementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Takeoff/landing, glide dead zone and altitude record'**
  String get altitudeAnnouncementSubtitle;

  /// No description provided for @altitudeAnnouncementDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which flight events are spoken. Every announcement text can be customized and previewed.'**
  String get altitudeAnnouncementDescription;

  /// No description provided for @altitudeAnnouncementVoiceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Voice announcements'**
  String get altitudeAnnouncementVoiceEnabled;

  /// No description provided for @altitudeAnnouncementVoiceEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Turn all automatic voice announcements on or off.'**
  String get altitudeAnnouncementVoiceEnabledDescription;

  /// No description provided for @altitudeAnnouncementSectionVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get altitudeAnnouncementSectionVoice;

  /// No description provided for @altitudeAnnouncementSectionTakeoffLanding.
  ///
  /// In en, this message translates to:
  /// **'Takeoff & landing'**
  String get altitudeAnnouncementSectionTakeoffLanding;

  /// No description provided for @altitudeAnnouncementSectionGlide.
  ///
  /// In en, this message translates to:
  /// **'Glide dead zone'**
  String get altitudeAnnouncementSectionGlide;

  /// No description provided for @altitudeAnnouncementSectionRecord.
  ///
  /// In en, this message translates to:
  /// **'Altitude record'**
  String get altitudeAnnouncementSectionRecord;

  /// No description provided for @altitudeAnnouncementSectionCustomRules.
  ///
  /// In en, this message translates to:
  /// **'Data-triggered announcements'**
  String get altitudeAnnouncementSectionCustomRules;

  /// No description provided for @altitudeAnnouncementCustomRulesDescription.
  ///
  /// In en, this message translates to:
  /// **'During flight, speak custom text when a live value crosses a threshold or enters a range. Each rule can repeat at its own interval.'**
  String get altitudeAnnouncementCustomRulesDescription;

  /// No description provided for @altitudeAnnouncementCustomRuleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get altitudeAnnouncementCustomRuleAdd;

  /// No description provided for @altitudeAnnouncementCustomRuleLimit.
  ///
  /// In en, this message translates to:
  /// **'You can configure up to 20 conditions.'**
  String get altitudeAnnouncementCustomRuleLimit;

  /// No description provided for @altitudeAnnouncementCustomRuleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No custom conditions yet.'**
  String get altitudeAnnouncementCustomRuleEmpty;

  /// No description provided for @altitudeAnnouncementCustomRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcement condition'**
  String get altitudeAnnouncementCustomRuleTitle;

  /// No description provided for @altitudeAnnouncementCustomMetric.
  ///
  /// In en, this message translates to:
  /// **'Data value'**
  String get altitudeAnnouncementCustomMetric;

  /// No description provided for @altitudeAnnouncementCustomCondition.
  ///
  /// In en, this message translates to:
  /// **'Judgment'**
  String get altitudeAnnouncementCustomCondition;

  /// No description provided for @altitudeAnnouncementConditionGreater.
  ///
  /// In en, this message translates to:
  /// **'Greater than (>)'**
  String get altitudeAnnouncementConditionGreater;

  /// No description provided for @altitudeAnnouncementConditionLess.
  ///
  /// In en, this message translates to:
  /// **'Less than (<)'**
  String get altitudeAnnouncementConditionLess;

  /// No description provided for @altitudeAnnouncementConditionRange.
  ///
  /// In en, this message translates to:
  /// **'Within range'**
  String get altitudeAnnouncementConditionRange;

  /// No description provided for @altitudeAnnouncementCustomThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get altitudeAnnouncementCustomThreshold;

  /// No description provided for @altitudeAnnouncementCustomLower.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get altitudeAnnouncementCustomLower;

  /// No description provided for @altitudeAnnouncementCustomUpper.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get altitudeAnnouncementCustomUpper;

  /// No description provided for @altitudeAnnouncementCustomRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat while condition remains true'**
  String get altitudeAnnouncementCustomRepeat;

  /// No description provided for @altitudeAnnouncementCustomRepeatInterval.
  ///
  /// In en, this message translates to:
  /// **'Repeat every {seconds} s'**
  String altitudeAnnouncementCustomRepeatInterval(String seconds);

  /// No description provided for @altitudeAnnouncementCustomContent.
  ///
  /// In en, this message translates to:
  /// **'Spoken content template'**
  String get altitudeAnnouncementCustomContent;

  /// No description provided for @altitudeAnnouncementCustomContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the text to speak.'**
  String get altitudeAnnouncementCustomContentRequired;

  /// No description provided for @altitudeAnnouncementCustomTemplateDescription.
  ///
  /// In en, this message translates to:
  /// **'Type the announcement and add live flight values using the tokens below. The preview uses sample values.'**
  String get altitudeAnnouncementCustomTemplateDescription;

  /// No description provided for @altitudeAnnouncementCustomDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete condition'**
  String get altitudeAnnouncementCustomDelete;

  /// No description provided for @altitudeAnnouncementMetricAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get altitudeAnnouncementMetricAltitude;

  /// No description provided for @altitudeAnnouncementMetricVerticalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Vertical speed'**
  String get altitudeAnnouncementMetricVerticalSpeed;

  /// No description provided for @altitudeAnnouncementMetricGroundSpeed.
  ///
  /// In en, this message translates to:
  /// **'Ground speed'**
  String get altitudeAnnouncementMetricGroundSpeed;

  /// No description provided for @altitudeAnnouncementMetricWindSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind speed'**
  String get altitudeAnnouncementMetricWindSpeed;

  /// No description provided for @altitudeAnnouncementMetricTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get altitudeAnnouncementMetricTemperature;

  /// No description provided for @altitudeAnnouncementMetricPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get altitudeAnnouncementMetricPressure;

  /// No description provided for @altitudeAnnouncementMetricBattery.
  ///
  /// In en, this message translates to:
  /// **'Sensor battery'**
  String get altitudeAnnouncementMetricBattery;

  /// No description provided for @altitudeAnnouncementMetricHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get altitudeAnnouncementMetricHeartRate;

  /// No description provided for @altitudeAnnouncementMetricHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get altitudeAnnouncementMetricHeading;

  /// No description provided for @altitudeAnnouncementTakeoffLandingEnabled.
  ///
  /// In en, this message translates to:
  /// **'Takeoff & landing announcements'**
  String get altitudeAnnouncementTakeoffLandingEnabled;

  /// No description provided for @altitudeAnnouncementTakeoffLandingDescription.
  ///
  /// In en, this message translates to:
  /// **'Plays a notification ding, then speaks when a flight starts or ends. With automatic takeoff/landing detection on, a takeoff that merges into the previous flight record announces \"continue flight\" instead.'**
  String get altitudeAnnouncementTakeoffLandingDescription;

  /// No description provided for @altitudeAnnouncementAutoDetectOff.
  ///
  /// In en, this message translates to:
  /// **'Automatic takeoff/landing detection is off, so \"continue flight\" is never announced.'**
  String get altitudeAnnouncementAutoDetectOff;

  /// No description provided for @altitudeAnnouncementEventTakeoff.
  ///
  /// In en, this message translates to:
  /// **'Takeoff'**
  String get altitudeAnnouncementEventTakeoff;

  /// No description provided for @altitudeAnnouncementEventContinueFlight.
  ///
  /// In en, this message translates to:
  /// **'Continue flight'**
  String get altitudeAnnouncementEventContinueFlight;

  /// No description provided for @altitudeAnnouncementEventLanding.
  ///
  /// In en, this message translates to:
  /// **'Landing'**
  String get altitudeAnnouncementEventLanding;

  /// No description provided for @altitudeAnnouncementEventGlide.
  ///
  /// In en, this message translates to:
  /// **'Dead zone'**
  String get altitudeAnnouncementEventGlide;

  /// No description provided for @altitudeAnnouncementEventAltitudeRecord.
  ///
  /// In en, this message translates to:
  /// **'New altitude record'**
  String get altitudeAnnouncementEventAltitudeRecord;

  /// No description provided for @altitudeAnnouncementGlideEnabled.
  ///
  /// In en, this message translates to:
  /// **'Dead-zone announcement'**
  String get altitudeAnnouncementGlideEnabled;

  /// No description provided for @altitudeAnnouncementGlideDescription.
  ///
  /// In en, this message translates to:
  /// **'The vario stays silent while the vertical speed is in the dead zone. During a flight this speaks after the vertical speed has stayed in the zone for the set delay, then repeats at the set interval while it stays there.'**
  String get altitudeAnnouncementGlideDescription;

  /// No description provided for @altitudeAnnouncementGlideRange.
  ///
  /// In en, this message translates to:
  /// **'Dead zone: {minimum} to {maximum} m/s'**
  String altitudeAnnouncementGlideRange(String minimum, String maximum);

  /// No description provided for @altitudeAnnouncementGlideDelay.
  ///
  /// In en, this message translates to:
  /// **'Announce after {seconds} s in the zone'**
  String altitudeAnnouncementGlideDelay(String seconds);

  /// No description provided for @altitudeAnnouncementGlideRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat every {seconds} s while in the zone'**
  String altitudeAnnouncementGlideRepeat(String seconds);

  /// No description provided for @altitudeAnnouncementRecordEnabled.
  ///
  /// In en, this message translates to:
  /// **'New altitude record announcement'**
  String get altitudeAnnouncementRecordEnabled;

  /// No description provided for @altitudeAnnouncementRecordDescription.
  ///
  /// In en, this message translates to:
  /// **'During a flight this speaks immediately when the altitude exceeds the highest altitude recorded so far. While records keep being broken, announcements are spaced by at least the interval below.'**
  String get altitudeAnnouncementRecordDescription;

  /// No description provided for @altitudeAnnouncementRecordInterval.
  ///
  /// In en, this message translates to:
  /// **'Minimum interval between announcements: {seconds} s'**
  String altitudeAnnouncementRecordInterval(String seconds);

  /// No description provided for @altitudeAnnouncementRecordScopeFlight.
  ///
  /// In en, this message translates to:
  /// **'This flight'**
  String get altitudeAnnouncementRecordScopeFlight;

  /// No description provided for @altitudeAnnouncementRecordScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All flights'**
  String get altitudeAnnouncementRecordScopeAll;

  /// No description provided for @altitudeAnnouncementCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize text'**
  String get altitudeAnnouncementCustomize;

  /// No description provided for @altitudeAnnouncementPlaceholderAgl.
  ///
  /// In en, this message translates to:
  /// **'Height above ground'**
  String get altitudeAnnouncementPlaceholderAgl;

  /// No description provided for @altitudeAnnouncementPlaceholderTakeoffHeight.
  ///
  /// In en, this message translates to:
  /// **'Height above takeoff'**
  String get altitudeAnnouncementPlaceholderTakeoffHeight;

  /// No description provided for @altitudeAnnouncementPlaceholderMaxAltitude.
  ///
  /// In en, this message translates to:
  /// **'Max altitude'**
  String get altitudeAnnouncementPlaceholderMaxAltitude;

  /// No description provided for @altitudeAnnouncementPlaceholderGlideRatio.
  ///
  /// In en, this message translates to:
  /// **'Glide ratio'**
  String get altitudeAnnouncementPlaceholderGlideRatio;

  /// No description provided for @altitudeAnnouncementPlaceholderWindSpeed.
  ///
  /// In en, this message translates to:
  /// **'Wind speed'**
  String get altitudeAnnouncementPlaceholderWindSpeed;

  /// No description provided for @altitudeAnnouncementPlaceholderFlightTime.
  ///
  /// In en, this message translates to:
  /// **'Flight time'**
  String get altitudeAnnouncementPlaceholderFlightTime;

  /// No description provided for @altitudeAnnouncementPlaceholderDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance flown'**
  String get altitudeAnnouncementPlaceholderDistance;

  /// No description provided for @altitudeAnnouncementPlaceholderDistanceUnit.
  ///
  /// In en, this message translates to:
  /// **'Distance unit'**
  String get altitudeAnnouncementPlaceholderDistanceUnit;

  /// No description provided for @altitudeAnnouncementPlaceholderTime.
  ///
  /// In en, this message translates to:
  /// **'Clock time'**
  String get altitudeAnnouncementPlaceholderTime;

  /// No description provided for @altitudeAnnouncementTest.
  ///
  /// In en, this message translates to:
  /// **'Test announcement'**
  String get altitudeAnnouncementTest;

  /// No description provided for @altitudeAnnouncementTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Voice announcement is working.'**
  String get altitudeAnnouncementTestSuccess;

  /// No description provided for @altitudeAnnouncementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No text-to-speech voice is available. Install or enable a speech engine with an English or Chinese voice in the system settings, check the media volume, then test again.'**
  String get altitudeAnnouncementUnavailable;

  /// No description provided for @altitudeAnnouncementTemplate.
  ///
  /// In en, this message translates to:
  /// **'Announcement text'**
  String get altitudeAnnouncementTemplate;

  /// No description provided for @altitudeAnnouncementTemplateDescription.
  ///
  /// In en, this message translates to:
  /// **'Write what should be spoken and tap a value to insert it. Text containing Chinese is spoken with a Chinese voice, other text with an English voice. Leave empty to use the default.'**
  String get altitudeAnnouncementTemplateDescription;

  /// No description provided for @altitudeAnnouncementTemplateReset.
  ///
  /// In en, this message translates to:
  /// **'Restore default'**
  String get altitudeAnnouncementTemplateReset;

  /// No description provided for @altitudeAnnouncementTemplatePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview: {text}'**
  String altitudeAnnouncementTemplatePreview(String text);

  /// No description provided for @altitudeAnnouncementPlaceholderAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get altitudeAnnouncementPlaceholderAltitude;

  /// No description provided for @altitudeAnnouncementPlaceholderAltitudeUnit.
  ///
  /// In en, this message translates to:
  /// **'Altitude unit'**
  String get altitudeAnnouncementPlaceholderAltitudeUnit;

  /// No description provided for @altitudeAnnouncementPlaceholderClimb.
  ///
  /// In en, this message translates to:
  /// **'Climb rate'**
  String get altitudeAnnouncementPlaceholderClimb;

  /// No description provided for @altitudeAnnouncementPlaceholderClimbUnit.
  ///
  /// In en, this message translates to:
  /// **'Climb unit'**
  String get altitudeAnnouncementPlaceholderClimbUnit;

  /// No description provided for @altitudeAnnouncementPlaceholderGroundSpeed.
  ///
  /// In en, this message translates to:
  /// **'Ground speed'**
  String get altitudeAnnouncementPlaceholderGroundSpeed;

  /// No description provided for @altitudeAnnouncementPlaceholderSpeedUnit.
  ///
  /// In en, this message translates to:
  /// **'Speed unit'**
  String get altitudeAnnouncementPlaceholderSpeedUnit;

  /// No description provided for @altitudeAnnouncementDuckVario.
  ///
  /// In en, this message translates to:
  /// **'Lower vario sound while speaking'**
  String get altitudeAnnouncementDuckVario;

  /// No description provided for @altitudeAnnouncementSpeechRate.
  ///
  /// In en, this message translates to:
  /// **'Speaking speed: {rate}×'**
  String altitudeAnnouncementSpeechRate(String rate);

  /// No description provided for @altitudeAnnouncementSpeechRateNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get altitudeAnnouncementSpeechRateNormal;

  /// No description provided for @altitudeAnnouncementVolume.
  ///
  /// In en, this message translates to:
  /// **'Voice volume: {percent}%'**
  String altitudeAnnouncementVolume(String percent);

  /// No description provided for @altitudeAnnouncementDuckVarioDescription.
  ///
  /// In en, this message translates to:
  /// **'Turns the vario tone down during announcements so the voice can be heard over a loud vario.'**
  String get altitudeAnnouncementDuckVarioDescription;

  /// No description provided for @altitudeAnnouncementDuckLevel.
  ///
  /// In en, this message translates to:
  /// **'Vario volume while speaking: {percent}%'**
  String altitudeAnnouncementDuckLevel(String percent);

  /// No description provided for @varioSoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Vario Sound Settings'**
  String get varioSoundTitle;

  /// No description provided for @varioSoundResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get varioSoundResetTooltip;

  /// No description provided for @varioSoundSectionProfile.
  ///
  /// In en, this message translates to:
  /// **'Vario sound profile'**
  String get varioSoundSectionProfile;

  /// No description provided for @varioSoundProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Vario sound profile'**
  String get varioSoundProfileTitle;

  /// No description provided for @varioSoundProfileXcTrack.
  ///
  /// In en, this message translates to:
  /// **'XC Track'**
  String get varioSoundProfileXcTrack;

  /// No description provided for @varioSoundProfileCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get varioSoundProfileCustom;

  /// No description provided for @varioSoundProfileXcTrackDescription.
  ///
  /// In en, this message translates to:
  /// **'Stock XCTrack sound. Custom tuning is disabled.'**
  String get varioSoundProfileXcTrackDescription;

  /// No description provided for @varioSoundProfileCustomDescription.
  ///
  /// In en, this message translates to:
  /// **'Tune thresholds, pitch, waveform and keypoints yourself.'**
  String get varioSoundProfileCustomDescription;

  /// No description provided for @varioSoundPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview sound'**
  String get varioSoundPreview;

  /// No description provided for @varioSoundPreviewLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get varioSoundPreviewLive;

  /// No description provided for @varioSoundPreviewMuted.
  ///
  /// In en, this message translates to:
  /// **'MUTED'**
  String get varioSoundPreviewMuted;

  /// No description provided for @varioSoundVerticalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Vertical speed'**
  String get varioSoundVerticalSpeed;

  /// No description provided for @varioSoundKeypointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vertical speed keypoints'**
  String get varioSoundKeypointsTitle;

  /// No description provided for @varioSoundKeypointsDescription.
  ///
  /// In en, this message translates to:
  /// **'Pin a custom pitch, beep rate, duty and waveform to a vertical speed. The vario interpolates between keypoints and uses the default sound outside their range.'**
  String get varioSoundKeypointsDescription;

  /// No description provided for @varioSoundKeypointAddAt.
  ///
  /// In en, this message translates to:
  /// **'Add at {speed}'**
  String varioSoundKeypointAddAt(String speed);

  /// No description provided for @varioSoundKeypointClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get varioSoundKeypointClearAll;

  /// No description provided for @varioSoundKeypointsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No keypoints yet. Drag the vertical speed slider above and add one.'**
  String get varioSoundKeypointsEmpty;

  /// No description provided for @varioSoundKeypointsNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Add at least two keypoints to shape the sound.'**
  String get varioSoundKeypointsNeedTwo;

  /// No description provided for @varioSoundKeypointAudition.
  ///
  /// In en, this message translates to:
  /// **'Audition'**
  String get varioSoundKeypointAudition;

  /// No description provided for @varioSoundKeypointDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete keypoint'**
  String get varioSoundKeypointDelete;

  /// No description provided for @varioSoundKeypointPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get varioSoundKeypointPitch;

  /// No description provided for @varioSoundKeypointCycle.
  ///
  /// In en, this message translates to:
  /// **'Beep cycle'**
  String get varioSoundKeypointCycle;

  /// No description provided for @varioSoundKeypointDuty.
  ///
  /// In en, this message translates to:
  /// **'Duty'**
  String get varioSoundKeypointDuty;

  /// No description provided for @varioSoundKeypointContinuous.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get varioSoundKeypointContinuous;

  /// No description provided for @varioSoundKeypointWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get varioSoundKeypointWaveform;

  /// No description provided for @varioSoundSectionThresholds.
  ///
  /// In en, this message translates to:
  /// **'Thresholds'**
  String get varioSoundSectionThresholds;

  /// No description provided for @varioSoundLiftThreshold.
  ///
  /// In en, this message translates to:
  /// **'Lift threshold'**
  String get varioSoundLiftThreshold;

  /// No description provided for @varioSoundSinkThreshold.
  ///
  /// In en, this message translates to:
  /// **'Sink threshold'**
  String get varioSoundSinkThreshold;

  /// No description provided for @varioSoundSectionPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get varioSoundSectionPitch;

  /// No description provided for @varioSoundLiftBasePitch.
  ///
  /// In en, this message translates to:
  /// **'Lift base pitch'**
  String get varioSoundLiftBasePitch;

  /// No description provided for @varioSoundLiftPitchRange.
  ///
  /// In en, this message translates to:
  /// **'Lift pitch range'**
  String get varioSoundLiftPitchRange;

  /// No description provided for @varioSoundSinkBasePitch.
  ///
  /// In en, this message translates to:
  /// **'Sink base pitch'**
  String get varioSoundSinkBasePitch;

  /// No description provided for @varioSoundSectionWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get varioSoundSectionWaveform;

  /// No description provided for @varioSoundLiftWaveform.
  ///
  /// In en, this message translates to:
  /// **'Lift waveform'**
  String get varioSoundLiftWaveform;

  /// No description provided for @varioSoundSinkWaveform.
  ///
  /// In en, this message translates to:
  /// **'Sink waveform'**
  String get varioSoundSinkWaveform;

  /// No description provided for @varioSoundSectionOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get varioSoundSectionOutput;

  /// No description provided for @varioSoundVarioSound.
  ///
  /// In en, this message translates to:
  /// **'Vario sound'**
  String get varioSoundVarioSound;

  /// No description provided for @varioSoundVarioSoundDescription.
  ///
  /// In en, this message translates to:
  /// **'Master on/off for the vario beeper.'**
  String get varioSoundVarioSoundDescription;

  /// No description provided for @varioSoundVolume.
  ///
  /// In en, this message translates to:
  /// **'Vario volume'**
  String get varioSoundVolume;

  /// No description provided for @varioSoundMasterGain.
  ///
  /// In en, this message translates to:
  /// **'Master gain'**
  String get varioSoundMasterGain;

  /// No description provided for @varioSoundSectionBehavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get varioSoundSectionBehavior;

  /// No description provided for @varioSoundOnlyWhenFlying.
  ///
  /// In en, this message translates to:
  /// **'Sound only when flying'**
  String get varioSoundOnlyWhenFlying;

  /// No description provided for @varioSoundOnlyWhenFlyingDescription.
  ///
  /// In en, this message translates to:
  /// **'Stay silent until a flight is started, then beep normally.'**
  String get varioSoundOnlyWhenFlyingDescription;

  /// No description provided for @varioSoundOnlyWhenSensorConnected.
  ///
  /// In en, this message translates to:
  /// **'Sound only when sensor connected'**
  String get varioSoundOnlyWhenSensorConnected;

  /// No description provided for @varioSoundOnlyWhenSensorConnectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Stay silent unless a Bluetooth sensor is connected.'**
  String get varioSoundOnlyWhenSensorConnectedDescription;

  /// No description provided for @varioSoundSinkZoneCue.
  ///
  /// In en, this message translates to:
  /// **'Sink notification zone'**
  String get varioSoundSinkZoneCue;

  /// No description provided for @varioSoundSinkZoneCueDescription.
  ///
  /// In en, this message translates to:
  /// **'Play the deadband cue between the sink threshold ({sink} m/s) and 0.0 m/s instead of staying silent.'**
  String varioSoundSinkZoneCueDescription(String sink);

  /// No description provided for @varioWaveformTick.
  ///
  /// In en, this message translates to:
  /// **'Tick'**
  String get varioWaveformTick;

  /// No description provided for @varioWaveformTack.
  ///
  /// In en, this message translates to:
  /// **'Tack'**
  String get varioWaveformTack;

  /// No description provided for @varioWaveformSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get varioWaveformSquare;

  /// No description provided for @varioWaveformLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get varioWaveformLong;
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
