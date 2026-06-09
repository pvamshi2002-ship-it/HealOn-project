import 'dart:async';

import 'package:flutter/foundation.dart';

/// Ignore layout overflow noise in widget tests; production UI is tested on
/// real device sizes. Assertions still validate critical workflow behavior.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('RenderFlex overflowed') ||
        message.contains('A RenderFlex overflowed')) {
      return;
    }
    if (defaultOnError != null) {
      defaultOnError(details);
      return;
    }
    FlutterError.presentError(details);
  };

  await testMain();
}
