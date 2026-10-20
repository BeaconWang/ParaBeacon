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
  String get edit => 'Edit';

  @override
  String get refresh => 'Refresh';

  @override
  String get submit => 'Submit';

  @override
  String get preferences => 'Preferences';

  @override
  String get interfaceConfiguration => 'Dashboard layout';

  @override
  String get interfaceConfigurationImport => 'Import dashboard layout';

  @override
  String get interfaceConfigurationExport => 'Export dashboard layout';

  @override
  String get interfaceConfigurationImportTitle => 'Replace dashboard layout?';

  @override
  String get interfaceConfigurationImportConfirmation =>
      'This replaces all dashboard pages and controls with the imported layout. Theme, language, account settings and flight records are not changed.';

  @override
  String get interfaceConfigurationImported => 'Dashboard layout imported.';

  @override
  String get interfaceConfigurationImportFailed =>
      'Unable to import this dashboard layout. Check that the file is valid and compatible.';

  @override
  String get interfaceConfigurationExported =>
      'Dashboard layout is ready to share.';

  @override
  String get interfaceConfigurationExportFailed =>
      'Unable to export the dashboard layout.';

  @override
  String get units => 'Units';

  @override
  String get unitsSubtitle => 'Choose default units for dashboard controls';

  @override
  String get unitAltitude => 'Altitude';

  @override
  String get unitSpeed => 'Speed';

  @override
  String get unitVerticalSpeed => 'Vertical speed';

  @override
  String get unitDistance => 'Distance';

  @override
  String get unitPressure => 'Pressure';

  @override
  String get unitTemperature => 'Temperature';

  @override
  String get settingDisplayUnit => 'Display unit';

  @override
  String get settingUnitDefault => 'Use Preferences default';

  @override
  String get unitMeters => 'Meters (m)';

  @override
  String get unitFeet => 'Feet (ft)';

  @override
  String get unitKilometersPerHour => 'Kilometers per hour (km/h)';

  @override
  String get unitMetersPerSecond => 'Meters per second (m/s)';

  @override
  String get unitMilesPerHour => 'Miles per hour (mph)';

  @override
  String get unitKnots => 'Knots (kn)';

  @override
  String get unitFeetPerMinute => 'Feet per minute (ft/min)';

  @override
  String get unitAutomaticDistance => 'Automatic (m/km)';

  @override
  String get unitKilometers => 'Kilometers (km)';

  @override
  String get unitMiles => 'Miles (mi)';

  @override
  String get unitHectopascals => 'Hectopascals (hPa)';

  @override
  String get unitInchesOfMercury => 'Inches of mercury (inHg)';

  @override
  String get unitCelsius => 'Celsius (°C)';

  @override
  String get unitFahrenheit => 'Fahrenheit (°F)';

  @override
  String get accounts => 'Accounts';

  @override
  String get accountsSubtitle => 'Manage your ASFC and XContest accounts';

  @override
  String get aircraft => 'Aircraft';

  @override
  String get aircraftSubtitle =>
      'Configure aircraft type, model and flight performance';

  @override
  String get liveTracking => 'LiveTracking';

  @override
  String get liveTrackingSubtitle => 'Share your live flight with XContest';

  @override
  String get liveTrackingEnabled => 'Enable LiveTracking';

  @override
  String get liveTrackingEnabledSubtitle =>
      'Send your active flight to XContest';

  @override
  String get liveTrackingRequiresXContest =>
      'Sign in to XContest to enable LiveTracking.';

  @override
  String get liveTrackingClaimContest => 'Claim contest flight';

  @override
  String get liveTrackingClaimContestSubtitle =>
      'Claim the flight for an XContest competition';

  @override
  String get liveTrackingShowPublic => 'Show public tracking';

  @override
  String get liveTrackingShowPublicSubtitle =>
      'Allow your live position to be visible publicly';

  @override
  String get liveTrackingFlightPublic => 'Make flight public';

  @override
  String get liveTrackingFlightPublicSubtitle =>
      'Publish the completed flight on XContest';

  @override
  String get liveTrackingTemporaryDisable => 'Temporarily stop sharing';

  @override
  String get liveTrackingTemporaryDisableSubtitle =>
      'Pause LiveTracking without changing the main setting';

  @override
  String get liveTrackingTemporarilyDisabled =>
      'LiveTracking is temporarily paused.';

  @override
  String get liveTrackingReady => 'LiveTracking is configured and ready.';

  @override
  String get aircraftFaiClass => 'FAI class';

  @override
  String get aircraftFaiParaglider => 'Paraglider';

  @override
  String get aircraftFaiHangGlider => 'Hang glider';

  @override
  String get aircraftFaiRigidWing => 'Rigid wing';

  @override
  String get aircraftFaiPoweredParagliderFoot =>
      'Powered paraglider (foot launch)';

  @override
  String get aircraftFaiPoweredParagliderTrike => 'Powered paraglider (trike)';

  @override
  String get aircraftFaiPoweredAircraft => 'Powered aircraft';

  @override
  String get aircraftFaiRigidWingPowered => 'Rigid wing (powered)';

  @override
  String get aircraftFaiRigidGlider => 'Rigid glider';

  @override
  String get aircraftCategoryStandard => 'Standard';

  @override
  String get aircraftCategoryPerformance => 'Performance';

  @override
  String get aircraftCategoryCompetition => 'Competition';

  @override
  String get aircraftCategoryFlexWing => 'Flex wing';

  @override
  String get aircraftCategoryRigidWing => 'Rigid wing';

  @override
  String get aircraftCategoryClass1 => 'Class 1';

  @override
  String get aircraftCategoryClass5 => 'Class 5';

  @override
  String get aircraftManufacturer => 'Manufacturer';

  @override
  String get aircraftSelectManufacturer => 'Select a manufacturer';

  @override
  String get aircraftModel => 'Model';

  @override
  String get aircraftSelectModel => 'Select a model';

  @override
  String get aircraftName => 'Aircraft name';

  @override
  String get aircraftParagliderCategory => 'Paraglider category';

  @override
  String get aircraftHangGliderCategory => 'Hang glider category';

  @override
  String get aircraftTandem => 'Tandem / biplace';

  @override
  String get aircraftTandemSubtitle => 'This aircraft carries two people';

  @override
  String get aircraftEngineType => 'Engine type';

  @override
  String get aircraftEngineNone => 'None';

  @override
  String get aircraftEngineElectric => 'Electric';

  @override
  String get aircraftEngineInternalCombustion => 'Internal combustion';

  @override
  String get aircraftTrimSpeed => 'Trim speed (km/h)';

  @override
  String get aircraftGoalGlideRatio => 'Goal glide ratio';

  @override
  String get aircraftPositiveNumberRequired => 'Enter a positive number.';

  @override
  String get aircraftSave => 'Save aircraft';

  @override
  String get flightDetailAircraft => 'Aircraft';

  @override
  String get flightDetailAircraftEdit => 'Edit Aircraft';

  @override
  String get flightDetailAircraftClass => 'FAI class';

  @override
  String get flightDetailAircraftManufacturer => 'Manufacturer';

  @override
  String get flightDetailAircraftModel => 'Model';

  @override
  String get flightDetailAircraftName => 'Aircraft name';

  @override
  String get flightDetailAircraftCategory => 'Category';

  @override
  String get flightDetailAircraftTandem => 'Tandem';

  @override
  String get flightDetailAircraftEngine => 'Engine';

  @override
  String get flightDetailAircraftTrimSpeed => 'Trim speed';

  @override
  String get flightDetailAircraftGlideRatio => 'Goal glide ratio';

  @override
  String get aircraftTandemYes => 'Yes';

  @override
  String get aircraftTandemNo => 'No';

  @override
  String get notSet => 'Not set';

  @override
  String get saving => 'Saving…';

  @override
  String get asfcAccount => 'ASFC account';

  @override
  String get asfcAccountSubtitle => 'Sign in with your ASFC / GoFly account';

  @override
  String get xcontestAccount => 'XContest account';

  @override
  String get xcontestAccountSubtitle => 'Sign in with your XContest account';

  @override
  String get xcontestUsername => 'Username';

  @override
  String get xcontestPassword => 'Password';

  @override
  String get xcontestUserId => 'User ID';

  @override
  String get xcontestFullName => 'Full name';

  @override
  String get xcontestProfileInformation => 'Account information';

  @override
  String get xcontestSignedIn => 'Signed in to XContest';

  @override
  String get xcontestCredentialsRequired =>
      'Enter your XContest username and password.';

  @override
  String get xcontestInvalidCredentials =>
      'The XContest username or password is incorrect.';

  @override
  String get xcontestConnectionFailed =>
      'Unable to connect to XContest. Check your network and try again.';

  @override
  String get xcontestLoginFailed => 'XContest login failed. Try again.';

  @override
  String get asfcUsername => 'Username or mobile';

  @override
  String get asfcPassword => 'Password';

  @override
  String get asfcPasswordLogin => 'Password';

  @override
  String get asfcSmsLogin => 'SMS code';

  @override
  String get asfcMobile => 'Mobile number';

  @override
  String get asfcSmsCode => 'SMS code';

  @override
  String get asfcCaptcha => 'Image code';

  @override
  String get asfcRefreshCaptcha => 'Refresh image code';

  @override
  String get asfcSendSmsCode => 'Send code';

  @override
  String asfcSmsCountdown(int seconds) {
    return 'Retry ${seconds}s';
  }

  @override
  String get asfcMobileRequired => 'Enter your mobile number.';

  @override
  String get asfcCaptchaRequired => 'Enter the image code.';

  @override
  String get asfcSmsCodeRequired => 'Enter the SMS code.';

  @override
  String get asfcSmsCredentialsRequired =>
      'Enter your mobile number and SMS code.';

  @override
  String get asfcCaptchaLoadFailed => 'Unable to load the image code.';

  @override
  String get asfcSmsCodeSendFailed => 'Unable to send the SMS code.';

  @override
  String get login => 'Log in';

  @override
  String get loggingIn => 'Logging in…';

  @override
  String get logout => 'Log out';

  @override
  String get asfcSignedIn => 'Signed in';

  @override
  String get asfcProfileInformation => 'Account information';

  @override
  String get asfcRefreshProfile => 'Refresh account information';

  @override
  String get asfcProfileLoadFailed => 'Unable to load account information.';

  @override
  String get asfcNoProfileInformation => 'No account information is available.';

  @override
  String get asfcInformationAvailable => 'Available';

  @override
  String get applyForCertificate => 'Apply for certificate';

  @override
  String get certificateDetails => 'Certificate details';

  @override
  String get certificateDetailsView => 'Details';

  @override
  String get certificateCardView => 'Card';

  @override
  String get certificateSwipeHint => 'Swipe left or right to switch views';

  @override
  String get certificateCardTitle => 'Aviation Sports Pilot Certificate';

  @override
  String get certificateIssued => 'Issued';

  @override
  String get certificatePendingApproval => 'Pending approval';

  @override
  String get certificatePendingApprovalSubtitle =>
      'Your certificate application is being reviewed.';

  @override
  String get certificateNumber => 'Certificate number';

  @override
  String get certificateLevel => 'Level';

  @override
  String get certificateSportCode => 'Sport code';

  @override
  String get certificateValidityStatus => 'Validity status';

  @override
  String get certificateValidity => 'Validity period';

  @override
  String get certificateIssueDate => 'Issue date';

  @override
  String get certificatePhoto => 'Photo';

  @override
  String get certificateUpgrade => 'License upgrade';

  @override
  String get certificateSignInList => 'Sign-in list';

  @override
  String get certificateSignInDate => 'Sign-in date';

  @override
  String get certificateReviewUnit => 'Reviewer';

  @override
  String get certificateNoSignIns => 'No sign-in records';

  @override
  String get asfcFlightRecords => 'ASFC flight records';

  @override
  String get asfcFlightSubmit => 'Submit flight record';

  @override
  String get asfcFlightEdit => 'Edit flight record';

  @override
  String get asfcFlightDetails => 'Flight record details';

  @override
  String get asfcFlightNoRecords => 'No ASFC flight records';

  @override
  String get asfcFlightDate => 'Training date';

  @override
  String get asfcFlightAddress => 'Location';

  @override
  String get asfcFlightModel => 'Aircraft model';

  @override
  String get asfcFlightTask => 'Flight task';

  @override
  String get asfcFlightStartTime => 'Start time';

  @override
  String get asfcFlightEndTime => 'End time';

  @override
  String get asfcFlightTime => 'Flight time';

  @override
  String get asfcFlightSeatType => 'Seat type';

  @override
  String get asfcFlightFrontSeat => 'Front seat';

  @override
  String get asfcFlightBackSeat => 'Back seat';

  @override
  String get asfcFlightTakeoffMode => 'Takeoff mode';

  @override
  String get asfcFlightSortie => 'Sorties';

  @override
  String get asfcFlightAgency => 'Training agency';

  @override
  String get asfcFlightCoach => 'Coach';

  @override
  String get asfcFlightSignin => 'Coach sign-in note';

  @override
  String get asfcFlightSelectAgency => 'Select an agency';

  @override
  String get asfcFlightSelectCoach => 'Select a coach';

  @override
  String get asfcFlightLoading => 'Loading…';

  @override
  String get asfcFlightRequired => 'This field is required.';

  @override
  String get asfcFlightSelectionRequired =>
      'Select an agency, coach and takeoff mode.';

  @override
  String get asfcFlightSaveFailed => 'Unable to save the flight record.';

  @override
  String get asfcFlightDeleted => 'Flight record deleted.';

  @override
  String get asfcFlightDeleteFailed => 'Unable to delete the flight record.';

  @override
  String get asfcFlightDeleteTitle => 'Delete flight record?';

  @override
  String get asfcFlightDeleteConfirmation =>
      'This flight record will be permanently deleted.';

  @override
  String get certificateApplication => 'ASFC certificate application';

  @override
  String get certificateApplicationSubtitle =>
      'Submit a paragliding license application through your ASFC account.';

  @override
  String get certificateFullName => 'Full name';

  @override
  String get certificateGender => 'Gender';

  @override
  String get certificateMale => 'Male';

  @override
  String get certificateFemale => 'Female';

  @override
  String get certificateBirthday => 'Date of birth';

  @override
  String get certificateCountry => 'Nationality';

  @override
  String get certificateEthnicity => 'Ethnicity';

  @override
  String get certificateIdNumber => 'ID card number';

  @override
  String get certificateMobile => 'Mobile number';

  @override
  String get certificateEmail => 'Email';

  @override
  String get certificateAddress => 'Address';

  @override
  String get certificateArea => 'Permanent residence';

  @override
  String get certificateAgency => 'Training agency';

  @override
  String get certificateCoachId => 'Coach ID (optional)';

  @override
  String get certificateCoach => 'Coach';

  @override
  String get certificateCoachSelect => 'Select a coach (optional)';

  @override
  String get certificateCoachesLoading => 'Loading coaches…';

  @override
  String get certificateDocuments => 'Documents';

  @override
  String get licensePhoto => 'Upload license photo';

  @override
  String get groupPhoto => 'Upload training group photo';

  @override
  String get licensePhotoUploaded => 'License photo uploaded';

  @override
  String get groupPhotoUploaded => 'Group photo uploaded';

  @override
  String get certificateEmergencyContact => 'Emergency contact';

  @override
  String get certificateContactName => 'Contact name';

  @override
  String get certificateContactPhone => 'Contact phone';

  @override
  String get certificateBloodType => 'Blood type';

  @override
  String get certificateRequired => 'This field is required.';

  @override
  String get certificatePhotoRequired =>
      'Upload both certificate photos before submitting.';

  @override
  String get certificateNotSignedIn => 'Sign in to your ASFC account first.';

  @override
  String get certificateImageInvalid => 'Choose an image smaller than 10 MB.';

  @override
  String get certificateImageUploadFailed => 'Unable to upload the image.';

  @override
  String get certificateApplicationFailed =>
      'The certificate application failed.';

  @override
  String get certificateApplicationSuccess =>
      'Certificate application submitted.';

  @override
  String get submitApplication => 'Submit application';

  @override
  String get submitting => 'Submitting…';

  @override
  String get asfcLoginFailed => 'Login failed. Check your account details.';

  @override
  String asfcLoginFailedWithReason(String reason) {
    return 'Login failed: $reason';
  }

  @override
  String get asfcConnectionFailed =>
      'Unable to connect. Check your network and try again.';

  @override
  String get asfcCredentialsRequired => 'Enter your username and password.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

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
  String get bluetoothSensor => 'Sensor';

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
  String get autoDeleteShortFlights => 'Automatically delete short flights';

  @override
  String get autoDeleteShortFlightsSubtitle =>
      'Remove completed flight records shorter than the selected duration';

  @override
  String get shortFlightThreshold => 'Minimum duration to keep';

  @override
  String get shortFlightThreshold30Seconds => '30 seconds';

  @override
  String get shortFlightThreshold1Minute => '1 minute';

  @override
  String get shortFlightThreshold2Minutes => '2 minutes';

  @override
  String get shortFlightThreshold5Minutes => '5 minutes';

  @override
  String get deleteExistingShortFlightsTitle => 'Delete short flights?';

  @override
  String deleteExistingShortFlightsMessage(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count existing flight records are',
      one: '1 existing flight record is',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them',
      one: 'it',
    );
    return '$_temp0 shorter than $duration. Delete $_temp1 now? This cannot be undone.';
  }

  @override
  String get keep => 'Keep';

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
  String get weatherFavoriteRename => 'Rename';

  @override
  String get weatherFavoriteName => 'Name';

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
  String get controlClimbAverage => 'Climb Average';

  @override
  String get controlTakeoffWaypoint => 'Takeoff Waypoint';

  @override
  String get takeoffPointLabel => 'HOME';

  @override
  String get takeoffDistanceLabel => 'DIST';

  @override
  String get takeoffAltitudeDifferenceLabel => 'ALT DIFF';

  @override
  String get climbAverageLabel => 'CLIMB AVG';

  @override
  String get peakLabel => 'PEAK';

  @override
  String get controlVerticalGraph => 'Vertical Graph';

  @override
  String get controlAltitude => 'Altitude';

  @override
  String get controlGpsAltitude => 'GPS Altitude';

  @override
  String get controlBaroAltitude => 'Baro Altitude';

  @override
  String get controlAltitudeAboveTakeoff => 'Altitude Above Takeoff';

  @override
  String get controlMaxAltitude => 'Max Altitude';

  @override
  String get controlThermalGain => 'Thermal Gain';

  @override
  String get controlLastThermalGain => 'Last Thermal Gain';

  @override
  String get controlVerticalSpeed => 'Vertical Speed';

  @override
  String get controlGroundSpeed => 'Ground Speed';

  @override
  String get controlGlide => 'Glide';

  @override
  String get controlHeading => 'Heading';

  @override
  String get controlBearing => 'Bearing';

  @override
  String get controlGpsAccuracy => 'GPS Accuracy';

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
  String get controlPhoneBattery => 'Phone Battery';

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
  String get controlWindDir => 'Wind Dir';

  @override
  String get locationNoFix => 'No GPS fix';

  @override
  String get mapNoBasemap => 'No basemap';

  @override
  String mapOffline(String filename) {
    return 'Offline · $filename';
  }

  @override
  String get mapOfflineNoFilename => 'Offline';

  @override
  String get mapRecenterTooltip => 'Re-center';

  @override
  String get mapZoomInTooltip => 'Zoom in';

  @override
  String get mapZoomOutTooltip => 'Zoom out';

  @override
  String get mapHeading => 'HDG';

  @override
  String get mapAltitude => 'ALT';

  @override
  String get mapRequiredGlideRatio => 'L/D REQ';

  @override
  String get varioLegendSink => 'SINK';

  @override
  String get varioLegendNeutral => 'NEUTRAL';

  @override
  String get varioLegendLift => 'LIFT';

  @override
  String get gpsNotificationTitle => 'ParaBeacon — recording flight';

  @override
  String get gpsNotificationText =>
      'Logging your track with the screen off. Tap to return.';

  @override
  String get gpsNotificationChannel => 'Flight recording';

  @override
  String get debugSensorTitle => 'Debug Sensor';

  @override
  String get debugSensorReset => 'RESET';

  @override
  String get debugSensorVerticalSpeed => 'Vertical speed';

  @override
  String get debugSensorAltitude => 'Altitude';

  @override
  String get debugSensorGroundSpeed => 'Ground speed';

  @override
  String get debugSensorHeading => 'Heading';

  @override
  String get debugSensorWindSpeed => 'Wind speed';

  @override
  String get debugSensorWindDirection => 'Wind direction';

  @override
  String get flightButtonStart => 'START';

  @override
  String get flightButtonStop => 'STOP';

  @override
  String get flightButtonAuto => 'AUTO';

  @override
  String get flightButtonAutoTooltip =>
      'Tap to toggle auto-detection; long-press for settings';

  @override
  String get flightAutoSettingsTitle => 'Auto take-off / landing';

  @override
  String get flightAutoTakeoffSpeed => 'Take-off speed threshold';

  @override
  String get flightLandingAutomatic => 'Automatic landing';

  @override
  String get flightLandingAutomaticDescription =>
      'End the flight automatically when landing is detected';

  @override
  String get flightLandingManual => 'Manual confirmation';

  @override
  String get flightLandingManualDescription =>
      'Ask before ending the flight after landing is detected';

  @override
  String get flightLandingNoDetection => 'Do not detect landing';

  @override
  String get flightLandingNoDetectionDescription =>
      'Take-off detection stays on; stop the flight manually';

  @override
  String get flightLandingDetectedTitle => 'Landing detected';

  @override
  String get flightLandingDetectedBody =>
      'Confirm landing and finish this flight recording?';

  @override
  String get flightLandingConfirm => 'Just landed';

  @override
  String get flightLandingStillFlying => 'Still flying';

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
  String get settingShowVerticalAcceleration => 'Show vertical acceleration';

  @override
  String get settingVerticalAccelerationFillOpacity =>
      'Acceleration fill opacity';

  @override
  String get settingVerticalGraphInterval => 'Shown interval';

  @override
  String get settingVerticalGraphStep => 'Vertical step';

  @override
  String get settingVerticalGraphDotSize => 'Dot size';

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
  String get dataMonitorMinimize => 'Minimize data monitor';

  @override
  String get dataMonitorRestore => 'Restore data monitor';

  @override
  String get dataMonitorResize => 'Resize data monitor';

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
  String get flightsImport => 'Import flights';

  @override
  String get flightsImportLibrary => 'Import library (.pbflights)';

  @override
  String get flightsImportXcTrack => 'Import XCTrack flights (.igc)';

  @override
  String get flightsImportFileUnreadable => 'Unable to read the selected file.';

  @override
  String get flightsExportDestinationTitle => 'Where should the export go?';

  @override
  String get flightsExportDestinationDownloads => 'Save to Downloads';

  @override
  String get flightsExportDestinationShare => 'Share directly';

  @override
  String get flightsExportSavedToDownloads =>
      'Export saved to Downloads/ParaBeacon.';

  @override
  String get flightsImportXcTrackPickMode =>
      'How do you want to select the tracklogs?';

  @override
  String get flightsImportModeFolder => 'Select a folder';

  @override
  String get flightsImportModeFolderNote =>
      'Import every .igc in a folder — no file limit';

  @override
  String get flightsImportModeFiles => 'Select files';

  @override
  String get flightsImportModeFilesNote =>
      'Pick individual .igc files (up to 100)';

  @override
  String get flightsImportXcTrackNote =>
      'XCTrack stores tracklogs at:\n/storage/emulated/0/Android/data/org.xcontest.XCTrack/files/Tracklogs\n\nThat folder can\'t be opened directly on most phones. Copy it (or its .igc files) to Download first, then import from there.';

  @override
  String get flightsImportingXcTrack => 'Importing XCTrack flights…';

  @override
  String get flightsImportNoIgc => 'No .igc files were found in that folder.';

  @override
  String get flightsExportLibrary => 'Export library (.pbflights)';

  @override
  String get flightsSelectRecords => 'Select flights to export';

  @override
  String get flightsExportSelected => 'Export selected flights (.pbflights)';

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
  String get flightsLibraryExportSaved => 'Flight bundle saved on the device.';

  @override
  String get flightsExportDoneTitle => 'Export complete';

  @override
  String get flightsExportDoneSaved =>
      'The flight bundle was saved to your device.';

  @override
  String get flightsExportDoneShared => 'The flight bundle is ready to share.';

  @override
  String get flightsExportDetailFlights => 'Flights';

  @override
  String get flightsExportDetailFileName => 'File';

  @override
  String get flightsExportDetailSize => 'Size';

  @override
  String get flightsExportDetailLocation => 'Location';

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
  String get flightDetailTrimLog => 'Trim flight log';

  @override
  String get flightDetailTrimDescription =>
      'Choose the first and last samples to keep. Keep at least two points; removed samples cannot be restored.';

  @override
  String flightDetailTrimFrom(String time) {
    return 'Keep from $time';
  }

  @override
  String flightDetailTrimThrough(String time) {
    return 'Keep through $time';
  }

  @override
  String flightDetailTrimCounts(int kept, int removed) {
    return 'Keep $kept samples · remove $removed';
  }

  @override
  String get flightDetailTrimApply => 'Trim';

  @override
  String get flightDetailTrimApplied => 'Flight log trimmed.';

  @override
  String get replayTrimUnavailable =>
      'This flight log changed or is no longer available. Close and reopen replay before trimming.';

  @override
  String get flightDetailFlight => 'Flight';

  @override
  String get flightDetailRoute => 'Route';

  @override
  String get flightDetailAltitude => 'Altitude';

  @override
  String get flightDetailRouteMetrics => 'Route metrics';

  @override
  String get flightDetailSpeedGlide => 'Speed & glide';

  @override
  String get flightDetailClimbAltitude => 'Climb & altitude';

  @override
  String get flightDetailTimeBreakdown => 'Time breakdown';

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
  String get flightDetailPilot => 'Pilot';

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
  String get flightDetailFlatTriangle => 'Flat triangle';

  @override
  String get flightDetailThreeTurnpoints => '3-turnpoint distance';

  @override
  String get flightDetailClosing => 'closing';

  @override
  String get flightDetailMaxAltGain => 'Max. alt. gain';

  @override
  String get flightDetailElevationDrop => 'Elevation drop';

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
  String get flightShareCardNoTrack => 'No track';

  @override
  String get flightShareCardNoAltitude => 'No altitude data';

  @override
  String flightShareCardFooter(int points) {
    return 'Recorded with ParaBeacon · $points points';
  }

  @override
  String get flightReportTitle => 'ParaBeacon Flight Report';

  @override
  String get flightReportDate => 'Date';

  @override
  String get flightReportTrackMap => 'Track';

  @override
  String get flightReportAltitudeProfile => 'Altitude profile';

  @override
  String get flightReportSummary => 'Summary';

  @override
  String get flightReportDistanceAltitude => 'Distance & altitude';

  @override
  String get flightReportGeneratedBy => 'Generated by ParaBeacon';

  @override
  String flightReportPage(int current, int total) {
    return 'Page $current / $total';
  }

  @override
  String get flightsStatistics => 'Statistics';

  @override
  String get flightsStatisticsAll => 'Statistics (all flights)';

  @override
  String get flightsStatisticsSelected => 'Statistics (selected flights)';

  @override
  String get statsTitle => 'Flight statistics';

  @override
  String statsScopeAll(int count) {
    return 'All flights · $count';
  }

  @override
  String statsScopeSelected(int count) {
    return 'Selected · $count';
  }

  @override
  String get statsNoData => 'No flights to analyze';

  @override
  String get statsNoDataHint => 'Record or select flights to see statistics.';

  @override
  String get statsPrioritySummary => 'Summary first';

  @override
  String get statsPriorityDetailed => 'Detailed stats';

  @override
  String statsComputingDetailed(int completed, int total) {
    return 'Calculating detailed stats · $completed / $total flights';
  }

  @override
  String get statsNoDetailedTracks =>
      'No recorded track details are available.';

  @override
  String get statsCalculationFailed =>
      'Detailed statistics could not be calculated. Your summary is still available.';

  @override
  String get statsNotEnoughData => 'Not enough data';

  @override
  String statsRecordOn(String date) {
    return 'on $date';
  }

  @override
  String statsFlightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flights',
      one: '1 flight',
      zero: 'No flights',
    );
    return '$_temp0';
  }

  @override
  String get statsSectionOverview => 'Overview';

  @override
  String get statsSectionRecords => 'Personal records';

  @override
  String get statsSectionAverages => 'Averages';

  @override
  String get statsSectionTotals => 'Totals';

  @override
  String get statsSectionByYear => 'Flights by year';

  @override
  String get statsSectionByMonth => 'Seasonality (by month)';

  @override
  String get statsSectionByAircraft => 'By glider / aircraft';

  @override
  String get statsSectionBySite => 'By takeoff site';

  @override
  String get statsFlights => 'Flights';

  @override
  String get statsTotalAirtime => 'Total airtime';

  @override
  String get statsTotalDistance => 'Total distance';

  @override
  String get statsTotalXcDistance => 'Total XC distance';

  @override
  String get statsDateRange => 'Date range';

  @override
  String get statsActiveDays => 'Active days';

  @override
  String get statsFlightsPerDay => 'Flights / active day';

  @override
  String get statsFirstFlight => 'First flight';

  @override
  String get statsLastFlight => 'Last flight';

  @override
  String get statsSampledFlights => 'Flights with track data';

  @override
  String get statsLongestFlight => 'Longest flight';

  @override
  String get statsLongestDistance => 'Longest track distance';

  @override
  String get statsLongestXc => 'Longest straight distance';

  @override
  String get statsMaxDistanceFromStart => 'Farthest from launch';

  @override
  String get statsHighestAltitude => 'Highest altitude';

  @override
  String get statsLowestAltitude => 'Lowest altitude';

  @override
  String get statsMaxClimb => 'Strongest climb';

  @override
  String get statsMaxSink => 'Strongest sink';

  @override
  String get statsMaxSpeed => 'Top speed';

  @override
  String get statsBestGlide => 'Best glide ratio';

  @override
  String get statsBestFaiTriangle => 'Best FAI triangle';

  @override
  String get statsAvgDuration => 'Avg flight time';

  @override
  String get statsAvgDistance => 'Avg track distance';

  @override
  String get statsAvgXcDistance => 'Avg straight distance';

  @override
  String get statsAvgMaxAltitude => 'Avg max altitude';

  @override
  String get statsAvgSpeed => 'Avg ground speed';

  @override
  String get statsAvgGlide => 'Avg glide ratio';

  @override
  String get statsTotalAltGained => 'Total altitude gained';

  @override
  String get statsTotalAltLost => 'Total altitude lost';

  @override
  String get statsTotalThermals => 'Thermals climbed';

  @override
  String get statsTotalMovingTime => 'Total moving time';

  @override
  String get statsTotalSamples => 'Track points';

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
  String get flightsDeleteTitle => 'Delete flight?';

  @override
  String get flightsDeleteMessage =>
      'This flight record will be permanently deleted. This cannot be undone.';

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

  @override
  String get sensorTitle => 'Sensor';

  @override
  String get sensorOptions => 'Options';

  @override
  String get sensorEnableBluetooth => 'Enable Bluetooth sensor';

  @override
  String get sensorEnableBluetoothSubtitle =>
      'Scan and connect to external sensors';

  @override
  String get sensorPreferInternal => 'Prefer internal sensor';

  @override
  String get sensorPreferInternalSubtitle =>
      'Use this device’s built-in barometer first';

  @override
  String get sensorNoInternalBarometer =>
      'No built-in barometer detected on this device';

  @override
  String get sensorInternalSection => 'Internal sensor';

  @override
  String get sensorStatus => 'Status';

  @override
  String get sensorBarometerNotDetected => 'No barometer detected';

  @override
  String get sensorBarometerConnected => 'Barometer connected';

  @override
  String get sensorBarometerNotPreferred =>
      'Barometer detected (not preferred)';

  @override
  String get sensorConnection => 'Connection';

  @override
  String sensorBluetoothState(String state) {
    return 'Bluetooth: $state';
  }

  @override
  String get sensorLiveDataFields => 'Live data fields';

  @override
  String get sensorNearbyDevices => 'Nearby devices';

  @override
  String get sensorFieldAltitude => 'Altitude';

  @override
  String get sensorFieldVerticalSpeed => 'Vertical speed';

  @override
  String get sensorFieldPressure => 'Pressure';

  @override
  String get sensorFieldTemperature => 'Temperature';

  @override
  String get sensorFieldHeartRate => 'Heart rate';

  @override
  String get sensorFieldBattery => 'Battery';

  @override
  String get sensorNoDeviceSelected => 'No device selected';

  @override
  String get sensorDevice => 'Device';

  @override
  String get sensorConnected => 'Connected';

  @override
  String get sensorConnecting => 'Connecting…';

  @override
  String get sensorDisconnected => 'Disconnected';

  @override
  String get sensorConnect => 'Connect';

  @override
  String get sensorDisconnect => 'Disconnect';

  @override
  String get sensorForget => 'Forget';

  @override
  String get sensorScan => 'Scan';

  @override
  String get sensorStop => 'Stop';

  @override
  String get sensorDevices => 'Devices';

  @override
  String get sensorTapScan => 'Tap Scan';

  @override
  String get sensorEnableFirst => 'Enable first';

  @override
  String get sensorUnknownDevice => '(unknown)';

  @override
  String sensorRssiDbm(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get sensorUnsupported =>
      'Bluetooth sensors are only available on iOS and Android.';

  @override
  String get altitudeAnnouncementTitle => 'Altitude voice announcements';

  @override
  String get altitudeAnnouncementSubtitle =>
      'Speak the current altitude when climb rate enters a chosen range';

  @override
  String get altitudeAnnouncementDescription =>
      'Announces once after climb rate remains in the selected range briefly. It rearms after climb rate stays below the range.';

  @override
  String get altitudeAnnouncementEnabled => 'Voice announcements';

  @override
  String get altitudeAnnouncementEnabledDescription =>
      'Speak altitude when lift enters the selected range';

  @override
  String get altitudeAnnouncementLiftRange => 'Lift-speed range (m/s)';

  @override
  String altitudeAnnouncementRangeDescription(String minimum, String maximum) {
    return 'Announce between $minimum and $maximum m/s';
  }

  @override
  String get altitudeAnnouncementTest => 'Test announcement';

  @override
  String get altitudeAnnouncementTestSuccess =>
      'Voice announcement is working.';

  @override
  String get altitudeAnnouncementUnavailable =>
      'No text-to-speech voice is available. Install or enable a speech engine with an English or Chinese voice in the system settings, check the media volume, then test again.';

  @override
  String get altitudeAnnouncementTemplate => 'Announcement text';

  @override
  String get altitudeAnnouncementTemplateDescription =>
      'Write what should be spoken and tap a value to insert it. Text containing Chinese is spoken with a Chinese voice, other text with an English voice. Leave empty to use the default.';

  @override
  String get altitudeAnnouncementTemplateReset => 'Restore default';

  @override
  String altitudeAnnouncementTemplatePreview(String text) {
    return 'Preview: $text';
  }

  @override
  String get altitudeAnnouncementPlaceholderAltitude => 'Altitude';

  @override
  String get altitudeAnnouncementPlaceholderAltitudeUnit => 'Altitude unit';

  @override
  String get altitudeAnnouncementPlaceholderClimb => 'Climb rate';

  @override
  String get altitudeAnnouncementPlaceholderClimbUnit => 'Climb unit';

  @override
  String get altitudeAnnouncementPlaceholderGroundSpeed => 'Ground speed';

  @override
  String get altitudeAnnouncementPlaceholderSpeedUnit => 'Speed unit';

  @override
  String get varioSoundTitle => 'Vario Sound Settings';

  @override
  String get varioSoundResetTooltip => 'Reset to defaults';

  @override
  String get varioSoundSectionProfile => 'Vario sound profile';

  @override
  String get varioSoundProfileTitle => 'Vario sound profile';

  @override
  String get varioSoundProfileXcTrack => 'XC Track';

  @override
  String get varioSoundProfileCustom => 'Custom';

  @override
  String get varioSoundProfileXcTrackDescription =>
      'Stock XCTrack sound. Custom tuning is disabled.';

  @override
  String get varioSoundProfileCustomDescription =>
      'Tune thresholds, pitch, waveform and keypoints yourself.';

  @override
  String get varioSoundPreview => 'Preview sound';

  @override
  String get varioSoundPreviewLive => 'LIVE';

  @override
  String get varioSoundPreviewMuted => 'MUTED';

  @override
  String get varioSoundVerticalSpeed => 'Vertical speed';

  @override
  String get varioSoundKeypointsTitle => 'Vertical speed keypoints';

  @override
  String get varioSoundKeypointsDescription =>
      'Pin a custom pitch, beep rate, duty and waveform to a vertical speed. The vario interpolates between keypoints and uses the default sound outside their range.';

  @override
  String varioSoundKeypointAddAt(String speed) {
    return 'Add at $speed';
  }

  @override
  String get varioSoundKeypointClearAll => 'Clear all';

  @override
  String get varioSoundKeypointsEmpty =>
      'No keypoints yet. Drag the vertical speed slider above and add one.';

  @override
  String get varioSoundKeypointsNeedTwo =>
      'Add at least two keypoints to shape the sound.';

  @override
  String get varioSoundKeypointAudition => 'Audition';

  @override
  String get varioSoundKeypointDelete => 'Delete keypoint';

  @override
  String get varioSoundKeypointPitch => 'Pitch';

  @override
  String get varioSoundKeypointCycle => 'Beep cycle';

  @override
  String get varioSoundKeypointDuty => 'Duty';

  @override
  String get varioSoundKeypointContinuous => 'Continuous';

  @override
  String get varioSoundKeypointWaveform => 'Waveform';

  @override
  String get varioSoundSectionThresholds => 'Thresholds';

  @override
  String get varioSoundLiftThreshold => 'Lift threshold';

  @override
  String get varioSoundSinkThreshold => 'Sink threshold';

  @override
  String get varioSoundSectionPitch => 'Pitch';

  @override
  String get varioSoundLiftBasePitch => 'Lift base pitch';

  @override
  String get varioSoundLiftPitchRange => 'Lift pitch range';

  @override
  String get varioSoundSinkBasePitch => 'Sink base pitch';

  @override
  String get varioSoundSectionWaveform => 'Waveform';

  @override
  String get varioSoundLiftWaveform => 'Lift waveform';

  @override
  String get varioSoundSinkWaveform => 'Sink waveform';

  @override
  String get varioSoundSectionOutput => 'Output';

  @override
  String get varioSoundVarioSound => 'Vario sound';

  @override
  String get varioSoundVarioSoundDescription =>
      'Master on/off for the vario beeper.';

  @override
  String get varioSoundVolume => 'Vario volume';

  @override
  String get varioSoundMasterGain => 'Master gain';

  @override
  String get varioSoundSectionBehavior => 'Behavior';

  @override
  String get varioSoundOnlyWhenFlying => 'Sound only when flying';

  @override
  String get varioSoundOnlyWhenFlyingDescription =>
      'Stay silent until a flight is started, then beep normally.';

  @override
  String get varioSoundOnlyWhenSensorConnected =>
      'Sound only when sensor connected';

  @override
  String get varioSoundOnlyWhenSensorConnectedDescription =>
      'Stay silent unless a Bluetooth sensor is connected.';

  @override
  String get varioWaveformTick => 'Tick';

  @override
  String get varioWaveformTack => 'Tack';

  @override
  String get varioWaveformSquare => 'Square';

  @override
  String get varioWaveformLong => 'Long';
}
