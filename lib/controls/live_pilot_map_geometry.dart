import 'package:latlong2/latlong.dart';

List<LatLng> livePilotTrailEndingAt(
  Iterable<LatLng> trail,
  LatLng currentPosition,
) {
  final points = trail.toList(growable: true);
  if (points.isEmpty ||
      points.last.latitude != currentPosition.latitude ||
      points.last.longitude != currentPosition.longitude) {
    points.add(currentPosition);
  }
  return List.unmodifiable(points);
}
