import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/live_tracking_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates enabled legacy tracking to selected destinations', () async {
    SharedPreferences.setMockInitialValues({
      'Livetrack.Enabled': true,
      'Livetrack.XContestEnabled': false,
    });

    final settings = LiveTrackingSettings.instance;
    await settings.load();

    expect(settings.xcontestEnabled, isFalse);
    expect(settings.parabeaconEnabled, isTrue);
    expect(settings.hasExplicitDestinationSelection, isTrue);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool('Livetrack.DestinationMigrationComplete'),
      isTrue,
    );
    expect(preferences.getBool('Livetrack.XContestEnabled'), isFalse);
    expect(preferences.getBool('Livetrack.ParaBeaconEnabled'), isTrue);
    expect(preferences.containsKey('Livetrack.Enabled'), isFalse);
  });
}
