import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/live/peer_location_interpolator.dart';

void main() {
  test('moves smoothly across the antimeridian', () {
    final interpolator = PeerLocationInterpolator();
    final now = DateTime.now().toUtc();
    interpolator.update(latitude: 10, longitude: 179.9, timestamp: now);
    interpolator.update(
      latitude: 10,
      longitude: -179.9,
      timestamp: now.add(const Duration(seconds: 1)),
    );

    final halfway = interpolator.positionAt(
      DateTime.now().toUtc().add(const Duration(milliseconds: 150)),
    );
    expect(halfway, isNotNull);
    expect(halfway!.longitude.abs(), greaterThan(179));
  });

  test('smooths timestamped pilot samples without speed data', () {
    final interpolator = PeerLocationInterpolator(
      interpolationDuration: const Duration(milliseconds: 900),
    );
    final observedAt = DateTime.now().toUtc();
    interpolator.update(latitude: 0, longitude: 0, timestamp: observedAt);
    interpolator.update(
      latitude: 1,
      longitude: 1,
      timestamp: observedAt.add(const Duration(seconds: 1)),
    );

    final halfway = interpolator.positionAt(
      DateTime.now().toUtc().add(const Duration(milliseconds: 450)),
    );
    expect(halfway, isNotNull);
    expect(halfway!.latitude, inInclusiveRange(0.45, 0.55));
    expect(halfway.longitude, inInclusiveRange(0.45, 0.55));
  });

  test('dead reckoning is bounded to three seconds', () {
    final interpolator = PeerLocationInterpolator();
    final observedAt = DateTime.now().toUtc().subtract(
      const Duration(seconds: 10),
    );
    interpolator.update(
      latitude: 0,
      longitude: 0,
      timestamp: observedAt,
      speedMetersPerSecond: 10,
      headingDegrees: 90,
    );

    final threeSeconds = interpolator.positionAt(
      DateTime.now().toUtc().add(const Duration(seconds: 3)),
    );
    final later = interpolator.positionAt(
      DateTime.now().toUtc().add(const Duration(seconds: 10)),
    );
    expect(threeSeconds, isNotNull);
    expect(later, isNotNull);
    expect(later!.longitude, closeTo(threeSeconds!.longitude, 0.000001));
    expect(later.longitude, greaterThan(0));
  });
}
