import 'dart:async';

import 'package:geolocator/geolocator.dart';

const Duration attendanceLocationTimeout = Duration(seconds: 15);
const Duration attendanceLocationMaxAge = Duration(seconds: 45);

bool isFreshAttendancePosition(Position position) {
  final capturedAt = position.timestamp.toUtc();
  final age = DateTime.now().toUtc().difference(capturedAt).abs();
  return age <= attendanceLocationMaxAge;
}

Future<Position> getFreshAttendancePosition() async {
  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.bestForNavigation,
    timeLimit: attendanceLocationTimeout,
  );
  if (!isFreshAttendancePosition(position)) {
    throw TimeoutException('Unable to get a fresh live GPS position.');
  }
  return position;
}
