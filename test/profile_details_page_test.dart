import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parabeacon/controls/profile_details_page.dart';
import 'package:parabeacon/data/parabeacon_account_service.dart';
import 'package:parabeacon/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows profile rows and edits name, introduction, and gender', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profileJson = <String, Object?>{
      'id': 'profile-user',
      'username': 'beacon',
      'display_name': 'Beacon',
      'introduction': 'Ridge pilot',
      'gender': 'female',
      'birthday': '1990-05-06',
      'pilot_number': 123456,
      'channel_number': 0,
      'avatar_id': 0,
    };
    final accountClient = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'access_token': 'details-page-token',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toUtc()
                .toIso8601String(),
            'refresh_token': 'details-page-refresh-token-long-value',
            'refresh_expires_at': null,
            'user': profileJson,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/user/change-password') {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'current_password': 'old-pass-123',
          'new_password': 'new-pass-456',
        });
        return http.Response('', 204);
      }
      expect(request.method, 'PATCH');
      profileJson.addAll(jsonDecode(request.body) as Map<String, Object?>);
      return http.Response(
        jsonEncode({'user': profileJson}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final account = ParaBeaconAccountService(
      client: accountClient,
      sessionStore: _MemorySessionStore(),
    );
    addTearDown(account.dispose);
    addTearDown(accountClient.close);
    expect(
      await account.login(identifier: 'beacon', password: 'abc123'),
      isTrue,
    );

    var imageChangeOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileDetailsPage(
          account: account,
          onChangeProfileImage: () async => imageChangeOpened = true,
          onOpenProfileImage: () async {},
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Beacon'), findsOneWidget);
    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Ridge pilot'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Birthday'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-detail-image')));
    expect(imageChangeOpened, isTrue);

    await tester.tap(find.byKey(const ValueKey('profile-detail-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New Beacon');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(account.user?.displayName, 'New Beacon');

    await tester.tap(find.byKey(const ValueKey('profile-detail-introduction')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mountain pilot');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(account.user?.introduction, 'Mountain pilot');

    await tester.tap(find.byKey(const ValueKey('profile-detail-gender')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();
    expect(account.user?.gender, 'male');

    expect(
      find.byKey(const ValueKey('profile-change-password')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('profile-change-password')));
    await tester.pumpAndSettle();
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'old-pass-123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'new-pass-456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'new-pass-456',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final changePasswordButton = find.widgetWithText(
      FilledButton,
      'Change password',
    );
    await tester.ensureVisible(changePasswordButton);
    await tester.pumpAndSettle();
    await tester.tap(changePasswordButton);
    await tester.pumpAndSettle();
    expect(account.isSignedIn, isFalse);
    expect(find.text('Sign in to view your profile.'), findsOneWidget);
  });
}

class _MemorySessionStore implements AccountSessionStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
