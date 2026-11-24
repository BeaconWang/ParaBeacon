import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/app_notice.dart';

void main() {
  setUp(AppNotice.clear);
  tearDown(AppNotice.clear);

  testWidgets('app notice stays visible above a fullscreen dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppNoticeOverlay(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog.fullscreen(
                  child: Center(
                    child: FilledButton(
                      onPressed: () => AppNotice.show('Image saved'),
                      child: const Text('Show notice'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show notice'));
    await tester.pump();

    expect(find.text('Image saved'), findsOneWidget);
    expect(find.text('Show notice'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('app-notice-1'))).dy,
      lessThan(tester.getTopLeft(find.text('Show notice')).dy),
    );

    await tester.tap(find.text('Image saved'));
    await tester.pump();
    expect(find.text('Image saved'), findsNothing);
    expect(find.text('Show notice'), findsOneWidget);
  });

  testWidgets('queues notices rather than dropping later results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppNoticeOverlay(child: child!),
        home: const Scaffold(body: Text('Dashboard')),
      ),
    );

    AppNotice.show('First notice');
    AppNotice.show('Second notice');
    await tester.pump();

    expect(find.text('First notice'), findsOneWidget);
    expect(find.text('Second notice'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('First notice'), findsNothing);
    expect(find.text('Second notice'), findsOneWidget);
    AppNotice.clear();
    await tester.pump();
  });
}
