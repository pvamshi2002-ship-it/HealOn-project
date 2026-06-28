// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<void> viewDocumentFile(String fileData, String fileName) async {
  final trimmed = fileData.trim();
  if (trimmed.isEmpty) return;

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    html.window.open(trimmed, '_blank');
    return;
  }

  if (trimmed.startsWith('data:')) {
    html.window.open(trimmed, '_blank');
    return;
  }

  html.window.open(
    'data:application/octet-stream;base64,$trimmed',
    '_blank',
  );
}

Future<void> downloadDocumentFile(String fileData, String fileName) async {
  final trimmed = fileData.trim();
  if (trimmed.isEmpty) return;

  final safeName = fileName.trim().isEmpty ? 'document' : fileName.trim();
  final href = trimmed.startsWith('http://') ||
          trimmed.startsWith('https://') ||
          trimmed.startsWith('data:')
      ? trimmed
      : 'data:application/octet-stream;base64,$trimmed';

  final anchor = html.AnchorElement(href: href)
    ..download = safeName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
