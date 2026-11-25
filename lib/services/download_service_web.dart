import 'dart:html' as html;

void _save(String filename, String content, String mime) {
  final blob = html.Blob([content], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}

void downloadHtmlFileImpl(String filename, String content) =>
    _save(filename, content, 'text/html');

void downloadJsonFileImpl(String filename, String content) =>
    _save(filename, content, 'application/json');
