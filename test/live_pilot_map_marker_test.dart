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

  test('anchors the live pilot avatar center to its map coordinate', () {
    final marker = LivePilotMapMarker.markerAlignment;
    expect(
      (marker.y + 1) * LivePilotMapMarker.markerHeight / 2,
      closeTo(LivePilotMapMarker.glyphCenterFromTop, 1e-10),
    );
  });
}
