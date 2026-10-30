import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/data/user_agent_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'default and custom User-Agent are applied to app HTTP requests',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = UserAgentSettings.instance;
      await settings.load();

      expect(settings.userAgent, UserAgentSettings.chromeDefault);
      expect(
        settings.forRequest(
          Uri.https('nominatim.openstreetmap.org', '/search'),
        ),
        '${UserAgentSettings.chromeDefault} ParaBeacon/0.1 (paraglider flight assistant)',
      );
      final receivedUserAgents = <String>[];
      final client = UserAgentHttpClient(
        innerClient: MockClient((request) async {
          receivedUserAgents.add(request.headers['user-agent']!);
          return http.Response('ok', 200);
        }),
      );

      await client.get(Uri.https('example.test', '/default'));
      expect(receivedUserAgents.last, UserAgentSettings.chromeDefault);

      expect(await settings.setUserAgent('ParaBeacon Test/2.0'), isTrue);
      await client.get(Uri.https('example.test', '/custom'));
      expect(receivedUserAgents.last, 'ParaBeacon Test/2.0');
      expect(
        settings.forRequest(
          Uri.https('nominatim.openstreetmap.org', '/search'),
        ),
        'ParaBeacon Test/2.0',
      );

      expect(await settings.setUserAgent('invalid\r\nInjected: yes'), isFalse);
      await client.get(Uri.https('example.test', '/still-custom'));
      expect(receivedUserAgents.last, 'ParaBeacon Test/2.0');

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(UserAgentSettings.preferenceKey),
        'ParaBeacon Test/2.0',
      );
      await settings.resetToChromeDefault();
      expect(preferences.containsKey(UserAgentSettings.preferenceKey), isFalse);
      client.close();
    },
  );
}
