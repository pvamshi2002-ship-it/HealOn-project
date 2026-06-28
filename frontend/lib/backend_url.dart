import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Override at build/run time with:
/// `flutter run --dart-define=BACKEND_URL=http://127.0.0.1:8000`
const String _backendUrlOverride = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: '',
);

String resolveBackendUrl() {
  final override = _backendUrlOverride.trim();
  if (override.isNotEmpty) {
    return override.replaceAll(RegExp(r'/+$'), '');
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    // Android emulator maps host loopback to 10.0.2.2
    return 'http://10.0.2.2:8000';
  }

  if (kIsWeb) {
    final host = Uri.base.host;
    if (host.isNotEmpty) {
      // Match the Flutter web host (localhost or 127.0.0.1) to avoid browser issues.
      return 'http://$host:8000';
    }
  }

  return 'http://127.0.0.1:8000';
}

final String backendUrl = resolveBackendUrl();
