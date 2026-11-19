import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/profile_image_preview.dart';

void main() {
  testWidgets('shows Change, Reset, and Download actions for profile image', (
    tester,
  ) async {
    var changeCount = 0;
    var resetCount = 0;
    var downloadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showProfileImagePreview(
                  context,
                  imageUrl:
                      '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
                  title: 'Profile image',
                  closeLabel: 'Close',
                  changeLabel: 'Change',
                  resetLabel: 'Reset',
                  downloadLabel: 'Download',
                  downloadingLabel: 'Downloading',
                  downloadSuccessLabel: 'Downloaded',
                  downloadFailedLabel: 'Download failed',
                  onChange: () async => changeCount++,
                  onReset: () async => resetCount++,
                  onDownload: () async {
                    downloadCount++;
                    return true;
                  },
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    expect(find.text('Profile image'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      contains('/api/v1/profile-images/'),
    );
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(downloadCount, 1);
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.text('Profile image'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(resetCount, 1);
    expect(find.text('Open preview'), findsOneWidget);

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(changeCount, 1);
    expect(find.text('Open preview'), findsOneWidget);

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Open preview'), findsOneWidget);
  });
}
