import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/platform/android_device.dart';

void main() {
  test('recognizes Huawei and HarmonyOS device identifiers', () {
    expect(
      AndroidDevice.isHuaweiOrHarmonyInfo({
        'manufacturer': 'HUAWEI',
        'brand': 'HUAWEI',
        'model': 'HUAWEI Mate 80',
      }),
      isTrue,
    );
    expect(
      AndroidDevice.isHuaweiOrHarmonyInfo({
        'manufacturer': 'unknown',
        'model': 'Mate 80',
        'isHarmonyOS': true,
      }),
      isTrue,
    );
    expect(
      AndroidDevice.isHuaweiOrHarmonyInfo({'product': 'HongMeng-device'}),
      isTrue,
    );
    expect(AndroidDevice.isHuaweiOrHarmonyInfo({}), isFalse);
  });
}
