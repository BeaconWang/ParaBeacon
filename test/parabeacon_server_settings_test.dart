import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parabeacon/data/parabeacon_server_config.dart';
import 'package:parabeacon/data/parabeacon_server_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'validates and persists a public HTTPS origin for next startup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = ParaBeaconServerSettings.instance;
      await settings.load();
      final runtimeBaseUri = ParaBeaconServerConfig.apiBaseUri;
      Future<List<InternetAddress>> publicLookup(String host) async => [
        InternetAddress.tryParse('8.8.8.8')!,
      ];
      addTearDown(() async {
        if (ParaBeaconServerConfig.isValidUserOrigin(runtimeBaseUri)) {
          await settings.setServerAddress(
            runtimeBaseUri.toString(),
            lookup: publicLookup,
          );
          ParaBeaconServerConfig.configureBaseUri(runtimeBaseUri);
        }
      });

      expect(settings.serverAddress, runtimeBaseUri.toString());
      expect(
        ParaBeaconServerSettings.parseAddress('example.org'),
        Uri.parse('https://example.org'),
      );
      expect(
        ParaBeaconServerSettings.parseAddress('http://example.org'),
        isNull,
      );
      expect(
        ParaBeaconServerSettings.parseAddress('https://user@example.org'),
        isNull,
      );
      expect(
        ParaBeaconServerSettings.parseAddress('https://example.org/api'),
        isNull,
      );
      expect(ParaBeaconServerSettings.parseAddress('https://10.1.2.3'), isNull);
      expect(
        ParaBeaconServerSettings.parseAddress('https://[fc00::1]'),
        isNull,
      );
      expect(
        ParaBeaconServerSettings.parseAddress(
          'https://[2606:4700:4700::1111]:8443',
        ),
        Uri.parse('https://[2606:4700:4700::1111]:8443'),
      );

      final saved = await settings.setServerAddress(
        'example.org',
        lookup: publicLookup,
      );
      expect(saved, isTrue);
      expect(settings.serverAddress, 'https://example.org');
      expect(settings.baseUri, runtimeBaseUri);
      expect(ParaBeaconServerConfig.apiBaseUri, runtimeBaseUri);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(ParaBeaconServerSettings.preferenceKey),
        'https://example.org',
      );
      ParaBeaconServerConfig.configureBaseUri(runtimeBaseUri);
      final restoredSettings = ParaBeaconServerSettings();
      await restoredSettings.load();
      expect(restoredSettings.serverAddress, 'https://example.org');
      expect(
        ParaBeaconServerConfig.apiBaseUri,
        Uri.parse('https://example.org'),
      );

      final privateDns = await settings.setServerAddress(
        'private.example.org',
        lookup: (host) async => [InternetAddress.tryParse('192.168.1.20')!],
      );
      expect(privateDns, isFalse);
      expect(settings.serverAddress, 'https://example.org');
      expect(
        preferences.getString(ParaBeaconServerSettings.preferenceKey),
        'https://example.org',
      );
    },
  );
}
