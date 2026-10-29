import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/data_value_control.dart';
import 'package:parabeacon/data/vertical_speed_settings.dart';
import 'package:parabeacon/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Vertical Speed caption shows and tracks averaging window', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await VerticalSpeedSettings.instance.setAverageWindowSeconds(2.0);

    await tester.pumpWidget(_appForLocale(const Locale('en')));

    expect(find.text('AVG · 2.0 s'), findsOneWidget);
    final captionStyle = tester.widget<Text>(find.text('AVG · 2.0 s')).style!;
    final titleStyle = tester.widget<Text>(find.text('VERTICAL SPEED')).style!;
    expect(captionStyle.fontSize, lessThan(titleStyle.fontSize!));

    await VerticalSpeedSettings.instance.setAverageWindowSeconds(2.5);
    await tester.pump();

    expect(find.text('AVG · 2.0 s'), findsNothing);
    expect(find.text('AVG · 2.5 s'), findsOneWidget);

    await tester.pumpWidget(_appForLocale(const Locale('zh')));
    expect(find.text('平均 · 2.5 秒'), findsOneWidget);
  });
}

Widget _appForLocale(Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: Center(
      child: SizedBox(
        width: 240,
        height: 100,
        child: VerticalSpeedControl(verticalSpeed: 1.2),
      ),
    ),
  ),
);
