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
    expect(find.byIcon(Icons.paragliding), findsOneWidget);
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

  test('uses the paraglider as the only preset fallback icon', () {
    for (var legacyId = 0; legacyId <= PilotAvatar.maxId; legacyId++) {
      expect(PilotAvatar.isValid(legacyId), isTrue);
      expect(PilotAvatar.iconFor(legacyId), Icons.paragliding);
    }
    expect(PilotAvatar.isValid(-1), isFalse);
    expect(PilotAvatar.isValid(PilotAvatar.maxId + 1), isFalse);
    expect(PilotAvatar.iconFor(999), Icons.paragliding);
  });
}
