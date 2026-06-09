import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Shared HTTP client for API calls. Tests can replace this with [MockClient].
http.Client healonHttpClient = http.Client();

@visibleForTesting
void setHealonHttpClientForTests(http.Client client) {
  healonHttpClient = client;
}

@visibleForTesting
void resetHealonHttpClientForTests() {
  healonHttpClient = http.Client();
}
