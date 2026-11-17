import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/parabeacon_server_config.dart';

void main() {
  test('accepts HTTP and HTTPS public IP origins including IPv4 and IPv6', () {
    expect(
      ParaBeaconServerConfig.isValidOrigin(Uri.parse('https://8.8.8.8:8443')),
      isTrue,
    );
    expect(
      ParaBeaconServerConfig.isValidOrigin(Uri.parse('http://8.8.8.8:8080')),
      isTrue,
    );
    expect(
      ParaBeaconServerConfig.isValidOrigin(
        Uri.parse('https://[2606:4700:4700::1111]:8443'),
      ),
      isTrue,
    );
  });

  test('rejects insecure and internal origins', () {
    expect(
      ParaBeaconServerConfig.isValidOrigin(Uri.parse('ftp://8.8.8.8')),
      isFalse,
    );
    expect(
      ParaBeaconServerConfig.isValidOrigin(Uri.parse('https://10.1.2.3')),
      isFalse,
    );
  });
}
