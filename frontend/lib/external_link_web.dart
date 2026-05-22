import 'dart:html' as html;

Future<void> openExternalLink(String url) async {
  html.window.open(url, '_blank');
}
