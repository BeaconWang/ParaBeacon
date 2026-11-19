import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/data/pilot_avatar.dart';
import 'package:parabeacon/data/profile_image_url.dart';

void main() {
  testWidgets('renders the account icon in a rounded rectangle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PilotAvatarPicture(avatarId: 2, size: 48)),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(48 * 0.24));
    expect(find.byIcon(PilotAvatar.iconFor(2)), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  test('resolves only versioned ParaBeacon profile image routes', () {
    final resolved = ProfileImageUrl.resolve(
      '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    expect(resolved?.origin, 'https://www.parabeacon.icu');
    expect(
      ProfileImageUrl.resolve('https://attacker.example/profile.jpg'),
      isNull,
    );
    expect(ProfileImageUrl.resolve('/api/v1/profile-images/not-an-id'), isNull);
  });

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
