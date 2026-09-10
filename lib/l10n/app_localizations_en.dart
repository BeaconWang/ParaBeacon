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
}
