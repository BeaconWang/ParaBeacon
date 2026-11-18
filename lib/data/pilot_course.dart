import 'dart:math' as math;

import 'geo_math.dart';

abstract final class PilotCourse {
  static const minimumMovementMeters = 5.0;
  static const maximumSampleGap = Duration(seconds: 90);
  static const maximumFixAge = Duration(seconds: 90);
  static const futureTolerance = Duration(seconds: 5);
  static const minimumCourseSpeedMetersPerSecond = 1.0;

  static bool isFresh(
    DateTime timestamp,
    DateTime now, {
    Duration maxAge = maximumFixAge,
  }) {
    final age = now.toUtc().difference(timestamp.toUtc());
    return age <= maxAge && age >= -futureTolerance;
  }

  static double? fromPositions({
    required double previousLatitude,
    required double previousLongitude,
    required DateTime previousTimestamp,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required DateTime now,
    double minimumMovement = minimumMovementMeters,
    Duration maximumGap = maximumSampleGap,
  }) {
    if (!hasValidCoordinates(previousLatitude, previousLongitude) ||
        !hasValidCoordinates(latitude, longitude)) {
      return null;
    }
    final previous = previousTimestamp.toUtc();
    final current = timestamp.toUtc();
    final gap = current.difference(previous);
    if (!current.isAfter(previous) ||
        gap > maximumGap ||
        !isFresh(current, now)) {
      return null;
    }
    final distance = GeoMath.distanceMeters(
      previousLatitude,
      previousLongitude,
      latitude,
      longitude,
    );
    if (!distance.isFinite || distance < minimumMovement) return null;
    return GeoMath.bearingDegrees(
      previousLatitude,
      previousLongitude,
      latitude,
      longitude,
    );
  }

  static double? fromHeading({
    required double? headingDegrees,
    required double? speedMetersPerSecond,
  }) {
    if (headingDegrees == null ||
        !headingDegrees.isFinite ||
        headingDegrees < 0 ||
        headingDegrees >= 360 ||
        speedMetersPerSecond == null ||
        !speedMetersPerSecond.isFinite ||
        speedMetersPerSecond < minimumCourseSpeedMetersPerSecond) {
      return null;
    }
    return headingDegrees;
  }

  static double screenDegrees({
    required double courseDegrees,
    required double mapRotationDegrees,
  }) {
    var degrees = (courseDegrees + mapRotationDegrees) % 360;
    if (degrees < 0) degrees += 360;
    return degrees;
  }

  static double screenRadians({
    required double courseDegrees,
    required double mapRotationDegrees,
  }) =>
      screenDegrees(
        courseDegrees: courseDegrees,
        mapRotationDegrees: mapRotationDegrees,
      ) *
      math.pi /
      180;

  static bool hasValidCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

class PilotCourseTracker {
  final Map<String, _PilotCourseSample> _samples = {};

  double? update({
    required String pilotId,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required DateTime now,
    bool landed = false,
  }) {
    final currentTime = timestamp.toUtc();
    if (!PilotCourse.hasValidCoordinates(latitude, longitude) ||
        !PilotCourse.isFresh(currentTime, now)) {
      return null;
    }
    final previous = _samples[pilotId];
    if (previous != null && !currentTime.isAfter(previous.timestamp)) {
      if (landed ||
          previous.courseTimestamp == null ||
          !PilotCourse.isFresh(previous.courseTimestamp!, now)) {
        return null;
      }
      return previous.courseDegrees;
    }

    var course = previous?.courseDegrees;
    var courseTimestamp = previous?.courseTimestamp;
    if (previous != null) {
      final derived = PilotCourse.fromPositions(
        previousLatitude: previous.latitude,
        previousLongitude: previous.longitude,
        previousTimestamp: previous.timestamp,
        latitude: latitude,
        longitude: longitude,
        timestamp: currentTime,
        now: now,
      );
      if (derived != null) {
        course = derived;
        courseTimestamp = currentTime;
      } else if (courseTimestamp == null ||
          !PilotCourse.isFresh(courseTimestamp, now)) {
        course = null;
        courseTimestamp = null;
      }
    }
    if (landed) {
      course = null;
      courseTimestamp = null;
    }
    _samples[pilotId] = _PilotCourseSample(
      latitude: latitude,
      longitude: longitude,
      timestamp: currentTime,
      courseDegrees: course,
      courseTimestamp: courseTimestamp,
    );
    return course;
  }

  void retainPilots(Set<String> pilotIds) {
    _samples.removeWhere((pilotId, _) => !pilotIds.contains(pilotId));
  }

  void clear() => _samples.clear();
}

class _PilotCourseSample {
  const _PilotCourseSample({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.courseDegrees,
    required this.courseTimestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? courseDegrees;
  final DateTime? courseTimestamp;
}
