import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/landing_point_store.dart';
import 'package:parabeacon/data/landing_points_config_io.dart';

void main() {
  final io = LandingPointsConfigIO.instance;

  test('landing-point bundle round-trips points and default destination', () {
    final point = LandingPoint(
      id: 'lz-home',
      name: 'Home LZ',
      latitude: 46.5197,
      longitude: 6.6323,
      altitudeM: 1420.5,
      createdAt: DateTime.utc(2026, 10, 22),
      notes: 'Road access',
    );

    final restored = io.parseBundle(
      utf8.encode(io.buildBundle([point], defaultId: point.id)),
    );

    expect(restored.points, hasLength(1));
    expect(restored.points.single.toJson(), point.toJson());
    expect(restored.defaultId, point.id);
  });

  test('rejects unsupported formats and invalid point records', () {
    expect(
      () => io.parseBundle(
        utf8.encode(
          jsonEncode({'format': 'parabeacon.landing-points', 'version': 2}),
        ),
      ),
      throwsFormatException,
    );

    final invalidPoint = {
      'id': 'bad',
      'name': 'Bad LZ',
      'latitude': 91,
      'longitude': 0,
      'createdAt': DateTime.utc(2026).toIso8601String(),
    };
    expect(
      () => io.parseBundle(
        utf8.encode(
          jsonEncode({
            'format': 'parabeacon.landing-points',
            'version': 1,
            'points': [invalidPoint],
            'defaultId': null,
          }),
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejects duplicate point ids and a dangling default id', () {
    final point = LandingPoint(
      id: 'lz-home',
      name: 'Home LZ',
      latitude: 46,
      longitude: 6,
      createdAt: DateTime.utc(2026, 10, 22),
    ).toJson();

    Map<String, Object?> bundle(List<Object?> points, String? defaultId) => {
      'format': 'parabeacon.landing-points',
      'version': 1,
      'points': points,
      'defaultId': defaultId,
    };

    expect(
      () =>
          io.parseBundle(utf8.encode(jsonEncode(bundle([point, point], null)))),
      throwsFormatException,
    );
    expect(
      () => io.parseBundle(utf8.encode(jsonEncode(bundle([point], 'missing')))),
      throwsFormatException,
    );
  });

  test('rejects files that exceed the configured size limit', () {
    expect(
      () => io.parseBundle(
        List<int>.filled(LandingPointsConfigIO.maxFileBytes + 1, 32),
      ),
      throwsFormatException,
    );
  });
}
