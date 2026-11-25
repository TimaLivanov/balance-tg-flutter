import 'dart:html' as html;

void downloadHtmlFileImpl(String filename, String content) {
  final blob = html.Blob([content], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
