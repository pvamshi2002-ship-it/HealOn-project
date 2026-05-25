// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String? readString(String key) => html.window.localStorage[key];

void writeString(String key, String value) {
  html.window.localStorage[key] = value;
}

void removeString(String key) {
  html.window.localStorage.remove(key);
}
