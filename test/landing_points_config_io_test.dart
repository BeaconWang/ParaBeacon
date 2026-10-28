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

  test('merge keeps unmatched saved points and requires conflict choices', () {
    final savedDefault = LandingPoint(
      id: 'saved-home',
      name: 'Home LZ',
      latitude: 46,
      longitude: 6,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final savedOther = LandingPoint(
      id: 'saved-ridge',
      name: 'Ridge LZ',
      latitude: 47,
      longitude: 7,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final fileDuplicate = LandingPoint(
      id: 'file-home',
      name: 'home lz',
      latitude: 48,
      longitude: 8,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final fileNew = LandingPoint(
      id: 'file-valley',
      name: 'Valley LZ',
      latitude: 49,
      longitude: 9,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final imported = LandingPointsBundle(
      points: [fileDuplicate, fileNew],
      defaultId: fileDuplicate.id,
    );
    final conflicts = io.findNameConflicts([
      savedDefault,
      savedOther,
    ], imported.points);

    expect(conflicts, hasLength(1));
    expect(
      () => io.merge(
        savedPoints: [savedDefault, savedOther],
        savedDefaultId: savedDefault.id,
        imported: imported,
        conflictChoices: const {},
      ),
      throwsFormatException,
    );

    final merged = io.merge(
      savedPoints: [savedDefault, savedOther],
      savedDefaultId: savedDefault.id,
      imported: imported,
      conflictChoices: {
        conflicts.single.nameKey: conflicts.single.candidates.first.key,
      },
    );

    expect(merged.points.map((point) => point.id), [
      savedDefault.id,
      savedOther.id,
      fileNew.id,
    ]);
    expect(merged.defaultId, savedDefault.id);
  });

  test('choosing imported duplicate preserves the current default by name', () {
    final savedDefault = LandingPoint(
      id: 'saved-ridge',
      name: 'Ridge LZ',
      latitude: 46,
      longitude: 6,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final savedOther = LandingPoint(
      id: 'saved-home',
      name: 'Home LZ',
      latitude: 47,
      longitude: 7,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final fileDefault = LandingPoint(
      id: 'file-ridge',
      name: 'ridge lz',
      latitude: 48,
      longitude: 8,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final imported = LandingPointsBundle(
      points: [fileDefault],
      defaultId: fileDefault.id,
    );
    final conflict = io.findNameConflicts([
      savedDefault,
      savedOther,
    ], imported.points).single;
    final importedChoice = conflict.candidates.singleWhere(
      (candidate) => candidate.fromFile,
    );

    final merged = io.merge(
      savedPoints: [savedDefault, savedOther],
      savedDefaultId: savedDefault.id,
      imported: imported,
      conflictChoices: {conflict.nameKey: importedChoice.key},
    );

    expect(merged.points.map((point) => point.id), [
      fileDefault.id,
      savedOther.id,
    ]);
    expect(merged.defaultId, fileDefault.id);
  });

  test('keeps unrelated saved duplicates and avoids id collisions', () {
    final savedFirst = LandingPoint(
      id: 'shared-id',
      name: 'Old LZ',
      latitude: 46,
      longitude: 6,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final savedSecond = LandingPoint(
      id: 'saved-second',
      name: 'old lz',
      latitude: 47,
      longitude: 7,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final importedPoint = LandingPoint(
      id: 'shared-id',
      name: 'New LZ',
      latitude: 48,
      longitude: 8,
      createdAt: DateTime.utc(2026, 10, 22),
    );
    final imported = LandingPointsBundle(points: [importedPoint]);

    expect(
      io.findNameConflicts([savedFirst, savedSecond], imported.points),
      isEmpty,
    );
    final merged = io.merge(
      savedPoints: [savedFirst, savedSecond],
      savedDefaultId: null,
      imported: imported,
      conflictChoices: const {},
    );

    expect(merged.points, hasLength(3));
    expect(merged.points[0].id, savedFirst.id);
    expect(merged.points[1].id, savedSecond.id);
    expect(merged.points[2].name, importedPoint.name);
    expect(merged.points[2].id, isNot(savedFirst.id));
    expect(merged.points.map((point) => point.id).toSet(), hasLength(3));
  });

  test('merge refuses to exceed the saved-point limit', () {
    final saved = List.generate(
      LandingPointStore.maxEntries,
      (index) => LandingPoint(
        id: 'saved-$index',
        name: 'Saved $index',
        latitude: 40,
        longitude: index / 10,
        createdAt: DateTime.utc(2026, 10, 22),
      ),
    );
    final importedPoint = LandingPoint(
      id: 'file-new',
      name: 'New point',
      latitude: 41,
      longitude: 5,
      createdAt: DateTime.utc(2026, 10, 22),
    );

    expect(
      () => io.merge(
        savedPoints: saved,
        savedDefaultId: null,
        imported: LandingPointsBundle(points: [importedPoint]),
        conflictChoices: const {},
      ),
      throwsA(isA<LandingPointsLimitException>()),
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
