import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/location_share_throttler.dart';

void main() {
  test('transmits on displacement or elapsed-time threshold', () {
    final throttler = LocationShareThrottler();
    final start = DateTime.utc(2026, 1, 1);

    expect(
      throttler.shouldTransmit(latitude: 37, longitude: -122, timestamp: start),
      isTrue,
    );
    expect(
      throttler.shouldTransmit(
        latitude: 37,
        longitude: -121.99999,
        timestamp: start.add(const Duration(milliseconds: 400)),
      ),
      isFalse,
    );
    expect(
      throttler.shouldTransmit(
        latitude: 37,
        longitude: -121.9999,
        timestamp: start.add(const Duration(milliseconds: 500)),
      ),
      isTrue,
    );
    expect(
      throttler.shouldTransmit(
        latitude: 37,
        longitude: -121.9999,
        timestamp: start.add(const Duration(milliseconds: 1500)),
      ),
      isTrue,
    );
  });

  test('rejects invalid coordinates and non-monotonic timestamps', () {
    final throttler = LocationShareThrottler();
    final timestamp = DateTime.utc(2026, 1, 1);
    expect(
      throttler.shouldTransmit(
        latitude: 91,
        longitude: 0,
        timestamp: timestamp,
      ),
      isFalse,
    );
    expect(
      throttler.shouldTransmit(latitude: 0, longitude: 0, timestamp: timestamp),
      isTrue,
    );
    expect(
      throttler.shouldTransmit(
        latitude: 0,
        longitude: 0,
        timestamp: timestamp.subtract(const Duration(seconds: 1)),
      ),
      isFalse,
    );
  });

  test('filters implausible GPS jumps without losing the last good fix', () {
    final throttler = LocationShareThrottler();
    final start = DateTime.utc(2026, 1, 1);
    expect(
      throttler.shouldTransmit(latitude: 0, longitude: 0, timestamp: start),
      isTrue,
    );
    expect(
      throttler.shouldTransmit(
        latitude: 0,
        longitude: 0.002,
        timestamp: start.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      throttler.shouldTransmit(
        latitude: 0,
        longitude: 0.0005,
        timestamp: start.add(const Duration(seconds: 2)),
      ),
      isTrue,
    );
  });
}
