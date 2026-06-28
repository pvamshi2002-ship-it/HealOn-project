// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:geolocator/geolocator.dart';

const Duration attendanceLocationTimeout = Duration(seconds: 15);
const Duration attendanceLocationMaxAge = Duration(seconds: 45);

bool isFreshAttendancePosition(Position position) {
  final capturedAt = position.timestamp.toUtc();
  final age = DateTime.now().toUtc().difference(capturedAt).abs();
  return age <= attendanceLocationMaxAge;
}

Future<Position> getFreshAttendancePosition() async {
  final webPosition = await html.window.navigator.geolocation
      .getCurrentPosition(
        enableHighAccuracy: true,
        timeout: attendanceLocationTimeout,
        maximumAge: Duration.zero,
      );
  final coords = webPosition.coords;
  if (coords == null) {
    throw TimeoutException('Unable to get live GPS coordinates.');
  }
  final timestamp = webPosition.timestamp == null
      ? DateTime.now().toUtc()
      : DateTime.fromMillisecondsSinceEpoch(
          webPosition.timestamp!,
          isUtc: true,
        );
  final position = Position(
    longitude: (coords.longitude ?? 0).toDouble(),
    latitude: (coords.latitude ?? 0).toDouble(),
    timestamp: timestamp,
    accuracy: (coords.accuracy ?? 0).toDouble(),
    altitude: (coords.altitude ?? 0).toDouble(),
    altitudeAccuracy: (coords.altitudeAccuracy ?? 0).toDouble(),
    heading: (coords.heading ?? 0).toDouble(),
    headingAccuracy: 0,
    speed: (coords.speed ?? 0).toDouble(),
    speedAccuracy: 0,
  );
  if (!isFreshAttendancePosition(position)) {
    throw TimeoutException('Unable to get a fresh live GPS position.');
  }
  return position;
}
