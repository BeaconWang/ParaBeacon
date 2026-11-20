import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parabeacon/controls/live_pilot_map_marker.dart';

void main() {
  testWidgets('shows live pilot identity, course, and flight details', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: LivePilotMapMarker(
              name: 'Sky Pilot',
              color: Colors.blue,
              landed: false,
              avatarId: 2,
              profileImageUrl:
                  '/api/v1/profile-images/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
              flightInfo: '1,250 m · 42 km/h',
              headingDegrees: 125,
              screenRotationDegrees: -20,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      contains('/api/v1/profile-images/'),
    );
    expect(find.byType(ClipOval), findsOneWidget);
    expect(find.byType(PilotDirectionIndicator), findsOneWidget);
    expect(find.text('Sky Pilot'), findsOneWidget);
    expect(find.text('1,250 m · 42 km/h'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Sky Pilot, sharing live location'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('independently hides name and flight detail captions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LivePilotMapMarker(
            name: 'Hidden Name',
            color: Colors.blue,
            landed: false,
            showName: false,
            flightInfo: '1,250 m',
          ),
        ),
      ),
    );
    expect(find.text('Hidden Name'), findsNothing);
    expect(find.text('1,250 m'), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LivePilotMapMarker(
            name: 'Visible Name',
            color: Colors.blue,
            landed: false,
            showName: true,
            flightInfo: '',
          ),
        ),
      ),
    );
    expect(find.text('Visible Name'), findsOneWidget);
    expect(find.text('1,250 m'), findsNothing);
  });

  testWidgets('keeps landed pilots visible but de-emphasized', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LivePilotMapMarker(
            name: 'Landed Pilot',
            color: Colors.orange,
            landed: true,
          ),
        ),
      ),
    );

    expect(find.text('Landed Pilot'), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);
    expect(find.byType(PilotDirectionIndicator), findsNothing);
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.45);
    expect(find.bySemanticsLabel('Landed Pilot, landed'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('keeps avatar center on map coordinate with or without heading', (
    tester,
  ) async {
    for (final heading in <double?>[null, 90]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: LivePilotMapMarker.markerWidth,
                height: LivePilotMapMarker.markerHeight,
                child: LivePilotMapMarker(
                  name: 'Anchor Pilot',
                  color: Colors.blue,
                  landed: false,
                  showName: false,
                  headingDegrees: heading,
                ),
              ),
            ),
          ),
        ),
      );

      final avatar = tester.getRect(find.byType(ClipOval));
      final markerRect = tester.getRect(find.byType(LivePilotMapMarker));
      final anchorOffsetFromTop =
          (1 - LivePilotMapMarker.markerAlignment.y) *
          LivePilotMapMarker.markerHeight /
          2;

      expect(avatar.center.dx, closeTo(markerRect.center.dx, 0.1));
      expect(
        avatar.center.dy - markerRect.top,
        closeTo(LivePilotMapMarker.glyphCenterFromTop, 0.1),
      );
      expect(
        avatar.center.dy - markerRect.top,
        closeTo(anchorOffsetFromTop, 0.1),
      );
    }
  });
}
