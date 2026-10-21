import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/flight_library_io.dart';

void main() {
  test('flight library exports use the compound ZIP extension', () {
    expect(FlightLibraryIO.extension, 'pbflights.zip');
  });
}
