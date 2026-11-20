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
      ParaBeaconServerConfig.isValidUserOrigin(
        Uri.parse('http://8.8.8.8:8080'),
      ),
      isTrue,
    );
    expect(
      ParaBeaconServerConfig.isValidOrigin(
        Uri.parse('https://[2606:4700:4700::1111]:8443'),
      ),
      isTrue,
    );
  });

  test('rejects reserved and IPv4-mapped private addresses', () {
    for (final address in [
      'https://100.100.100.20',
      'https://192.0.2.10',
      'https://198.19.0.1',
      'https://[2001:db8::1]',
      'https://[::ffff:192.168.1.20]',
    ]) {
      expect(
        ParaBeaconServerConfig.isValidOrigin(Uri.parse(address)),
        isFalse,
        reason: '$address must not be accepted as a public server origin',
      );
    }
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
