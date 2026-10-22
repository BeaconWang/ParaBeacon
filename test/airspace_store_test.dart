import 'package:flutter_test/flutter_test.dart';

import 'package:parabeacon/data/airspace_store.dart';

void main() {
  test('unchanged proximity is not emitted again', () async {
    final store = AirspaceStore.instance;
    store.loadOpenAirString('''
AC C
AN Test airspace
AL SFC
AH 3000 M
DP 47:00:00 N 008:00:00 E
DP 47:01:00 N 008:00:00 E
DP 47:01:00 N 008:01:00 E
DP 47:00:00 N 008:01:00 E
''');

    final emissions = <List<AirspaceProximity>>[];
    final subscription = store.proximityStream.listen(emissions.add);
    store.updatePosition(47.005, 8.005, 100);
    store.updatePosition(47.005, 8.005, 100);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(1));

    store.updatePosition(47.005, 8.005, 4000);
    await Future<void>.delayed(Duration.zero);
    expect(emissions, hasLength(2));
    expect(emissions.last.single.verticalM, greaterThan(0));

    await subscription.cancel();
    store.loadOpenAirString('');
    store.updatePosition(47.005, 8.005, 100);
  });
}
