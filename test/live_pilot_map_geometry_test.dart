import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parabeacon/controls/live_pilot_map_geometry.dart';

void main() {
  test('live pilot trail terminates exactly at the marker position', () {
    const trail = [LatLng(49.0, 8.0), LatLng(49.001, 8.001)];
    const currentPosition = LatLng(49.002, 8.003);

    final renderedTrail = livePilotTrailEndingAt(trail, currentPosition);

    expect(renderedTrail, hasLength(3));
    expect(renderedTrail.last.latitude, currentPosition.latitude);
    expect(renderedTrail.last.longitude, currentPosition.longitude);
  });

  test('anchors an empty trail at the current marker coordinate', () {
    const currentPosition = LatLng(49.002, 8.003);

    final renderedTrail = livePilotTrailEndingAt(const [], currentPosition);

    expect(renderedTrail, hasLength(1));
    expect(renderedTrail.single, currentPosition);
  });

  test('extends a single-point trail to the current marker coordinate', () {
    const trail = [LatLng(49.0, 8.0)];
    const currentPosition = LatLng(49.002, 8.003);

    final renderedTrail = livePilotTrailEndingAt(trail, currentPosition);

    expect(renderedTrail, hasLength(2));
    expect(renderedTrail.last, currentPosition);
  });

  test('does not add a duplicate point when trail already ends at marker', () {
    const trail = [LatLng(49.0, 8.0), LatLng(49.001, 8.001)];
    const currentPosition = LatLng(49.001, 8.001);

    final renderedTrail = livePilotTrailEndingAt(trail, currentPosition);

    expect(renderedTrail, hasLength(2));
    expect(renderedTrail.last.latitude, currentPosition.latitude);
    expect(renderedTrail.last.longitude, currentPosition.longitude);
  });
}
