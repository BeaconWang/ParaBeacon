import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/pilot_avatar.dart';

void main() {
  test('provides a bounded set of account icons and a safe fallback', () {
    expect(PilotAvatar.icons, hasLength(PilotAvatar.maxId + 1));
    for (var id = 0; id <= PilotAvatar.maxId; id++) {
      expect(PilotAvatar.isValid(id), isTrue);
      expect(PilotAvatar.iconFor(id), isA<IconData>());
    }
    expect(PilotAvatar.isValid(-1), isFalse);
    expect(PilotAvatar.isValid(PilotAvatar.maxId + 1), isFalse);
    expect(
      PilotAvatar.iconFor(999),
      PilotAvatar.iconFor(PilotAvatar.defaultId),
    );
  });
}
