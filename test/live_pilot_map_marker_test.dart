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
      tester.widget<Text>(find.text('Sky Pilot')).style?.color?.a,
      lessThan(1),
    );
    expect(
      tester.widget<Text>(find.text('1,250 m · 42 km/h')).style?.color?.a,
      lessThan(1),
    );
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

  testWidgets('centers the pilot icon on its anchor with or without heading', (
    tester,
  ) async {
    for (final heading in <double?>[null, 90]) {
      for (final showName in [true, false]) {
        for (final flightInfo in <String?>[null, '1,250 m · 42 km/h']) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: LivePilotMapMarker(
                    name: 'Anchor Pilot',
                    color: Colors.blue,
                    landed: false,
                    showName: showName,
                    flightInfo: flightInfo,
                    headingDegrees: heading,
                  ),
                ),
              ),
            ),
          );

          final icon = tester.getRect(find.byType(ClipOval));
          final stageFinder = find.ancestor(
            of: find.byType(ClipOval),
            matching: find.byType(Stack),
          );
          expect(stageFinder, findsOneWidget);
          final stage = tester.getRect(stageFinder);
          final marker = tester.getRect(find.byType(LivePilotMapMarker));
          expect(
            marker.size,
            const Size(
              LivePilotMapMarker.markerWidth,
              LivePilotMapMarker.markerHeight,
            ),
          );
          expect(
            stage.size,
            const Size.square(LivePilotMapMarker.iconStageSize),
          );
          expect(icon.center.dx, closeTo(stage.center.dx, 0.1));
          expect(icon.center.dy, closeTo(stage.center.dy, 0.1));
          expect(
            stage.center.dy - marker.top,
            closeTo(LivePilotMapMarker.glyphCenterFromTop, 0.5),
          );
        }
      }
    }
  });

  test('anchors the live pilot avatar center to its map coordinate', () {
    final marker = LivePilotMapMarker.markerAlignment;
    expect(
      (marker.y + 1) * LivePilotMapMarker.markerHeight / 2,
      closeTo(LivePilotMapMarker.glyphCenterFromTop, 1e-10),
    );
  });
}
